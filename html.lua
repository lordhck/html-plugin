VERSION = "0.3.0"

local micro  = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")

-- Known tags, keyed by name. The value is a list of default attributes:
-- "name" for an empty attribute ("" -> cursor lands here), {"name", "value"}
-- for a pre-filled one. Container tags expand to <tag></tag>; tags listed in
-- void_tags below are self-closing and expand to <tag> with no closing tag.
local html_tags = {
    -- Document
    html = {}, head = {}, body = {}, title = {}, style = {}, script = {},

    -- Sections & landmarks
    header = {}, footer = {}, main = {}, nav = {}, article = {},
    section = {}, aside = {}, address = {},

    -- Headings
    h1 = {}, h2 = {}, h3 = {}, h4 = {}, h5 = {}, h6 = {},
    hgroup = {},

    -- Grouping / flow
    div = {}, p = {}, pre = {}, blockquote = {}, figure = {},
    figcaption = {}, details = {}, summary = {}, dialog = {},

    -- Lists
    ul = {}, ol = {}, li = {}, dl = {}, dt = {}, dd = {},

    -- Text-level semantics
    span = {}, a = {}, em = {}, strong = {}, b = {}, i = {}, u = {},
    s = {}, small = {}, mark = {}, sub = {}, sup = {}, code = {},
    kbd = {}, samp = {}, var = {}, q = {}, cite = {}, abbr = {},
    time = {}, del = {}, ins = {}, label = {},

    -- Forms
    form = {}, button = {}, select = {}, option = {}, optgroup = {},
    textarea = {}, fieldset = {}, legend = {}, datalist = {},
    output = {}, progress = {}, meter = {},

    -- Tables
    table = {}, caption = {}, colgroup = {}, thead = {}, tbody = {},
    tfoot = {}, tr = {}, td = {}, th = {},

    -- Embedded / interactive
    iframe = {}, video = {}, audio = {}, canvas = {}, svg = {},
    picture = {}, object = {}, map = {}, template = {},

    -- Void elements (self-closing; see void_tags). Values are default attrs.
    area = {}, base = {"href"}, br = {}, col = {}, embed = {"src"},
    hr = {}, wbr = {},
    img = {"src", "alt"},
    input = {"type"},
    link = {{"rel", "stylesheet"}, "href"},
    meta = {"name", "content"},
    param = {"name", "value"},
    source = {"src"},
    track = {"src"},
}

-- Tags with no closing tag. Their default attributes live in html_tags above;
-- this set only marks which tags are self-closing.
local void_tags = {
    area = true, base = true, br = true, col = true, embed = true,
    hr = true, img = true, input = true, link = true, meta = true,
    param = true, source = true, track = true, wbr = true,
}

-- Abbreviations that expand to literal text. A "$0" marks the final cursor.
local snippets = {
    doctype = "<!DOCTYPE html>",

    -- HTML5 boilerplate, triggered by "!".
    ["!"] = table.concat({
        "<!DOCTYPE html>",
        '<html lang="en">',
        "<head>",
        '    <meta charset="UTF-8">',
        '    <meta name="viewport" content="width=device-width, initial-scale=1.0">',
        "    <title>Document</title>",
        "</head>",
        "<body>",
        "    $0",
        "</body>",
        "</html>",
    }, "\n"),

    -- tag:variant aliases, expanded to a common preset for that tag.
    ["meta:charset"]  = '<meta charset="UTF-8">',
    ["meta:viewport"] = '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
    ["a:href"]        = '<a href="$0"></a>',
}

-- Render a tag's default-attribute list into a string. The first empty-valued
-- attribute gets a "$0" cursor marker. Returns the string (with a leading
-- space when non-empty) and whether a cursor marker was placed.
local function render_attrs(attrs)
    if not attrs or #attrs == 0 then
        return "", false
    end
    local parts = {}
    local placed = false
    for _, attr in ipairs(attrs) do
        local name, value
        if type(attr) == "table" then
            name, value = attr[1], attr[2]
        else
            name, value = attr, ""
        end
        if value == "" and not placed then
            value = "$0"
            placed = true
        end
        parts[#parts + 1] = name .. '="' .. value .. '"'
    end
    return " " .. table.concat(parts, " "), placed
end

-- Build an expansion template for a tag, with "$0" marking the final cursor.
local function tag_template(abbr, attrs)
    local rendered, placed = render_attrs(attrs)
    local open = "<" .. abbr .. rendered .. ">"
    if void_tags[abbr] then
        return placed and open or (open .. "$0")
    end
    if placed then
        return open .. "</" .. abbr .. ">"
    end
    return open .. "$0</" .. abbr .. ">"
end

-- Returns the abbreviation before the cursor and its start column, or nil.
local function abbreviation_before_cursor(bp)
    local c = bp.Cursor
    local line = bp.Buf:Line(c.Y)
    local before = string.sub(line, 1, c.X)
    local abbr = string.match(before, "!$") or string.match(before, "[%w%-:]+$")
    if not abbr then
        return nil
    end
    return abbr, c.X - #abbr
end

-- Replace [startLoc, endLoc] with text; "$0" marks the cursor, else the end.
local function insert_snippet(bp, startLoc, endLoc, text)
    local before, after
    local marker = string.find(text, "$0", 1, true)
    if marker then
        before = string.sub(text, 1, marker - 1)
        after  = string.sub(text, marker + 2)
    else
        before, after = text, ""
    end

    bp.Buf:Remove(startLoc, endLoc)
    bp.Buf:Insert(startLoc, before .. after)

    local _, newlines = string.gsub(before, "\n", "")
    local cx, cy
    if newlines == 0 then
        cx, cy = startLoc.X + #before, startLoc.Y
    else
        cx, cy = #string.match(before, "[^\n]*$"), startLoc.Y + newlines
    end
    bp.Cursor:GotoLoc(buffer.Loc(cx, cy))
end

-- Expand the abbreviation before the cursor, leaving the cursor inside.
function expand(bp)
    local abbr, startX = abbreviation_before_cursor(bp)
    if not abbr then
        return false
    end

    local y = bp.Cursor.Y
    local startLoc = buffer.Loc(startX, y)
    local endLoc   = buffer.Loc(startX + #abbr, y)

    if snippets[abbr] then
        insert_snippet(bp, startLoc, endLoc, snippets[abbr])
        return true
    end

    if html_tags[abbr] then
        insert_snippet(bp, startLoc, endLoc, tag_template(abbr, html_tags[abbr]))
        return true
    end

    return false
end

local expanded = false

function preAutocomplete(bp)
    expanded = expand(bp)
    return not expanded
end

function preInsertTab(bp)
    if expanded then
        expanded = false
        return false
    end
    return true
end

function init()
    config.MakeCommand("html", expand, config.NoComplete)
end
