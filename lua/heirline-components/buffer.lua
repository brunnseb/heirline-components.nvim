-- ### Heirline-components buffer utils.
--
--  DESCRIPTION:
--  Funtions you can use to manipulate the tabline.
--  They are very useful to call from a keymapping.

--    Helpers:
--      -> is_valid                 → Checks if a buffer is valid and listed.
--      -> comparator.bufnr         → Used by the sort function
--      -> comparator.extension     → Used by the sort function
--      -> comparator.full_path     → Used by the sort function
--      -> comparator.unique_path   → Used by the sort function
--      -> comparator.modified      → Used by the sort function

--    Functions:
--      -> move          → <b / >b to move the current wintab to left/right.
--      -> nav           → ]b / [b to open the wintab on the left/right.
--      -> nav_to        → (unused) We use heirline instead for <leader>bb.
--      -> close         → <leader>C to close the current buffer but not its window.
--      -> wipe          → <leader>c to close the current buffer and its window.
--      -> close_all     → <leader>bC to close all buffers.
--      -> close_left    → <leader>bl to delete all wintabs to the left.
--      -> close_right   → <leader>br to delete all wintabs to the right.
--      -> sort          → <leader>bs to sort wintabs.
--      -> close_tab     → <leader>bd to select a wintab to close.

local M = {}
local fnamemodify = vim.fn.fnamemodify
local function bufinfo(bufnr) return vim.fn.getbufinfo(bufnr)[1] end

--- HELPERS -----------------------------------------------------------------
M.comparator = {}

--- Check if a buffer is valid.
---@param bufnr number The buffer to check.
---@return boolean # Whether the buffer is valid or not.
function M.is_valid(bufnr)
  if not bufnr then bufnr = 0 end
  return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted
end

--- Comparator of two buffer numbers.
---@param bufnr_a integer buffer number A.
---@param bufnr_b integer buffer number B.
---@return boolean comparison true if A is sorted before B,
---                           false if B should be sorted before A.
function M.comparator.bufnr(bufnr_a, bufnr_b) return bufnr_a < bufnr_b end

--- Comparator of two buffer numbers based on the file extensions.
---@param bufnr_a integer buffer number A.
---@param bufnr_b integer buffer number B.
---@return boolean comparison true if A is sorted before B,
---                           false if B should be sorted before A.
function M.comparator.extension(bufnr_a, bufnr_b)
  return fnamemodify(bufinfo(bufnr_a).name, ":e")
      < fnamemodify(bufinfo(bufnr_b).name, ":e")
end

--- Comparator of two buffer numbers based on the full path.
---@param bufnr_a integer buffer number A.
---@param bufnr_b integer buffer number B.
---@return boolean comparison true if A is sorted before B,
---                           false if B should be sorted before A.
function M.comparator.full_path(bufnr_a, bufnr_b)
  return fnamemodify(bufinfo(bufnr_a).name, ":p")
      < fnamemodify(bufinfo(bufnr_b).name, ":p")
end

--- Comparator of two buffers based on their unique path
---@param bufnr_a integer buffer number A
---@param bufnr_b integer buffer number B
---@return boolean comparison true if A is sorted before B, false if B should be sorted before A
function M.comparator.unique_path(bufnr_a, bufnr_b)
  local unique_path_bufnr_a = require("heirline-components.core.provider").unique_path() { bufnr = bufnr_a }
      .. fnamemodify(bufinfo(bufnr_a).name, ":t")
  local unique_path_bufnr_b = require("heirline-components.core.provider").unique_path() { bufnr = bufnr_b }
      .. fnamemodify(bufinfo(bufnr_b).name, ":t")

  return unique_path_bufnr_a < unique_path_bufnr_b
end

--- Comparator of two buffers based on modification date.
---@param bufnr_a integer buffer number A.
---@param bufnr_b integer buffer number B.
---@return boolean comparison true if A is sorted before B,
---                           false if B should be sorted before A.
function M.comparator.modified(bufnr_a, bufnr_b)
  return bufinfo(bufnr_a).lastused > bufinfo(bufnr_b).lastused
end

--- FUNCTIONS ---------------------------------------------------------------
--- Move the current buffer tab n places in the bufferline.
---@param n number The number of tabs to move the current buffer over
---                by (positive = right, negative = left)
function M.move(n)
  if n == 0 then return end                         -- if n = 0 then no shifts are needed
  local bufs = vim.t.bufs                           -- make temp variable
  for i, bufnr in ipairs(bufs) do                   -- loop to find current buffer
    if bufnr == vim.api.nvim_get_current_buf() then -- found index of current buffer
      for _ = 0, (n % #bufs) - 1 do                 -- calculate number of right shifts
        local new_i = i + 1                         -- get next i
        if i == #bufs then                          -- if at end, cycle to beginning
          new_i = 1                                 -- next i is actually 1 if at the end
          local val = bufs[i]                       -- save value
          table.remove(bufs, i)                     -- remove from end
          table.insert(bufs, new_i, val)            -- insert at beginning
        else                                        -- if not at the end,then just do an in place swap
          bufs[i], bufs[new_i] = bufs[new_i], bufs[i]
        end
        i = new_i -- iterate i to next value
      end
      break
    end
  end
  vim.t.bufs = bufs       -- set buffers
  require("heirline-components.utils").trigger_event("User HeirlineComponentsTablineBuffersUpdated")
  vim.cmd.redrawtabline() -- redraw tabline
end

--- Navigate left and right by n places in the bufferline.
-- @param n number The number of tabs to navigate to (positive = right, negative = left).
function M.nav(n)
  local current = vim.api.nvim_get_current_buf()
  for i, v in ipairs(vim.t.bufs) do
    if current == v then
      vim.cmd.b(vim.t.bufs[(i + n - 1) % #vim.t.bufs + 1])
      break
    end
  end
end

--- Navigate to a specific buffer by its position in the bufferline.
---@param tabnr number The position of the buffer to navigate to.
function M.nav_to(tabnr)
  if tabnr > #vim.t.bufs or tabnr < 1 then
    require("heirline-components.utils").notify(("No tab #%d"):format(tabnr), vim.log.levels.WARN)
  else
    vim.cmd.b(vim.t.bufs[tabnr])
  end
end

--- Close a given buffer.
---@param bufnr? number The buffer to close or the current buffer
---                     if not provided.
---@param force? boolean Whether or not to foce close the buffers,
---                      or confirm changes (default: false).
function M.close(bufnr, force)
  if not bufnr or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  if require("heirline-components.utils").is_available "mini.bufremove" and M.is_valid(bufnr) and #vim.t.bufs > 1 then
    if not force and vim.api.nvim_get_option_value("modified", { buf = bufnr }) then
      local bufname = vim.fn.expand "%"
      local empty = bufname == ""
      if empty then bufname = "Untitled" end
      local confirm = vim.fn.confirm(
        ('Save changes to "%s"?'):format(bufname),
        "&Yes\n&No\n&Cancel",
        1,
        "Question"
      )
      if confirm == 1 then
        if empty then return end
        vim.cmd.write()
      elseif confirm == 2 then
        force = true
      else
        return
      end
    end
    require("mini.bufremove").delete(bufnr, force)
  else
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
    vim.cmd(("silent! %s %d"):format((force or buftype == "terminal") and "bdelete!" or "confirm bdelete", bufnr))
  end
end

--- Close the current window and the specified buffer,
--- asking for confirmation if unsaved.
---@param bufnr? number The buffer to close,
---                     or the current buffer if not provided.
---@param force? boolean Whether or not to force close the buffers,
---                      or confirm changes (default: false).
function M.wipe(bufnr, force)

  -- Helper function
  local function is_last_valid_window()
    local nwins = 0
    for _, window in ipairs(vim.api.nvim_list_wins()) do
      local buffer = vim.api.nvim_win_get_buf(window)
      if vim.api.nvim_buf_get_option(buffer, 'buftype') ~= "nofile" then
        nwins = nwins + 1
      end
    end

    local result = nwins <= 1
    return result
  end

  -- Helper function
  local function close_all_nofile_bufs()
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_option(buffer, 'buftype') == "nofile" then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end
  end

  -- This line prevents sidebars from overtaking the visual space when the last
  -- window is closed.
  if is_last_valid_window() then close_all_nofile_bufs() end

  if force == nil then force = false end
  if require("heirline-components.utils").is_available "mini.bufremove" then
    M.close(bufnr, force)   -- close buffer(s)
    vim.cmd "silent! close" -- close current window
  else
    vim.cmd(
      (force and "bd!" or "confirm bd") .. (bufnr == nil and "" or bufnr)
    )
    vim.cmd "silent! close"
  end
end

--- Close all buffers.
---@param keep_current? boolean Whether or not to keep the current buffer
---                             (default: false).
---@param force? boolean Whether or not to foce close the buffers
---                      or confirm changes (default: false).
function M.close_all(keep_current, force)
  if keep_current == nil then keep_current = false end
  local current = vim.api.nvim_get_current_buf()
  for _, bufnr in ipairs(vim.t.bufs) do
    if not keep_current or bufnr ~= current then M.close(bufnr, force) end
  end
end

--- Close buffers to the left of the current buffer.
---@param force? boolean Whether or not to foce close the buffers
---                      or confirm changes (default: false).
function M.close_left(force)
  local current = vim.api.nvim_get_current_buf()
  for _, bufnr in ipairs(vim.t.bufs) do
    if bufnr == current then break end
    M.close(bufnr, force)
  end
end

--- Close buffers to the right of the current buffer.
---@param force? boolean Whether or not to foce close the buffers
---                      or confirm changes (default: false).
function M.close_right(force)
  local current = vim.api.nvim_get_current_buf()
  local after_current = false
  for _, bufnr in ipairs(vim.t.bufs) do
    if after_current then M.close(bufnr, force) end
    if bufnr == current then after_current = true end
  end
end

--- Sort a the buffers in the current tab based on some comparator.
---@param compare_func string|function a string of a comparator defined in
---                                    require("heirline-components.buffer").comparator
---                                    or a custom comparator function.
---@param skip_autocmd boolean|nil whether or not to skip triggering
---                                BaseBufsUpdated autocmd event.
---@return boolean # Whether or not the buffers were sorted.
function M.sort(compare_func, skip_autocmd)
  if type(compare_func) == "string" then
    compare_func = M.comparator[compare_func]
  end
  if type(compare_func) == "function" then
    local bufs = vim.t.bufs
    table.sort(bufs, compare_func)
    vim.t.bufs = bufs
    if not skip_autocmd then require("heirline-components.utils").trigger_event("User HeirlineComponentsTablineBuffersUpdated") end
    vim.cmd.redrawtabline()
    return true
  end
  return false
end

--- Close the current tab.
function M.close_tab()
  if #vim.api.nvim_list_tabpages() > 1 then
    vim.t.bufs = nil
    require("heirline-components.utils").trigger_event("User HeirlineComponentsTablineBuffersUpdated")
    vim.cmd.tabclose()
  end
end

return M
