local M = {}

local lsp_kinds_map = require("helptoc.lsp").kinds_map


---@param lsp_kinds table 當前選擇的內容
---@param cb function 需要自定選擇後的行為
function M.open_filter_ui(lsp_kinds, cb)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"

  -- 建立當前選取狀態的快速查詢表
  local selected = {}
  for _, v in ipairs(lsp_kinds) do
    selected[v] = true
  end

  local lines = {
    "# LSP Symbols filter settings",
    "# ---------------------------------------------",
    "# Operation tips:",
    "# <CR> or <Space> : Switch the check state",
    "# q or <Esc> : Save settings and re-render",
    "# ---------------------------------------------",
    ""
  }

  -- 將選項依序印出
  for i = 1, 26 do
    if lsp_kinds_map[i] then
      local mark = selected[i] and "[x]" or "[ ]"
      -- 排版：
      -- [x]  1 = 󰈙 File,
      -- [ ] 26 = 󰅲 TypeParameter
      table.insert(lines, string.format("%s %-2d = %s %s",
        mark, i,
        lsp_kinds_map[i].icon, lsp_kinds_map[i].name
      ))
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- 設定浮動視窗位置（置中）
  local width = 45
  local height = #lines + 1
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Filter Kinds ",
    title_pos = "center",
  })

  -- 綁定切換按鍵 (Toggle)
  local function toggle()
    local r = vim.api.nvim_win_get_cursor(win)[1]
    local line = vim.api.nvim_buf_get_lines(buf, r - 1, r, false)[1]

    local new_line = nil
    if line:match("^%[% %]") then
      new_line = line:gsub("^%[% %]", "[x]")
    elseif line:match("^%[x%]") then
      new_line = line:gsub("^%[x%]", "[ ]")
    end

    if new_line then
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, r - 1, r, false, { new_line })
      vim.bo[buf].modifiable = false
    end
  end

  vim.keymap.set('n', '<CR>', toggle, { buffer = buf, silent = true })
  vim.keymap.set('n', '<Space>', toggle, { buffer = buf, silent = true })

  -- 綁定儲存並離開的按鍵
  local function apply_and_close()
    local new_kinds = {}
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    for _, l in ipairs(all_lines) do
      -- 正則匹配：抓取以 "[x]" 開頭的行，並提取後面的數字
      local id_str = l:match("^%[x%]%s+(%d+)")
      if id_str then
        table.insert(new_kinds, tonumber(id_str))
      end
    end

    cb(new_kinds)
    vim.api.nvim_win_close(win, true)
  end

  vim.keymap.set('n', 'q', apply_and_close, { buffer = buf, silent = true })
  vim.keymap.set('n', '<Esc>', apply_and_close, { buffer = buf, silent = true })
end

return M
