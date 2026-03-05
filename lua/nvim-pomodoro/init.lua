local M = {}

function M.setup(user_opts)
  local config = require("nvim-pomodoro.config")
  local opts   = config.merge(user_opts)

  local timer = require("nvim-pomodoro.timer")
  local ui    = require("nvim-pomodoro.ui")

  timer.setup(opts)

  vim.api.nvim_create_user_command("Pomodoro", function()
    ui.toggle()
  end, { desc = "Toggle Pomodoro popup" })

  if opts.keymap and opts.keymap ~= "" then
    vim.keymap.set("n", opts.keymap, ui.toggle, {
      desc   = "Toggle Pomodoro popup",
      silent = true,
    })
  end
end

return M
