-- Declarative keybind table for the JarvOS Lua config.
--
-- One declaration feeds two consumers: hl.bind registers the bind with
-- Hyprland, and flush() writes the JSON the QuickShell cheatsheet reads. The
-- .conf setup kept these in sync by re-parsing keybinds.conf with a Python
-- script; the Lua config is the single source of truth instead.
local M = {}

local pages = {}
local page, section

--- Start a page group (the old `#!` heading).
function M.page(name)
    page = { name = name or "", children = {}, keybinds = {} }
    pages[#pages + 1] = page
    section = nil
end

--- Start a section within the current page (the old `##!` heading).
function M.section(name)
    if not page then
        M.page("")
    end
    section = { name = name, children = {}, keybinds = {} }
    page.children[#page.children + 1] = section
end

--- Build the key string hl.bind expects: "SUPER + SHIFT + M".
-- Modifier names must be upper case or Hyprland parses them as keysyms; the
-- cheatsheet keeps the declared spelling ("Super") for display.
local function key_string(mods, key)
    if not mods or #mods == 0 then
        return key
    end
    local upper = {}
    for i, m in ipairs(mods) do
        upper[i] = m:upper()
    end
    return table.concat(upper, " + ") .. " + " .. key
end

--- Register one bind and record it for the cheatsheet.
-- spec: { mods = {"Super"}, key = "Space", desc = "Launcher",
--         dispatch = <HL.Dispatcher>, opts = { locked = true }, hidden = bool }
function M.bind(spec)
    local opts = {}
    for k, v in pairs(spec.opts or {}) do
        opts[k] = v
    end
    if spec.desc then
        opts.description = spec.desc
    end

    hl.bind(key_string(spec.mods, spec.key), spec.dispatch, opts)

    if not section then
        M.section("")
    end
    section.keybinds[#section.keybinds + 1] = {
        mods    = spec.mods or {},
        key     = spec.key,
        comment = spec.desc or "",
        hidden  = spec.hidden or false,
    }
end

local function escape(s)
    return (tostring(s):gsub('[%c"\\]', function(c)
        local named = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return named[c] or string.format('\\u%04x', c:byte())
    end))
end

local function encode_keybind(kb)
    local mods = {}
    for i, m in ipairs(kb.mods) do
        mods[i] = '"' .. escape(m) .. '"'
    end
    return string.format('{"mods":[%s],"key":"%s","comment":"%s","hidden":%s}',
        table.concat(mods, ","), escape(kb.key), escape(kb.comment), tostring(kb.hidden))
end

local function encode_section(sec)
    local binds = {}
    for i, kb in ipairs(sec.keybinds) do
        binds[i] = encode_keybind(kb)
    end
    return string.format('{"name":"%s","children":[],"keybinds":[%s]}',
        escape(sec.name), table.concat(binds, ","))
end

--- Write the cheatsheet JSON. Failure here must never break the config, so a
--- missing directory or read-only path is reported and swallowed.
function M.flush(path)
    local out = {}
    for i, p in ipairs(pages) do
        local secs = {}
        for j, sec in ipairs(p.children) do
            secs[j] = encode_section(sec)
        end
        out[i] = string.format('{"name":"%s","children":[%s],"keybinds":[]}',
            escape(p.name), table.concat(secs, ","))
    end

    local json = '{"children":[' .. table.concat(out, ",") .. ']}'
    local file, err = io.open(path, "w")
    if not file then
        print("[jarvos] keybinds: cannot write " .. path .. ": " .. tostring(err))
        return
    end
    file:write(json)
    file:close()
end

return M
