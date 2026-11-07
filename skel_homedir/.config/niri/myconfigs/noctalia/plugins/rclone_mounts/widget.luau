--!nonstrict
-- rclone mount manager — bar widget (thin presentation client).
--
-- Shows a server glyph + the mounted-remote count. Hovering reveals a
-- tooltip with, per mount: "name: mountpoint" then "cache: <mode>" below
-- it, in the same order the service publishes (mirrors rclone_status.sh's
-- mount/listmounts order). Clicking opens the panel.

local mounts = {}
local rcUp = false
local vertical = barWidget.isVertical()

local function applyTooltip()
    if not rcUp then
        barWidget.setTooltip(noctalia.tr("widget.rc_down"))
        return
    end
    if #mounts == 0 then
        barWidget.setTooltip(noctalia.tr("widget.no_mounts"))
        return
    end

    local rows = {}
    for _, m in ipairs(mounts) do
        table.insert(rows, { key = m.name, value = m.mountpoint })
        table.insert(rows, { key = "", value = `cache: {m.cacheMode}` })
    end
    barWidget.setTooltip(rows)
end

local function applyDisplay()
    barWidget.setGlyph("server")
    local greyedOut = (not rcUp) or (#mounts == 0)
    if not rcUp then
        barWidget.setText((not vertical) and "" or "–")
    else
        barWidget.setText(vertical and "" or tostring(#mounts))
    end
    if greyedOut then
        barWidget.setGlyphColor("on_surface_variant")
        barWidget.setColor("on_surface_variant")
    else
        barWidget.setGlyphColor("on_surface")
        barWidget.setColor("on_surface")
    end
    applyTooltip()
end

function onClick()
    noctalia.togglePanel("strixrox/rclone_mounts:panel")
end

noctalia.state.watch("mounts", function(value)
    mounts = if type(value) == "table" then value else {}
    applyDisplay()
end)

noctalia.state.watch("rcUp", function(value)
    rcUp = value == true
    applyDisplay()
end)

mounts = noctalia.state.get("mounts") or {}
rcUp = noctalia.state.get("rcUp") == true
applyDisplay()
