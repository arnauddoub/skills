-- rex do wt-pane.lua dir=<dir> cmd=<command> [label=<text>] [split=right|below]: opens a pane in <dir> beside this one,
-- after closing a pane left with a bare shell in <dir> (not its <slug>-dev pane).
-- rex do wt-pane.lua close=<dir>: closes every pane whose program runs in <dir>, this one excepted.
-- wt-pane.sh builds the command and calls it; one server connection instead of one rex process per pane.
local terminal = "com.superlogical.terminal"
-- rex do types its arguments (cmd=true arrives as a boolean): everything here is text.
local args = {}
for k, v in pairs(rex.args) do args[k] = tostring(v) end
local shells = { zsh = true, bash = true, sh = true }

local function check(value, err)
  if err ~= nil then error(err, 0) end
  return value
end

-- Every pane of the session with its label, foreground program and directory.
local function panes()
  local out = {}
  for _, b in ipairs(check(rex.session.list_blocks{}).blocks) do
    if b.creator_name == terminal then
      local p = rex.block.call(terminal, "process", { block_id = b.block_id }) or {}
      local fg = p.foreground or {}
      table.insert(out, {
        id = b.block_id,
        label = b.label or "",
        program = (fg.argv0 or ""):match("[^/]*$"):gsub("^%-", ""),
        cwd = fg.cwd or (p.child or {}).cwd or "",
      })
    end
  end
  return out
end

local function inside(cwd, dir)
  return cwd == dir or cwd:sub(1, #dir + 1) == dir .. "/"
end

local function close(id)
  check(rex.call("block.close", { session_id = rex.session_id, block_id = id }))
end

if args.close then
  local closed = {}
  for _, p in ipairs(panes()) do
    if p.id ~= rex.block_id and inside(p.cwd, args.close) then
      close(p.id)
      table.insert(closed, p.label)
    end
  end
  return { closed = closed }
end

local dir, cmd = args.dir, args.cmd
assert(dir and cmd, "usage: rex do wt-pane.lua dir=<dir> cmd=<command> [label=<text>] [split=right|below]")
local label = args.label or dir:match("[^/]*$")

local closed = {}
for _, p in ipairs(panes()) do
  if p.cwd == dir and shells[p.program] and not p.label:match("%-dev$") then
    close(p.id)
    table.insert(closed, p.label)
  end
end

local split = check(rex.call("session.new_split", {
  session_id = rex.session_id,
  anchor_id = rex.block_id,
  direction = args.split == "below" and "vertical" or "horizontal",
  side = "after",
  layout = { block = {
    flavor = terminal .. ".shell",
    label = label,
    options = { cwd = dir, shell = "none", command = { "zsh", "-lic", cmd .. "; exec zsh -l" } },
  } },
}))
return { label = label, closed = closed, split = split }
