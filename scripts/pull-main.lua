-- rex do pull-main.lua repo=<path> [minutes=180]: fast-forward that checkout's main to origin/main every <minutes>.
local root, minutes = rex.args.repo, tonumber(rex.args.minutes) or 180
assert(root, "usage: rex do pull-main.lua repo=<path> [minutes=180]")

local function git(...)
  return rex.exec({ "git", "-C", root, ... }, { timeout = 120 })
end

local function log(msg)
  print(os.date("%H:%M") .. "  " .. msg)
end

local function pull()
  local branch = git("branch", "--show-current").stdout:gsub("%s+$", "")
  if branch ~= "main" then return log("on " .. branch .. ", not main: skipped") end
  local fetch = git("fetch", "-q", "origin", "main")
  if not fetch.ok then return log("fetch failed: " .. fetch.stderr) end
  local behind = git("rev-list", "--count", "HEAD..origin/main").stdout:gsub("%s+$", "")
  if behind == "0" then return log("up to date") end
  local merge = git("merge", "-q", "--ff-only", "origin/main")
  log(merge.ok and ("fast-forwarded " .. behind .. " commits") or ("ff-only refused: " .. merge.stderr))
end

pull()
rex.every(minutes * 60, pull)
