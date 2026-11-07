--!nonstrict
-- rclone mount manager — headless service.
--
-- Talks to the rclone rc HTTP API directly via noctalia.http (JSON POST to
-- http://<rc_addr>/<command>): mount/listmounts (authoritative mount list,
-- same order we publish, same order rclone_status.sh prints), vfs/stats,
-- vfs/queue (per-VFS upload-queue items - this is what makes "transfers in
-- progress" genuinely per-remote instead of the global core/stats list),
-- operations/about (rc equivalent of `rclone about`), core/stats +
-- core/transferred (completed-transfer history - rclone has no per-VFS
-- scoping for this one, so it stays global across every mount), and
-- config/listremotes.
--
-- Every tick refreshes vfs/stats, vfs/queue, and the global transferred
-- list (all cheap, local rc calls). "about" hits the remote backend over
-- the network, so it only refreshes every SLOW_REFRESH_TICKS ticks; on the
-- ticks in between, each mount's `about` is carried forward from the
-- previous publish instead of being reset - resetting it every tick was
-- the bug that made remote-storage info (and, by the same mechanism, the
-- old global transfer lists) flash and then disappear between refreshes.
--
-- Publishes two state keys other entries read:
--   "mounts"  - ordered array of { name, fs, mountpoint, cacheMode, ... }
--   "remotes" - configured remotes (stripped of trailing ':') not mounted
-- and watches "command" for { action = "mount"|"unmount", remote,
-- mountpoint } requests from the panel.
--
-- Encrypted rclone.conf: deliberately no special handling here, and none
-- is needed. Every rclone.conf read (operations/about, config/listremotes,
-- mount/mount's own fs lookup, ...) happens inside the already-running
-- `rclone rcd` process over its rc HTTP API - this plugin never shells out
-- to a fresh `rclone` CLI subprocess, which is the only case that needs
-- its own RCLONE_CONFIG_PASS/--password-command (see the
-- rclone-mount-scripting skill). Whoever starts `rclone rcd` is on the
-- hook for decrypting the config once, at its own startup; every rc call
-- after that, from this plugin or anything else, just uses that already
-- in-memory, decrypted config. If rcd isn't up (or isn't decrypted yet),
-- core/pid simply fails and the plugin shows "rc server unreachable" -
-- already handled, nothing further to add.

local CACHE_MODE_NAMES = { [0] = "off", [1] = "minimal", [2] = "write", [3] = "full" }
local SLOW_REFRESH_TICKS = 10 -- "about" hits the network; refresh every Nth poll

local mounts = {}
local availableRemotes = {}
local rcUp = false
local tickCount = 0
local refreshInFlight = false

local function log(msg)
    noctalia.log(`rclone_mounts: {msg}`)
end

local function cfg(key)
    return noctalia.getConfig(key)
end

local function rcAddr()
    local addr = cfg("rc_addr")
    if type(addr) ~= "string" or addr == "" then
        return "127.0.0.1:5572"
    end
    return addr
end

-- POST params as a JSON body to an rc command path; cb(decoded, httpResponse).
-- decoded is nil on transport failure, a non-2xx status, or bad JSON.
local function rcCall(path, params, cb)
    local body = noctalia.json.encode(params or {})
    if body == nil then
        cb(nil, nil)
        return
    end

    local req = {
        url = `http://{rcAddr()}/{path}`,
        method = "POST",
        body = body,
        headers = { "Content-Type: application/json" },
    }

    local user = cfg("rc_user")
    if type(user) == "string" and user ~= "" then
        req.basic_username = user
        req.basic_password = cfg("rc_pass")
    end

    local ok = noctalia.http(req, function(res)
        if res == nil or not res.ok or res.status >= 400 then
            cb(nil, res)
            return
        end
        local decoded = noctalia.json.decode(res.body or "")
        cb(decoded, res)
    end)
    if not ok then
        cb(nil, nil)
    end
end

local function remoteNameOf(fs)
    return fs:match("^([^:]*):") or fs
end

local function publish()
    noctalia.state.set("mounts", mounts)
    noctalia.state.set("remotes", availableRemotes)
    noctalia.state.set("rcUp", rcUp)
end

-- ── vfs/stats (per mount, every tick) ───────────────────────────────────

local function applyVfsStats2(entry, decoded)
    local disk = decoded.diskCache
    local opt = decoded.opt or {}
    entry.cacheUsedBytes = disk.bytesUsed or 0
    entry.cachePath = disk.path or ""
    entry.cacheMaxBytes = if opt.CacheMaxSize ~= nil and opt.CacheMaxSize ~= -1 then opt.CacheMaxSize else -1
    entry.uploadsQueued = disk.uploadsQueued or 0
    entry.uploadsInProgress = disk.uploadsInProgress or 0
    entry.erroredFiles = disk.erroredFiles or 0
    local mode = opt.CacheMode
    entry.cacheMode = if type(mode) == "number" then (CACHE_MODE_NAMES[mode] or "unknown") else "unknown"
    entry.cacheAvailable = true
end

local function applyVfsStats(entry, vfsNames, done)
    rcCall("vfs/stats", { fs = entry.fs }, function(decoded)
        if type(decoded) ~= "table" or decoded.diskCache == nil then
            -- listmounts' Fs string didn't match the registered vfs name
            -- verbatim; fall back to a prefix match against vfs/list, same
            -- cross-check rclone_status.sh does.
            local alt = nil
            for _, name in ipairs(vfsNames) do
                if name:sub(1, #entry.remote + 1) == entry.remote .. ":" then
                    alt = name
                    break
                end
            end
            if alt ~= nil then
                rcCall("vfs/stats", { fs = alt }, function(decoded2)
                    if type(decoded2) == "table" and decoded2.diskCache ~= nil then
                        applyVfsStats2(entry, decoded2)
                    end
                    done()
                end)
                return
            end
            done()
            return
        end
        applyVfsStats2(entry, decoded)
        done()
    end)
end

-- ── vfs/queue (per mount, every tick) ────────────────────────────────────
-- This is the actual per-VFS upload queue - each item carries its own
-- `uploading` flag, which is what makes "transfers in progress" genuinely
-- scoped to this mount instead of the whole rc server.

local function applyVfsQueue(entry, done)
    rcCall("vfs/queue", { fs = entry.fs }, function(decoded)
        local items = {}
        if type(decoded) == "table" and type(decoded.queue) == "table" then
            for _, q in ipairs(decoded.queue) do
                table.insert(items, {
                    id = q.id or 0,
                    name = q.name or "",
                    size = q.size or 0,
                    uploading = q.uploading == true,
                    tries = q.tries or 0,
                })
            end
        end
        -- vfs/queue has no start-time field; "id" is assigned in queue
        -- order, so sorting by it descending is the closest available
        -- proxy for "most recently started/queued first".
        table.sort(items, function(a, b) return a.id > b.id end)
        entry.queueItems = items
        done()
    end)
end

local function applyMountData(entry, vfsNames, done)
    local pending = 2
    local function partDone()
        pending -= 1
        if pending <= 0 then done() end
    end
    applyVfsStats(entry, vfsNames, partDone)
    applyVfsQueue(entry, partDone)
end

-- ── operations/about (per remote, only on slow ticks) ───────────────────
-- A failed/timed-out fetch leaves entry.about untouched - refresh() already
-- seeded it from the previous publish, so a transient failure just keeps
-- showing the last good reading instead of blanking it.

local function applyAbout(entry, done)
    rcCall("operations/about", { fs = entry.remote .. ":" }, function(decoded)
        if type(decoded) == "table" and decoded.total ~= nil then
            entry.about = { supported = true, total = decoded.total, used = decoded.used, free = decoded.free }
        end
        done()
    end)
end

-- ── completed-transfer history (global, every tick) ──────────────────────

local function applyGlobalTransfers(statsDecoded, transferredDecoded)
    local transferredCount = if type(statsDecoded) == "table" then (statsDecoded.transfers or 0) else 0

    local transferred = {}
    if type(transferredDecoded) == "table" and type(transferredDecoded.transferred) == "table" then
        for _, t in ipairs(transferredDecoded.transferred) do
            table.insert(transferred, {
                name = t.name or "",
                error = t.error or "",
                startedAt = t.started_at or t.completed_at or "",
            })
        end
    end
    -- started_at/completed_at are ISO8601 strings ("2026-11-06T23:07:21.77...
    -- +05:30"), not a numeric timestamp - lexicographic string comparison
    -- still sorts them chronologically as long as the offset format is
    -- consistent (it is, within one rclone process), so plain string
    -- comparison is enough; no need to parse them.
    table.sort(transferred, function(a, b) return a.startedAt > b.startedAt end)

    -- core/stats' "transferring" list carries the live percentage but is
    -- global (not per-VFS); key it by name so each mount's vfs/queue items
    -- - which ARE per-VFS - can be enriched with a percentage for whichever
    -- of their files happens to be transferring right now.
    local percentByName = {}
    if type(statsDecoded) == "table" and type(statsDecoded.transferring) == "table" then
        for _, t in ipairs(statsDecoded.transferring) do
            if type(t.name) == "string" then
                percentByName[t.name] = t.percentage or 0
            end
        end
    end

    -- core/transferred has no per-VFS scoping, so completed-transfer
    -- history stays global across every mount's tab (the in-progress list
    -- above is per-mount via vfs/queue instead).
    for _, entry in ipairs(mounts) do
        entry.transferredCount = transferredCount
        entry.transferred = transferred
        if entry.queueItems ~= nil then
            for _, q in ipairs(entry.queueItems) do
                q.percentage = percentByName[q.name]
            end
        end
    end
end

local function fetchRemotes(mountedNames, done)
    rcCall("config/listremotes", {}, function(decoded)
        availableRemotes = {}
        if type(decoded) == "table" and type(decoded.remotes) == "table" then
            local seen = {}
            for _, r in ipairs(decoded.remotes) do
                local name = r:match("^(.-):?$")
                if not mountedNames[name] and not seen[name] then
                    seen[name] = true
                    table.insert(availableRemotes, name)
                end
            end
            table.sort(availableRemotes)
        end
        done()
    end)
end

-- ── full refresh cycle ───────────────────────────────────────────────────

local function refresh(doSlowRefresh)
    if refreshInFlight then return end
    refreshInFlight = true

    rcCall("core/pid", {}, function(pidDecoded)
        if type(pidDecoded) ~= "table" or pidDecoded.pid == nil then
            rcUp = false
            mounts = {}
            availableRemotes = {}
            publish()
            refreshInFlight = false
            return
        end
        rcUp = true

        rcCall("mount/listmounts", {}, function(listDecoded)
            local points = {}
            if type(listDecoded) == "table" and type(listDecoded.mountPoints) == "table" then
                points = listDecoded.mountPoints
            end

            -- Carry forward each mount's last known "about" reading so a
            -- fast (non-slow) tick doesn't blank it before the next slow
            -- refresh re-fetches it. Keyed by mountpoint, not remote name:
            -- the same remote mounted twice to different directories (e.g.
            -- mounted outside this plugin) must not collide and corrupt
            -- each other's carried-over state.
            local oldByMountpoint = {}
            for _, old in ipairs(mounts) do
                oldByMountpoint[old.mountpoint] = old
            end

            local newMounts = {}
            local mountedNames = {}
            for _, p in ipairs(points) do
                local fs = p.Fs or ""
                local remote = remoteNameOf(fs)
                local mountpoint = p.MountPoint or ""
                mountedNames[remote] = true
                local previous = oldByMountpoint[mountpoint]
                table.insert(newMounts, {
                    name = remote,
                    fs = fs,
                    remote = remote,
                    mountpoint = mountpoint,
                    cacheMode = "unknown",
                    cacheAvailable = false,
                    cacheUsedBytes = 0,
                    cacheMaxBytes = -1,
                    cachePath = "",
                    uploadsQueued = 0,
                    uploadsInProgress = 0,
                    erroredFiles = 0,
                    about = if previous ~= nil then previous.about else { supported = false },
                    queueItems = {},
                    transferredCount = 0,
                    transferred = {},
                })
            end
            mounts = newMounts

            if #mounts == 0 then
                fetchRemotes(mountedNames, function()
                    publish()
                    refreshInFlight = false
                end)
                return
            end

            rcCall("vfs/list", {}, function(vfsListDecoded)
                local vfsNames = {}
                if type(vfsListDecoded) == "table" and type(vfsListDecoded.vfses) == "table" then
                    vfsNames = vfsListDecoded.vfses
                end

                local pending = #mounts
                local function oneDone()
                    pending -= 1
                    if pending > 0 then return end

                    local function afterMountData()
                        rcCall("core/stats", {}, function(statsDecoded)
                            rcCall("core/transferred", {}, function(transferredDecoded)
                                applyGlobalTransfers(statsDecoded, transferredDecoded)
                                fetchRemotes(mountedNames, function()
                                    publish()
                                    refreshInFlight = false
                                end)
                            end)
                        end)
                    end

                    if doSlowRefresh then
                        local aboutPending = #mounts
                        for _, entry in ipairs(mounts) do
                            applyAbout(entry, function()
                                aboutPending -= 1
                                if aboutPending <= 0 then afterMountData() end
                            end)
                        end
                    else
                        afterMountData()
                    end
                end

                for _, entry in ipairs(mounts) do
                    applyMountData(entry, vfsNames, oneDone)
                end
            end)
        end)
    end)
end

-- ── mount command (from the panel's "Add" button) ────────────────────────

local function mountRemote(remote, mountpoint, cacheMode, cacheMaxSizeGiB)
    if type(remote) ~= "string" or remote == "" or type(mountpoint) ~= "string" or mountpoint == "" then
        return
    end
    if type(cacheMode) ~= "number" or CACHE_MODE_NAMES[cacheMode] == nil then
        cacheMode = 0 -- off
    end

    local vfsOpt = { CacheMode = cacheMode }
    local maxSizeLabel = "unbounded"
    if type(cacheMaxSizeGiB) == "number" and cacheMaxSizeGiB > 0 then
        -- rclone's SizeSuffix parses "G" as GiB (binary), matching --vfs-cache-max-size.
        vfsOpt.CacheMaxSize = `{cacheMaxSizeGiB}G`
        maxSizeLabel = `{cacheMaxSizeGiB} GiB`
    end

    log(`mounting {remote}: at {mountpoint} (cache mode {CACHE_MODE_NAMES[cacheMode]}, max size {maxSizeLabel})`)

    local params = {
        fs = remote .. ":",
        mountPoint = mountpoint,
        vfsOpt = vfsOpt,
        mountOpt = { AllowNonEmpty = true },
    }
    rcCall("mount/mount", params, function(decoded, res)
        if res ~= nil and res.ok and res.status < 400 then
            noctalia.notify(noctalia.tr("notify.mount_title"), noctalia.tr("notify.mount_success", { remote = remote, mountpoint = mountpoint }))
            refresh(false)
        else
            local reason = if type(decoded) == "table" and decoded.error ~= nil then tostring(decoded.error) else noctalia.tr("notify.unknown_error")
            log(`mount failed for {remote}: {reason}`)
            noctalia.notifyError(noctalia.tr("notify.mount_title"), noctalia.tr("notify.mount_failed", { error = reason }))
        end
    end)
end

-- ── unmount command (from the panel's "Unmount" button) ──────────────────

local function unmountRemote(remote, mountpoint)
    if type(mountpoint) ~= "string" or mountpoint == "" then
        return
    end
    log(`unmounting {remote or "?"} at {mountpoint}`)
    rcCall("mount/unmount", { mountPoint = mountpoint }, function(decoded, res)
        if res ~= nil and res.ok and res.status < 400 then
            noctalia.notify(noctalia.tr("notify.unmount_title"), noctalia.tr("notify.unmount_success", { remote = remote or "?", mountpoint = mountpoint }))
            refresh(false)
        else
            local reason = if type(decoded) == "table" and decoded.error ~= nil then tostring(decoded.error) else noctalia.tr("notify.unknown_error")
            log(`unmount failed for {mountpoint}: {reason}`)
            noctalia.notifyError(noctalia.tr("notify.unmount_title"), noctalia.tr("notify.unmount_failed", { error = reason }))
        end
    end)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

local function applyPollInterval()
    local seconds = cfg("poll_seconds")
    if type(seconds) ~= "number" or seconds <= 0 then
        seconds = 3
    end
    noctalia.setUpdateInterval(seconds * 1000)
end

applyPollInterval()

function onConfigChanged()
    applyPollInterval()
end

function update()
    tickCount += 1
    local doSlowRefresh = (tickCount % SLOW_REFRESH_TICKS == 1)
    refresh(doSlowRefresh)
end

noctalia.state.watch("command", function(cmd)
    if type(cmd) ~= "table" then return end
    if cmd.action == "mount" then
        mountRemote(cmd.remote, cmd.mountpoint, cmd.cacheMode, cmd.cacheMaxSizeGiB)
    elseif cmd.action == "unmount" then
        unmountRemote(cmd.remote, cmd.mountpoint)
    end
end)
