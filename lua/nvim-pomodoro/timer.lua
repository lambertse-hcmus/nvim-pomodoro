local M = {}

M.SESSION = {
  FOCUS       = 1,
  SHORT_BREAK = 2,
  LONG_BREAK  = 3,
}

local state = {
  session      = M.SESSION.FOCUS,
  seconds_left = 0,
  cycle        = 0,
  running      = false,
  handle       = nil,
  opts         = {},
  on_tick      = nil,   -- saved so resume() can restart without re-passing callbacks
  on_done      = nil,
}

-- ── helpers ────────────────────────────────────────────────────────────────

local function session_duration(session, opts)
  if session == M.SESSION.FOCUS       then return opts.focus_time      * 60 end
  if session == M.SESSION.SHORT_BREAK then return opts.break_time      * 60 end
  if session == M.SESSION.LONG_BREAK  then return opts.long_break_time * 60 end
end

local function next_session()
  if state.session == M.SESSION.FOCUS then
    state.cycle = state.cycle + 1
    if state.cycle >= state.opts.cycles_before_long_break then
      state.cycle = 0
      return M.SESSION.LONG_BREAK
    end
    return M.SESSION.SHORT_BREAK
  end
  return M.SESSION.FOCUS
end

local function stop_handle()
  if state.handle then
    state.handle:stop()
    state.handle:close()
    state.handle = nil
  end
end

-- ── public API ─────────────────────────────────────────────────────────────

function M.setup(opts)
  state.opts         = opts
  state.session      = M.SESSION.FOCUS
  state.seconds_left = session_duration(M.SESSION.FOCUS, opts)
  state.cycle        = 0
  state.running      = false
  state.on_tick      = nil
  state.on_done      = nil
  stop_handle()
end

function M.start(on_tick, on_done)
  if state.running then return end

  -- persist callbacks so resume() works without arguments
  state.on_tick = on_tick
  state.on_done = on_done
  state.running = true

  state.handle = vim.loop.new_timer()
  state.handle:start(0, 1000, vim.schedule_wrap(function()
    if not state.running then return end

    if state.on_tick then
      state.on_tick(state.session, state.seconds_left)
    end

    if state.seconds_left <= 0 then
      local finished     = state.session
      state.running      = false
      stop_handle()

      local nxt          = next_session()
      state.session      = nxt
      state.seconds_left = session_duration(nxt, state.opts)

      if state.on_done then
        state.on_done(finished, nxt)
      end
      return
    end

    state.seconds_left = state.seconds_left - 1
  end))
end

-- Pause: stop the uv handle but keep seconds_left and callbacks intact
function M.pause()
  if not state.running then return end
  state.running = false
  stop_handle()
end

-- Resume: restart the tick using the saved callbacks
function M.resume()
  if state.running then return end
  if not state.on_tick or not state.on_done then return end
  M.start(state.on_tick, state.on_done)
end

-- Full stop: clears everything
function M.stop()
  state.running = false
  state.on_tick = nil
  state.on_done = nil
  stop_handle()
end

function M.is_running()
  return state.running
end

function M.current_session()
  return state.session
end

function M.seconds_left()
  return state.seconds_left
end

function M.switch_session(session)
  M.stop()
  state.session      = session
  state.seconds_left = session_duration(session, state.opts)
end

return M
