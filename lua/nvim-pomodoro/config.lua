local M = {}

M.defaults = {
  focus_time               = 25,  -- minutes
  break_time               = 5,   -- minutes
  long_break_time          = 15,  -- minutes
  cycles_before_long_break = 4,
  keymap                   = "<leader>p",
}

function M.merge(user_opts)
  return vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
