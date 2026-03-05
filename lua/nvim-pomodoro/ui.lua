local M = {}

local timer  = require("nvim-pomodoro.timer")
local notify = require("nvim-pomodoro.notify")

local SESSION = timer.SESSION

local TABS = {
  { id = SESSION.FOCUS,       label = "🍅 Focus"       },
  { id = SESSION.SHORT_BREAK, label = "☕ Short Break" },
  { id = SESSION.LONG_BREAK,  label = "🛌 Long Break"  },
}

local HINTS = {
  "[1] Focus",
  "[2] Short Break",
  "[3] Long Break",
  "[c] Start/Pause",
  "[q] Detach",
  "[x] Close",
}

local WIDTH  = 100
local HEIGHT = 10

local state = {
  buf      = nil,
  win      = nil,
  active   = SESSION.FOCUS,
  detached = false,
}

-- ── helpers ────────────────────────────────────────────────────────────────

local function fmt_time(secs)
  return string.format("%02d:%02d", math.floor(secs / 60), secs % 60)
end

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function space_around(items, width)
  local n         = #items
  local total_len = 0
  for _, item in ipairs(items) do
    total_len = total_len + vim.fn.strdisplaywidth(item)
  end

  local total_space = width - total_len
  local slot        = total_space / n
  local left_pad    = math.floor(slot / 2)
  local right_pad   = math.floor(slot - left_pad)

  local result = ""
  for i, item in ipairs(items) do
    result = result .. string.rep(" ", left_pad) .. item .. string.rep(" ", right_pad)
    if i == n then
      local actual = vim.fn.strdisplaywidth(result)
      if actual < width then
        result = result .. string.rep(" ", width - actual)
      end
    end
  end
  return result
end

-- ── rendering ──────────────────────────────────────────────────────────────

local function render()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

  local tab_items = {}
  for _, tab in ipairs(TABS) do
    if tab.id == state.active then
      table.insert(tab_items, "[ " .. tab.label .. " ]")
    else
      table.insert(tab_items, "  " .. tab.label .. "  ")
    end
  end

  local clock      = fmt_time(timer.seconds_left())
  local status     = timer.is_running() and "▶  Running" or "⏸  Paused"
  local clock_pad  = math.floor((WIDTH - vim.fn.strdisplaywidth(clock))  / 2)
  local status_pad = math.floor((WIDTH - vim.fn.strdisplaywidth(status)) / 2)

  local lines = {
    string.rep("─", WIDTH),
    space_around(tab_items, WIDTH),
    string.rep("─", WIDTH),
    "",
    string.rep(" ", clock_pad)  .. clock,
    "",
    string.rep(" ", status_pad) .. status,
    "",
    space_around(HINTS, WIDTH),
    string.rep("─", WIDTH),
  }

  vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)
end

-- ── session handlers ───────────────────────────────────────────────────────

local function on_done(finished, nxt)
  notify.session_ended(finished, nxt)
  state.active = nxt

  if state.detached or not is_open() then
    state.detached = false
    M._open_win()
  end

  render()

  timer.start(
    function(session, _)
      state.active = session
      if is_open() then render() end
    end,
    on_done
  )
end

local function toggle_session()
  if timer.is_running() then
    timer.pause()
    render()
  else
    -- First time: no callbacks saved yet → pass them; subsequent: resume uses saved ones
    timer.resume()
    if not timer.is_running() then
      -- resume() was a no-op (never started), do a fresh start
      timer.start(
        function(session, _)
          state.active = session
          if is_open() then render() end
        end,
        on_done
      )
    end
    render()
  end
end

-- ── window management ──────────────────────────────────────────────────────

function M._open_win()
  if is_open() then return end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(state.buf, "filetype",  "pomodoro")

  local ui  = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - HEIGHT) / 2)
  local col = math.floor((ui.width  - WIDTH)  / 2)

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative  = "editor",
    width     = WIDTH,
    height    = HEIGHT,
    row       = row,
    col       = col,
    style     = "minimal",
    border    = "rounded",
    title     = " 🍅 Pomodoro ",
    title_pos = "center",
  })

  vim.api.nvim_win_set_option(state.win, "wrap",       false)
  vim.api.nvim_win_set_option(state.win, "cursorline", false)

  local o = { noremap = true, silent = true, nowait = true, buffer = state.buf }

  -- switch tabs
  vim.keymap.set("n", "1", function()
    timer.switch_session(SESSION.FOCUS)
    state.active = SESSION.FOCUS
    render()
  end, o)

  vim.keymap.set("n", "2", function()
    timer.switch_session(SESSION.SHORT_BREAK)
    state.active = SESSION.SHORT_BREAK
    render()
  end, o)

  vim.keymap.set("n", "3", function()
    timer.switch_session(SESSION.LONG_BREAK)
    state.active = SESSION.LONG_BREAK
    render()
  end, o)

  -- start / resume
  vim.keymap.set("n", "c", toggle_session, o)

  -- detach (keep timer running, hide popup)
  vim.keymap.set("n", "q",     M.detach, o)
  vim.keymap.set("n", "<Esc>", M.detach, o)

  -- close (stop timer + close popup)
  vim.keymap.set("n", "x", M.close, o)

  render()
end

-- ── public API ─────────────────────────────────────────────────────────────

function M.close()
  timer.stop()
  if is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win      = nil
  state.buf      = nil
  state.detached = false
end

function M.detach()
  if is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win      = nil
  state.buf      = nil
  state.detached = true
  vim.notify(
    "Pomodoro timer is running in the background.",
    vim.log.levels.INFO,
    { title = "Pomodoro" }
  )
end

function M.toggle()
  if is_open() then
    M.detach()
    return
  end

  state.active   = timer.current_session()
  state.detached = false
  M._open_win()
end

return M
