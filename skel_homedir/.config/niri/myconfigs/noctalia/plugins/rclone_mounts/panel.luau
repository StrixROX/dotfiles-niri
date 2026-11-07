--!nonstrict
-- rclone mount manager — panel.
--
-- Layout (top to bottom), only the middle section scrolls:
--   1. Header: title + close                                    [fixed]
--   2. Add-mount row: remote dropdown + directory-picker "Add"   [fixed]
--   3. Tab bar: one button per mounted remote, listmounts order  [fixed]
--   4. Details for the selected tab                            [scrolls]
--
-- The directory picker shells out to whichever of zenity / kdialog / yad
-- is installed - noctalia has no built-in native file-chooser API for
-- plugins, so this is the standard way a Luau plugin reaches the system's
-- own folder picker (what the user called "xdg-open file selector").

local mounts = {}
local remotes = {}
local rcUp = false
local selectedTabIndex = 1
local selectedRemoteIndex = 0
local picking = false
local confirmUnmountFor = nil -- mountpoint currently showing the unmount confirmation (unique key; the same remote can in principle be mounted twice, at different paths)
local CACHE_MODE_LABELS = { "Full", "Write", "Minimal", "Off" }
local CACHE_MODE_VALUES = { 3, 2, 1, 0 } -- rclone's vfs CacheMode enum, same order as CACHE_MODE_LABELS
local CACHE_MODE_SETTING_TO_VALUE = { full = 3, write = 2, minimal = 1, off = 0 }

local function defaultCacheModeIndex()
    local value = CACHE_MODE_SETTING_TO_VALUE[noctalia.getConfig("default_cache_mode")]
    if value == nil then
        return 3 -- "Off", 0-based (matches ui.select/onChange convention below)
    end
    for i, v in ipairs(CACHE_MODE_VALUES) do
        if v == value then
            return i - 1 -- CACHE_MODE_VALUES is 1-based (Lua array); selectedIndex is 0-based
        end
    end
    return 3
end

local function defaultCacheMaxSizeText()
    local gib = noctalia.getConfig("default_cache_max_size_gib")
    if type(gib) == "number" and gib > 0 then
        return tostring(gib)
    end
    return ""
end

local selectedCacheModeIndex = defaultCacheModeIndex()
local cacheMaxSizeText = defaultCacheMaxSizeText() -- max cache size in GiB, blank = unbounded

local function tr(key, subst)
    return noctalia.tr(key, subst)
end

local function humanBytes(n)
    if type(n) ~= "number" then return "?" end
    local units = { "B", "KiB", "MiB", "GiB", "TiB", "PiB" }
    local i = 1
    while n >= 1024 and i < #units do
        n /= 1024
        i += 1
    end
    return string.format("%.1f %s", n, units[i])
end

local function pct(used, total)
    if type(used) ~= "number" or type(total) ~= "number" or total <= 0 then
        return "n/a"
    end
    return string.format("%.1f%%", (used / total) * 100)
end

local function currentMount()
    return mounts[selectedTabIndex]
end

local function clampSelectedTab()
    if #mounts == 0 then
        selectedTabIndex = 1
        return
    end
    if selectedTabIndex < 1 or selectedTabIndex > #mounts then
        selectedTabIndex = 1
    end
end

-- ── sections ─────────────────────────────────────────────────────────────

local function sectionHeading(text)
    return ui.label({ text = text, fontSize = 13, fontWeight = "bold", color = "primary" })
end

local function kv(k, v)
    return ui.row({ gap = 8, align = "center" }, {
        ui.label({ text = k, color = "on_surface_variant", minWidth = 90 }),
        ui.label({ text = v, color = "on_surface" }),
    })
end

local function remoteStorageSection(m)
    local content
    if m.about ~= nil and m.about.supported then
        content = ui.row({ gap = 20, align = "center" }, {
            ui.label({ text = `{tr("panel.used")}: {humanBytes(m.about.used)} ({pct(m.about.used, m.about.total)})` }),
            ui.label({ text = `{tr("panel.free")}: {humanBytes(m.about.free)}` }),
            ui.label({ text = `{tr("panel.total")}: {humanBytes(m.about.total)}` }),
        })
    else
        content = ui.label({ text = tr("panel.about_unsupported"), color = "on_surface_variant" })
    end
    return ui.column({ gap = 4, align = "stretch" }, { sectionHeading(tr("panel.section.remote_storage")), content })
end

local function vfsCacheSection(m)
    local rows = {}
    if m.cacheAvailable then
        if m.cacheMaxBytes ~= nil and m.cacheMaxBytes ~= -1 then
            table.insert(rows, kv(tr("panel.used"), `{humanBytes(m.cacheUsedBytes)} / {humanBytes(m.cacheMaxBytes)} ({pct(m.cacheUsedBytes, m.cacheMaxBytes)})`))
        else
            table.insert(rows, kv(tr("panel.used"), `{humanBytes(m.cacheUsedBytes)} ({tr("panel.max_unbounded")})`))
        end
        table.insert(rows, kv(tr("panel.cache_mode"), m.cacheMode))
        table.insert(rows, kv(tr("panel.cache_dir"), if m.cachePath ~= "" then m.cachePath else "?"))
    else
        table.insert(rows, ui.label({ text = tr("panel.cache_unavailable"), color = "on_surface_variant" }))
    end
    return ui.column({ gap = 4, align = "stretch" }, { sectionHeading(tr("panel.section.vfs_cache")), ui.column({ gap = 4 }, rows) })
end

local function uploadQueueSection(m)
    local text = `{tr("panel.queued")}: {m.uploadsQueued}   {tr("panel.in_progress")}: {m.uploadsInProgress}   {tr("panel.errored")}: {m.erroredFiles}`
    return ui.column({ gap = 4, align = "stretch" }, { sectionHeading(tr("panel.section.upload_queue")), ui.label({ text = text }) })
end

local function transfersInProgressSection(m)
    local rows = {}
    local items = m.queueItems or {}
    local inProgress = {}
    for _, q in ipairs(items) do
        if q.uploading then
            table.insert(inProgress, q)
        end
    end
    if #inProgress == 0 then
        table.insert(rows, ui.label({ text = tr("panel.no_transfers"), color = "on_surface_variant" }))
    else
        for _, q in ipairs(inProgress) do
            local nameText = `{q.name} ({humanBytes(q.size)})`
            if q.percentage ~= nil then
                table.insert(rows, ui.row({ gap = 6, align = "center", justify = "space_between" }, {
                    ui.label({ text = nameText, flexGrow = 1 }),
                    ui.label({ text = `{q.percentage}%`, fontWeight = "bold" }),
                }))
            else
                table.insert(rows, ui.label({ text = nameText }))
            end
        end
    end
    return ui.column({ gap = 4, align = "stretch" }, { sectionHeading(tr("panel.section.transfers_in_progress")), ui.column({ gap = 2 }, rows) })
end

local function completedTransfersSection(m)
    local heading = ui.row({ align = "center", justify = "space_between" }, {
        sectionHeading(tr("panel.section.completed_transfers")),
        ui.label({ text = `{tr("panel.total")}: {m.transferredCount or 0}`, color = "on_surface_variant" }),
    })
    local rows = {}
    if m.transferred ~= nil then
        for _, t in ipairs(m.transferred) do
            if t.error ~= nil and t.error ~= "" then
                table.insert(rows, ui.label({ text = `{t.name} [{tr("panel.error")}: {t.error}]`, color = "error" }))
            else
                table.insert(rows, ui.label({ text = t.name }))
            end
        end
    end
    if #rows == 0 then
        table.insert(rows, ui.label({ text = tr("panel.no_transfers"), color = "on_surface_variant" }))
    end
    return ui.column({ gap = 4, align = "stretch" }, { heading, ui.column({ gap = 2 }, rows) })
end

-- ── unmount ──────────────────────────────────────────────────────────────

local function hasActiveTransfers(m)
    local items = m.queueItems or {}
    for _, q in ipairs(items) do
        if q.uploading then return true end
    end
    return false
end

local function sendUnmount(m)
    noctalia.state.set("command", { action = "unmount", remote = m.name, mountpoint = m.mountpoint })
end

local function requestUnmount(m)
    if m.cacheMode == "full" and hasActiveTransfers(m) then
        confirmUnmountFor = m.mountpoint
    else
        sendUnmount(m)
    end
    render()
end

local function unmountConfirmBanner(m)
    if confirmUnmountFor ~= m.mountpoint then
        return nil
    end
    return ui.column({ gap = 8, align = "stretch", fill = "error/0.12", radius = 8, padding = 12 }, {
        ui.label({ text = tr("panel.unmount_confirm_message"), color = "on_surface" }),
        ui.row({ gap = 8, align = "center", justify = "end" }, {
            ui.button({ text = tr("panel.cancel"), variant = "ghost", onClick = "onCancelUnmount" }),
            ui.button({ text = tr("panel.unmount_anyway"), variant = "destructive", onClick = "onConfirmUnmount" }),
        }),
    })
end

local function mountPointRow(m)
    return ui.column({ gap = 4, align = "stretch" }, {
        sectionHeading(tr("panel.mount_point")),
        ui.row({ gap = 8, align = "center", justify = "space_between" }, {
            ui.label({ text = m.mountpoint, color = "on_surface", flexGrow = 1 }),
            ui.button({
                key = "unmount_button",
                text = tr("panel.unmount"),
                variant = "destructive",
                onClick = function()
                    requestUnmount(m)
                end,
            }),
        }),
    })
end

local function detailsColumn()
    if not rcUp then
        return ui.label({ text = tr("panel.rc_down"), color = "error" })
    end
    local m = currentMount()
    if m == nil then
        return ui.label({ text = tr("panel.no_mounts"), color = "on_surface_variant" })
    end
    local children = { mountPointRow(m) }
    local banner = unmountConfirmBanner(m)
    if banner ~= nil then
        table.insert(children, banner)
    end
    table.insert(children, remoteStorageSection(m))
    table.insert(children, vfsCacheSection(m))
    table.insert(children, uploadQueueSection(m))
    table.insert(children, transfersInProgressSection(m))
    table.insert(children, completedTransfersSection(m))
    return ui.column({ gap = 16, align = "stretch" }, children)
end

-- ── tabs ─────────────────────────────────────────────────────────────────

local function tabBar()
    if #mounts == 0 then
        return nil
    end
    local buttons = {}
    for index, m in ipairs(mounts) do
        table.insert(buttons, ui.button({
            key = `tab_{m.mountpoint}`,
            text = m.name,
            variant = if index == selectedTabIndex then "primary" else "outline",
            onClick = function()
                selectedTabIndex = index
                render()
            end,
        }))
    end
    return ui.row({ gap = 6, align = "center" }, buttons)
end

-- ── add-mount row ────────────────────────────────────────────────────────

local function remoteLabels()
    if #remotes == 0 then
        return { tr("panel.no_remotes") }
    end
    return remotes
end

local function parseMaxSizeGiB()
    local n = tonumber(noctalia.string.trim(cacheMaxSizeText))
    if n ~= nil and n > 0 then
        return n
    end
    return nil
end

local function addMountRow()
    local hasRemotes = #remotes > 0
    return ui.column({ gap = 8, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.select({
                key = "remote_select",
                options = remoteLabels(),
                selectedIndex = selectedRemoteIndex,
                enabled = hasRemotes,
                flexGrow = 1,
                onChange = "onRemoteChange",
            }),
            ui.select({
                key = "cache_mode_select",
                options = CACHE_MODE_LABELS,
                selectedIndex = selectedCacheModeIndex,
                enabled = hasRemotes,
                width = 120,
                onChange = "onCacheModeChange",
            }),
        }),
        ui.row({ gap = 8, align = "center" }, {
            ui.input({
                key = "cache_max_size_input",
                value = cacheMaxSizeText,
                placeholder = tr("panel.cache_max_size_placeholder"),
                enabled = hasRemotes,
                flexGrow = 1,
                onChange = "onCacheMaxSizeChange",
            }),
            ui.button({
                key = "add_button",
                text = if picking then tr("panel.picking_directory") else tr("panel.add"),
                variant = "primary",
                enabled = hasRemotes and not picking,
                onClick = "onAddClicked",
            }),
        }),
    })
end

-- ── render ───────────────────────────────────────────────────────────────

function render()
    clampSelectedTab()

    local headerContent = {
        ui.label({ text = tr("panel.title"), fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
        ui.button({ glyph = "close", variant = "ghost", onClick = "onCloseClicked" }),
    }

    local children = {
        ui.row({ align = "center", justify = "space_between" }, headerContent),
        addMountRow(),
    }

    local tabs = tabBar()
    if tabs ~= nil then
        table.insert(children, tabs)
    end

    table.insert(children, ui.scroll({ flexGrow = 1, gap = 12, align = "stretch" }, { detailsColumn() }))

    panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, children))
end

-- ── directory picker ─────────────────────────────────────────────────────

local function pickDirectoryAsync(cb)
    local cmd = [[
if command -v zenity >/dev/null 2>&1; then
  zenity --file-selection --directory --title="Select mount point" 2>/dev/null
elif command -v kdialog >/dev/null 2>&1; then
  kdialog --getexistingdirectory "$HOME" 2>/dev/null
elif command -v yad >/dev/null 2>&1; then
  yad --file --directory --title="Select mount point" 2>/dev/null
fi]]
    local ok = noctalia.runAsync(cmd, function(result)
        local path = noctalia.string.trim(result.stdout or "")
        cb(if path ~= "" then path else nil)
    end)
    if not ok then cb(nil) end
end

-- ── callbacks ────────────────────────────────────────────────────────────

function onOpen(_context)
    render()
end

function onRemoteChange(index, _text)
    selectedRemoteIndex = tonumber(index) or 0
    render()
end

function onCacheModeChange(index, _text)
    selectedCacheModeIndex = tonumber(index) or 3
    render()
end

function onCacheMaxSizeChange(value)
    cacheMaxSizeText = value or ""
end

function onAddClicked()
    if picking or #remotes == 0 then return end
    local remote = remotes[selectedRemoteIndex + 1]
    if remote == nil then return end
    local cacheMode = CACHE_MODE_VALUES[selectedCacheModeIndex + 1] or 0
    local cacheMaxSizeGiB = parseMaxSizeGiB()

    picking = true
    render()
    pickDirectoryAsync(function(path)
        picking = false
        if path ~= nil then
            noctalia.state.set("command", { action = "mount", remote = remote, mountpoint = path, cacheMode = cacheMode, cacheMaxSizeGiB = cacheMaxSizeGiB })
        end
        render()
    end)
end

function onCloseClicked()
    panel.close()
end

function onCancelUnmount()
    confirmUnmountFor = nil
    render()
end

function onConfirmUnmount()
    local m = currentMount()
    if m ~= nil then
        sendUnmount(m)
    end
    confirmUnmountFor = nil
    render()
end

-- ── state wiring ─────────────────────────────────────────────────────────

noctalia.state.watch("mounts", function(value)
    mounts = if type(value) == "table" then value else {}
    render()
end)

noctalia.state.watch("remotes", function(value)
    remotes = if type(value) == "table" then value else {}
    if selectedRemoteIndex >= #remotes then
        selectedRemoteIndex = 0
    end
    render()
end)

noctalia.state.watch("rcUp", function(value)
    rcUp = value == true
    render()
end)

mounts = noctalia.state.get("mounts") or {}
remotes = noctalia.state.get("remotes") or {}
rcUp = noctalia.state.get("rcUp") == true
