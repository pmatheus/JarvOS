-- Shared helpers for the JarvOS Lua config.
local M = {}

M.home = os.getenv("HOME") or ""

-- Expand a leading ~ the way the old .conf files did.
function M.expand(path)
    return (path:gsub("^~", M.home))
end

-- Lua has no glob. List a directory and require every .lua file in it,
-- sorted, so custom overrides load in a predictable order.
function M.require_dir(dir, prefix)
    local ok, pipe = pcall(io.popen, "ls -1 " .. M.expand(dir) .. "/*.lua 2>/dev/null")
    if not ok or not pipe then
        return
    end

    local names = {}
    for line in pipe:lines() do
        local base = line:match("([^/]+)%.lua$")
        if base then
            names[#names + 1] = base
        end
    end
    pipe:close()

    table.sort(names)
    for _, base in ipairs(names) do
        require(prefix .. "." .. base)
    end
end

-- Require a module only if it exists, so an optional file is not a config error.
function M.require_optional(mod)
    local ok, err = pcall(require, mod)
    if not ok and not tostring(err):match("module '" .. mod .. "' not found") then
        print("[jarvos] " .. mod .. ": " .. tostring(err))
    end
    return ok
end

return M
