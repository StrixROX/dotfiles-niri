 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#291416',
    base01 = '#452124',
    base02 = '#3e1e20',
    base03 = '#716263',
    base04 = '#b6afaf',
    base05 = '#f3f2f2',
    base06 = '#f3f2f2',
    base07 = '#f3f2f2',
    base08 = '#d15a63',
    base09 = '#d3ca5f',
    base0A = '#d6905c',
    base0B = '#e46771',
    base0C = '#e9e296',
    base0D = '#ec939a',
    base0E = '#e9b996',
    base0F = '#f4d5be',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#f3f2f2',          bg = '#291416' })
  hi('TelescopeBorder',         { fg = '#716263',             bg = '#291416' })
  hi('TelescopePromptNormal',   { fg = '#f3f2f2',          bg = '#291416' })
  hi('TelescopePromptBorder',   { fg = '#716263',             bg = '#291416' })
  hi('TelescopePromptPrefix',   { fg = '#e46771',             bg = '#291416' })
  hi('TelescopePromptCounter',  { fg = '#b6afaf',  bg = '#291416' })
  hi('TelescopePromptTitle',    { fg = '#291416',             bg = '#e46771' })
  hi('TelescopePreviewTitle',   { fg = '#291416',             bg = '#d6905c' })
  hi('TelescopeResultsTitle',   { fg = '#291416',             bg = '#d3ca5f' })
  hi('TelescopeSelection',      { fg = '#f3f2f2',          bg = '#3e1e20' })
  hi('TelescopeSelectionCaret', { fg = '#e46771',             bg = '#3e1e20' })
  hi('TelescopeMatching',       { fg = '#e46771',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#f3f2f2',          bg = '#291416' })
  hi('MiniPickBorder',         { fg = '#716263',             bg = '#291416' })
  hi('MiniPickPrompt',   { fg = '#f3f2f2',          bg = '#291416' })
  hi('MiniPickPromptPrefix',   { fg = '#e46771',             bg = '#291416' })
  hi('MiniPickBorderText',    { fg = '#291416',             bg = '#e46771' })
  hi('MiniPickMatchCurrent',      { fg = '#f3f2f2',          bg = '#3e1e20' })
  hi('MiniPickPromptCaret', { fg = '#e46771',             bg = '#3e1e20' })
  hi('MiniPickMatchRanges',       { fg = '#e46771',             bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates).
-- The handler re-requires this module, which re-runs the code below, so the
-- previous handle is stopped first; otherwise handlers double on every signal.
if _G.__matugen_signal then
  _G.__matugen_signal:stop()
  _G.__matugen_signal:close()
end

local signal = vim.uv.new_signal()
_G.__matugen_signal = signal
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
