local M = {}

local lsp_kinds_map = {
  -- https://github.com/microsoft/language-server-protocol/blob/ad04bde24d0c3850dcb6ec08e802f7e69c2ee5dc/_specifications/specification-3-16.md?plain=1#L4754-L4780
  [vim.lsp.protocol.SymbolKind.File] = 'File',
  [vim.lsp.protocol.SymbolKind.Module] = 'Module',
  [vim.lsp.protocol.SymbolKind.Namespace] = 'Namespace',
  [vim.lsp.protocol.SymbolKind.Package] = 'Package',
  [vim.lsp.protocol.SymbolKind.Class] = 'Class',
  [vim.lsp.protocol.SymbolKind.Method] = 'Method',
  [vim.lsp.protocol.SymbolKind.Property] = 'Property',
  [vim.lsp.protocol.SymbolKind.Field] = 'Field',
  [vim.lsp.protocol.SymbolKind.Constructor] = 'Constructor',
  [vim.lsp.protocol.SymbolKind.Enum] = 'Enum',
  [vim.lsp.protocol.SymbolKind.Interface] = 'Interface',
  [vim.lsp.protocol.SymbolKind.Function] = 'Function',
  [vim.lsp.protocol.SymbolKind.Variable] = 'Variable',
  [vim.lsp.protocol.SymbolKind.Constant] = 'Constant',
  [vim.lsp.protocol.SymbolKind.String] = 'String',
  [vim.lsp.protocol.SymbolKind.Number] = 'Number',
  [vim.lsp.protocol.SymbolKind.Boolean] = 'Boolean',
  [vim.lsp.protocol.SymbolKind.Array] = 'Array',
  [vim.lsp.protocol.SymbolKind.Object] = 'Object',
  [vim.lsp.protocol.SymbolKind.Key] = 'Key',
  [vim.lsp.protocol.SymbolKind.Null] = 'Null',
  [vim.lsp.protocol.SymbolKind.EnumMember] = 'EnumMember',
  [vim.lsp.protocol.SymbolKind.Struct] = 'Struct',
  [vim.lsp.protocol.SymbolKind.Event] = 'Event',
  [vim.lsp.protocol.SymbolKind.Operator] = 'Operator',
  [vim.lsp.protocol.SymbolKind.TypeParameter] = 'TypeParameter',
}


---@param lsp_kinds table
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
    "# 操作提示：",
    "# <CR> or <Space> : Switch the check state",
    "# q or <Esc> : Save settings and re-render",
    "# ---------------------------------------------",
    ""
  }

  -- 將選項依序印出
  for i = 1, 26 do
    if lsp_kinds_map[i] then
      local mark = selected[i] and "[x]" or "[ ]"
      -- 排版：[x]  1 = File, [ ] 26 = TypeParameter
      table.insert(lines, string.format("%s %-2d = %s", mark, i, lsp_kinds_map[i]))
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
