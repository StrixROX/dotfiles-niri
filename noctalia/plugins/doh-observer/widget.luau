local POLLING_RATE = noctalia.getConfig("poll_interval_ms") or 5000
local SERVICE_NAME = "doh-client.service"

local STATUS_MSG = {
  active = {
    text = "Online",
    glyph = "network",
  },
  inactive = {
    text = "Offline",
    glyph = "network-off",
  },
  failed = {
    text = "Failed",
    glyph = "network-off",
  },
  loading = {
    text = "Loading",
    glyph = "refresh",
  },
}
local DEFAULT_STATUS = "loading"
local FAILED_STATUS = "failed"
local LOADING_STATUS = "loading"

local status = DEFAULT_STATUS

local function render()
  barWidget.setText(STATUS_MSG[status].text)
  barWidget.setGlyph(STATUS_MSG[status].glyph)
end

local function checkServiceStatus()
  local function callback(result)
    local new_status = result.stdout

    if STATUS_MSG[new_status] then
      status = new_status
    else
      status = DEFAULT_STATUS
    end
  end

  noctalia.runAsync({ "systemctl", "is-active", SERVICE_NAME }, callback)
end

local function restartFailedService()
  noctalia.runAsync({ "systemctl", "reset-failed", SERVICE_NAME }, function(res)
    if res.exitCode ~= 0 then
      update()
    else
      noctalia.runAsync({ "systemctl", "start", SERVICE_NAME }, update)
    end
  end)
end

function update()
  checkServiceStatus()
  render()
end

function onClick()
  if status == FAILED_STATUS then
    status = LOADING_STATUS
    render()

    restartFailedService()
  else
    update()
  end
end

noctalia.setUpdateInterval(POLLING_RATE)
checkServiceStatus()
render()

