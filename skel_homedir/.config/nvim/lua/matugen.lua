 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#27132a',
    base01 = '#341a38',
    base02 = '#412046',
    base03 = '#6f6271',
    base04 = '#b5afb6',
    base05 = '#f3f2f3',
    base06 = '#f3f2f3',
    base07 = '#f3f2f3',
    base08 = '#fd4663',
    base09 = '#cc6673',
    base0A = '#d65ca8',
    base0B = '#d567e4',
    base0C = '#e996a0',
    base0D = '#e193ec',
    base0E = '#e996c9',
    base0F = '#f4bedf',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#f3f2f3',          bg = '#27132a' })
  hi('TelescopeBorder',         { fg = '#6f6271',             bg = '#27132a' })
  hi('TelescopePromptNormal',   { fg = '#f3f2f3',          bg = '#27132a' })
  hi('TelescopePromptBorder',   { fg = '#6f6271',             bg = '#27132a' })
  hi('TelescopePromptPrefix',   { fg = '#d567e4',             bg = '#27132a' })
  hi('TelescopePromptCounter',  { fg = '#b5afb6',  bg = '#27132a' })
  hi('TelescopePromptTitle',    { fg = '#27132a',             bg = '#d567e4' })
  hi('TelescopePreviewTitle',   { fg = '#27132a',             bg = '#d65ca8' })
  hi('TelescopeResultsTitle',   { fg = '#27132a',             bg = '#cc6673' })
  hi('TelescopeSelection',      { fg = '#f3f2f3',          bg = '#412046' })
  hi('TelescopeSelectionCaret', { fg = '#d567e4',             bg = '#412046' })
  hi('TelescopeMatching',       { fg = '#d567e4',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#f3f2f3',          bg = '#27132a' })
  hi('MiniPickBorder',         { fg = '#6f6271',             bg = '#27132a' })
  hi('MiniPickPrompt',   { fg = '#f3f2f3',          bg = '#27132a' })
  hi('MiniPickPromptPrefix',   { fg = '#d567e4',             bg = '#27132a' })
  hi('MiniPickBorderText',    { fg = '#27132a',             bg = '#d567e4' })
  hi('MiniPickMatchCurrent',      { fg = '#f3f2f3',          bg = '#412046' })
  hi('MiniPickPromptCaret', { fg = '#d567e4',             bg = '#412046' })
  hi('MiniPickMatchRanges',       { fg = '#d567e4',             bold = true })
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
