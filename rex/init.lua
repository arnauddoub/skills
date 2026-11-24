require("extensions.rex-resume")

rex.bind("shift+enter", "pane.send_key", { key = "ctrl+j" })
rex.bind("shift+cmd+=", "pane.balance")


local GH = "/opt/homebrew/bin/gh"

local function pane(block_id)
  local res = rex.session.list_blocks{} or { blocks = {} }
  local label
  for _, b in ipairs(res.blocks) do
    if b.block_id == block_id then label = b.label end
  end
  local p = rex.block.call("com.superlogical.terminal", "process", { block_id = block_id }) or {}
  return label or "", (p.foreground or {}).cwd or (p.child or {}).cwd
end


local CURL = "/usr/bin/curl"

local function linear_key()
  local k = rex.exec({ "/usr/bin/security", "find-generic-password", "-s", "linear-api", "-w" }, { timeout = 5 })
  return k and k.ok and k.stdout:gsub("%s+$", "") or nil
end

local function linear_argv(key, query)
  return { CURL, "-sS", "--max-time", "10", "https://api.linear.app/graphql", "-H", "Authorization: " .. key,
    "-H", "Content-Type: application/json", "-d", rex.json.encode({ query = query }) }
end

local function decode(r)
  local ok, v = pcall(rex.json.decode, r and r.ok and r.stdout or "")
  return ok and v or nil
end

local OPEN = '{ type: { nin: ["completed", "canceled", "duplicate"] } }'

-- A ticket pane offers its ticket; a project pane (a *-requirements worktree) offers the project and its open tickets.
local function pane_items(key, own, label, cwd)
  if own then
    local res = decode(rex.exec(linear_argv(key, ("{ issue(id: %q) { identifier title url state { name } } }"):format(own)), { timeout = 15 }))
    local issue = res and res.data and res.data.issue
    if not issue then return {}, own end
    return { { id = issue.url, title = issue.identifier .. "  " .. issue.title, subtitle = issue.state.name, icon = "tag" } }, own
  end
  local slug = (cwd or ""):match("/worktrees/[^/]-%-(.+)%-requirements")
  local name = (label ~= "" and label ~= "shell") and label or (slug and slug:gsub("%-", " "))
  if not name then return {}, nil end
  local query = ('{ projects(first: 1, filter: { name: { eqIgnoreCase: %q } }) { nodes { name url issues(first: 100, filter: { state: %s }) { nodes { identifier title url state { name } } } } } }'):format(name, OPEN)
  local res = decode(rex.exec(linear_argv(key, query), { timeout = 15 }))
  local project = res and res.data and res.data.projects.nodes[1]
  if not project then return {}, name end
  local items = { { id = project.url, title = project.name, subtitle = "Projet", icon = "folder" } }
  for _, i in ipairs(project.issues.nodes) do
    table.insert(items, { id = i.url, title = i.identifier .. "  " .. i.title, subtitle = i.state.name, icon = "tag" })
  end
  return items, project.name
end

rex.action{
  name = "open_linear",
  title = "Open the Pane's Linear Ticket",
  keywords = "linear ticket issue project",
  args = { dry = "boolean?" },
  run = function(ctx, args)
    local label, cwd = pane(ctx.block_id)
    local own = label:match("(%u+%-%d+)") or (cwd or ""):match("/worktrees/[^/]-(%u+%-%d+)")
    local key = linear_key()
    if key == nil then error("no Linear API key in the keychain (service linear-api)", 0) end
    local items, title = pane_items(key, own, label, cwd)
    if #items == 0 then error("no Linear ticket or project for this pane" .. (title and (": " .. title) or ""), 0) end
    if args.dry then return { items = items } end
    local url = items[1].id
    if rex.ui then
      url = rex.ui.pick{ title = title, placeholder = "Filtrer", items = items }
      if url == nil then return end
    end
    rex.exec({ "open", url })
    return { url = url }
  end,
}
rex.bind("shift+cmd+l", "open_linear")

local PR_STATUS = { draft = "draft", inReview = "en review", approved = "approuvée", changesRequested = "modifs demandées", merged = "mergée", closed = "fermée" }
local ATTACHMENTS = "attachments { nodes { url title metadata } }"

local function pr_of(a)
  local m = a.metadata or {}
  if not (a.url or ""):match("^https://github%.com/[^/]+/[^/]+/pull/%d+$") then return nil end
  return { url = a.url, number = m.number or tonumber(a.url:match("(%d+)$")), title = a.title or "", status = m.status or "",
    head = m.branch or "", base = m.targetBranch or "" }
end

local function from_gh(argv, cwd)
  local r = rex.exec(argv, { cwd = cwd, timeout = 15 })
  local list = decode(r)
  if type(list) ~= "table" then return {} end
  if list.url then list = { list } end
  local out = {}
  for _, p in ipairs(list) do
    table.insert(out, { url = p.url, number = p.number, title = p.title, head = p.headRefName, base = p.baseRefName,
      status = p.isDraft and "draft" or ({ OPEN = "inReview", MERGED = "merged", CLOSED = "closed" })[p.state] or "" })
  end
  return out
end
local GH_FIELDS = "url,number,title,headRefName,baseRefName,state,isDraft"

-- Bottom-up: a PR whose base is no other listed PR's head comes first, then the PR stacked on it.
local function stack_order(prs)
  local by_base, heads, out = {}, {}, {}
  for _, pr in ipairs(prs) do heads[pr.head] = true; by_base[pr.base] = by_base[pr.base] or {}; table.insert(by_base[pr.base], pr) end
  local function walk(base)
    for _, pr in ipairs(by_base[base] or {}) do table.insert(out, pr); walk(pr.head) end
  end
  for base in pairs(by_base) do if not heads[base] then walk(base) end end
  return out
end

-- A ticket pane: the PRs Linear links to its ticket, the PRs they stack on, else its branch's PR.
-- A project pane: the open PRs linked to the project's open tickets.
local function pane_prs(key, own, label, cwd)
  local prs, seen = {}, {}
  local function add(pr) if pr and pr.url and not seen[pr.url] then seen[pr.url] = true; table.insert(prs, pr) end end
  local title = own
  if own then
    local res = decode(rex.exec(linear_argv(key, ("{ issue(id: %q) { %s } }"):format(own, ATTACHMENTS)), { timeout = 15 }))
    for _, a in ipairs(((((res or {}).data or {}).issue or {}).attachments or {}).nodes or {}) do add(pr_of(a)) end
  else
    local slug = (cwd or ""):match("/worktrees/[^/]-%-(.+)%-requirements")
    local name = (label ~= "" and label ~= "shell") and label or (slug and slug:gsub("%-", " "))
    if name then
      local q = ('{ projects(first: 1, filter: { name: { eqIgnoreCase: %q } }) { nodes { name issues(first: 100, filter: { state: %s }) { nodes { %s } } } } }'):format(name, OPEN, ATTACHMENTS)
      local res = decode(rex.exec(linear_argv(key, q), { timeout = 15 }))
      local project = res and res.data and res.data.projects.nodes[1]
      if project then
        title = project.name
        for _, i in ipairs(project.issues.nodes) do
          for _, a in ipairs(i.attachments.nodes) do
            local pr = pr_of(a)
            if pr and pr.status ~= "merged" and pr.status ~= "closed" then add(pr) end
          end
        end
      end
    end
  end
  if #prs == 0 and cwd then
    for _, pr in ipairs(from_gh({ GH, "pr", "view", "--json", GH_FIELDS }, cwd)) do add(pr) end
  end
  local heads = {}
  for _, pr in ipairs(prs) do heads[pr.head] = true end
  for _, pr in ipairs(prs) do
    if pr.base ~= "" and pr.base ~= "main" and pr.base ~= "master" and not heads[pr.base] and cwd then
      for _, below in ipairs(from_gh({ GH, "pr", "list", "--state", "all", "--head", pr.base, "--json", GH_FIELDS }, cwd)) do add(below) end
    end
  end
  return stack_order(prs), title
end

rex.action{
  name = "open_pr",
  title = "Open the Pane's Pull Request",
  keywords = "github pull request pr",
  args = { dry = "boolean?" },
  run = function(ctx, args)
    local label, cwd = pane(ctx.block_id)
    local own = label:match("(%u+%-%d+)") or (cwd or ""):match("/worktrees/[^/]-(%u+%-%d+)")
    local key = linear_key()
    if key == nil then error("no Linear API key in the keychain (service linear-api)", 0) end
    local prs, title = pane_prs(key, own, label, cwd)
    if #prs == 0 then error("no pull request for " .. (title or own or "this pane"), 0) end
    if args.dry then return { prs = prs } end
    local items = {}
    for _, pr in ipairs(prs) do
      table.insert(items, { id = pr.url, title = "#" .. pr.number .. "  " .. pr.title, subtitle = pr.head .. " ← " .. pr.base,
        detail = PR_STATUS[pr.status] or pr.status, icon = "branch" })
    end
    local url = prs[1].url
    if rex.ui then
      url = rex.ui.pick{ title = (title or "Pull requests") .. " · " .. #prs .. " PR", placeholder = "Filtrer", items = items }
      if url == nil then return end
    end
    rex.exec({ "open", url })
    return { url = url }
  end,
}
rex.bind("shift+cmd+g", "open_pr")
