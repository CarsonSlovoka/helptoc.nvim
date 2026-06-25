-- Markdown + Help 常駐 TOC 視窗

local M = {}

local winid = nil
local bufid = nil
local ns_id = vim.api.nvim_create_namespace("helptoc")

-- 用來儲存 TOC 行號 → 原 buffer 行號 的對應表
local toc_to_lnum = {}

local pattern = {
  "*.md", "*.markdown",
  "*/doc/*.txt",
  "*.sh", "*.bash",
  "*.lua",
}

-- ==================== 配置 ====================
local config = {
  width = 38,
  position = "right", -- "right" 或 "left"
  auto_refresh = true,
  indent_size = "auto",
  highlight = {
    heading1 = "Title",
    heading2 = "Function",
    heading3 = "Label",
  }
}

-- ==================== LSP ====================
-- 取得 LSP Symbols 的封裝
local function get_lsp_symbols(bufnr)
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  vim.lsp.buf_request(bufnr, "textDocument/documentSymbol", params, function(err, result, ctx, config)
    if err or not result then return end
    local entries = {}

    local function process_symbols(list, depth)
      for _, sym in ipairs(list) do
        -- 6: Method, 12: Function
        if sym.kind == 6 or sym.kind == 12 then
          table.insert(entries, {
            lnum = sym.selectionRange.start.line + 1,
            level = depth,
            text = sym.name
          })
        end
        if sym.children then process_symbols(sym.children, depth + 1) end
      end
    end
    process_symbols(result, 1)
    M.render_toc(entries) -- 拿到資料後呼叫渲染
  end)
end

-- ==================== Parser ====================
function M.render_toc(entries)
  if not winid or not vim.api.nvim_win_is_valid(winid) then return end
  local toc_buf = vim.api.nvim_win_get_buf(winid)

  local lines = {}
  toc_to_lnum = {}
  local highlights = {}
  local indent_size = config.indent_size == "auto" and
      vim.api.nvim_get_option_value("shiftwidth", {}) or
      config.indent_size

  for i, entry in ipairs(entries) do
    local indent = string.rep(string.rep(" ", indent_size), entry.level - 1)
    table.insert(lines, indent .. entry.text)
    toc_to_lnum[i] = entry.lnum

    -- 根據層級設定 Highlight
    local hl_group =
        (entry.level == 1 and config.highlight.heading1) or
        (entry.level == 2 and config.highlight.heading2) or
        config.highlight.heading3 or "Normal"
    table.insert(highlights, { #lines - 1, hl_group })
  end

  vim.bo[toc_buf].modifiable = true
  vim.api.nvim_buf_set_lines(toc_buf, 0, -1, false, lines)

  -- 清空舊 highlight
  vim.api.nvim_buf_clear_namespace(toc_buf, ns_id, 0, -1)

  -- 套用 highlight
  for _, hl in ipairs(highlights) do
    -- vim.api.nvim_buf_add_highlight(toc_buf, ns_id, hl[2], hl[1], 0, -1) -- 此方法已棄用
    vim.hl.range(toc_buf, ns_id, hl[2], { hl[1], 0 }, { hl[1], -1 })
    -- vim.hl.range(buf, ns_id, hl.highlight, { hl.line_num, hl.start_col }, { hl.line_num, hl.end_col }) -- ns_id不可以用0，一定要建立
  end
  vim.bo[toc_buf].modifiable = false
end

local function parse_markdown(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local entries = {}

  local in_code_block = false

  for lnum, line in ipairs(lines) do
    if line:match("^```") then
      in_code_block = not in_code_block
    end

    if in_code_block then
      goto continue
    end

    -- ATX headings (# ## ### ...)
    local level = line:match("^#+%s+")
    if level then
      local text = line:gsub("^#+%s*", "")
      table.insert(entries, {
        lnum = lnum,
        level = #level - 1, -- # -> 1, ## -> 2
        text = text,
        raw = line,
      })
    end

    ::continue::
  end
  return entries
end

local function parse_help(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local entries = {}

  for lnum, line in ipairs(lines) do
    -- 主要標題（大寫開頭 + *tag*）
    if line:match("^%u[A-Z0-9 .()-]*%s*%*") or line:match("^%s*%*.*%*$") then
      local text = line:gsub("%s*%*.*%*$", ""):gsub("^%s*", "")
      if text:match("%S") then
        table.insert(entries, {
          lnum = lnum,
          level = 1,
          text = text,
        })
      end
      -- 次要標題（較短的大寫行）
    elseif line:match("^%s*[A-Z][A-Z0-9 .()-]+$") then
      local text = vim.trim(line)
      if #text > 3 and not text:match("^%s*$") then
        table.insert(entries, {
          lnum = lnum,
          level = 2,
          text = text,
        })
      end
    end
  end
  return entries
end

local function parse_bash(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local entries = {}

  for lnum, line in ipairs(lines) do
    local func_name

    -- 形式1: function name() {
    func_name = line:match("^%s*function%s+([%w_][%w_0-9]*)")
    if not func_name then
      -- 形式2: name() {
      func_name = line:match("^%s*([%w_][%w_0-9]*)%s*%(%s*%)%s*{")
    end

    if func_name then
      table.insert(entries, {
        lnum = lnum,
        level = 1, -- function 統一當作 level 1
        text = func_name,
        -- text = "ƒ " .. func_name, -- 加符號區別 (可以考慮)
      })
    end
  end
  return entries
end

local function parse_lua(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local entries = {}

  for lnum, line in ipairs(lines) do
    local func_name

    -- 1. function name(...)
    func_name = line:match("^%s*function%s+([%w_][%w_0-9%.]*)%s*%(")

    -- 2. local function name(...)
    if not func_name then
      func_name = line:match("^%s*local%s+function%s+([%w_][%w_0-9]*)%s*%(")
    end

    -- 3. name = function(...)
    if not func_name then
      func_name = line:match("^%s*([%w_][%w_0-9%.]*)%s*=%s*function%s*%(")
    end

    -- 4. local name = function(...)
    if not func_name then
      func_name = line:match("^%s*local%s+([%w_][%w_0-9%.]*)%s*=%s*function%s*%(")
    end

    if func_name then
      -- 清理多餘的 table 前綴（例如 mytable.func → func）
      func_name = func_name:match("%.([^%.]+)$") or func_name
      table.insert(entries, {
        lnum = lnum,
        level = 1,
        text = "λ " .. func_name, -- 用 λ 符號區別 Lua function
      })
    end
  end
  return entries
end

local function get_entries(bufnr)
  local ft = vim.bo[bufnr].filetype
  if ft == "markdown" then
    return parse_markdown(bufnr)
  elseif ft == "help" then
    return parse_help(bufnr)
  elseif ft == "sh" or ft == "bash" then
    return parse_bash(bufnr)
  elseif ft == "lua" then
    return parse_lua(bufnr)
  else
    return {}
  end
end

-- ==================== 視窗管理 ====================
local function create_toc_buffer()
  if bufid and vim.api.nvim_buf_is_valid(bufid) then
    return bufid
  end
  bufid = vim.api.nvim_create_buf(false, true)
  -- vim.bo[bufid].filetype = "helptoc"
  vim.bo[bufid].filetype = "markdown" -- 如果有做link, img等conceal時，也能呈現
  vim.bo[bufid].buftype = "nofile"
  vim.bo[bufid].modifiable = false
  return bufid
end

function M.open()
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_set_current_win(winid)
    M.refresh()
    return
  end

  local main_win = vim.api.nvim_get_current_win()
  -- local main_buf = vim.api.nvim_get_current_buf()

  -- 建立 TOC buffer
  local toc_buf = create_toc_buffer()

  -- 開啟垂直分割
  vim.cmd(config.position == "left" and "leftabove vsplit" or "rightbelow vsplit")
  winid = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(winid, toc_buf)
  vim.api.nvim_win_set_width(winid, config.width)

  -- 設定 window 選項
  vim.wo[winid].winfixwidth = true
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].foldcolumn = "0"
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false

  -- Keymaps (當前buffer才有的keymap)
  local opts = { noremap = true, silent = true, buffer = toc_buf }
  vim.keymap.set("n", "<CR>", function() M.jump_to_entry(main_win) end, opts)
  vim.keymap.set("n", "q", function() M.close() end, opts)
  vim.keymap.set("n", "r", M.refresh, opts)


  vim.keymap.set('n', '+', '<cmd>vertical resize +2<cr>',
    vim.tbl_deep_extend("force", opts, { desc = 'Increase window width' }))
  vim.keymap.set('n', '-', '<cmd>vertical resize -2<cr>',
    vim.tbl_deep_extend("force", opts, { desc = 'Decrease window width' }))


  M.refresh()
end

function M.close()
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
    winid = nil
    toc_to_lnum = {}
  end
end

function M.refresh()
  if not (winid and vim.api.nvim_win_is_valid(winid)) then
    return
  end

  local main_win = vim.fn.win_getid(0) == winid and vim.fn.winnr("#") or 0
  local main_buf = vim.api.nvim_win_get_buf(main_win)
  local ft = vim.bo[main_buf].filetype

  -- 如果是 Lua 且有 LSP client，走 LSP 流程
  if ft == "lua" and #vim.lsp.get_clients({ bufnr = main_buf }) > 0 then
    -- Note: lsp 是異步的, 所以只能在裡面觸發render_toc
    get_lsp_symbols(main_buf)
  else
    -- 其他情況或無 LSP 時，退回使用原本的靜態 Parser
    local entries = get_entries(main_buf)
    M.render_toc(entries)
  end
end

function M.toggle()
  if winid then
    M.close()
  else
    M.open()
  end
end

function M.jump_to_entry(main_win)
  if not winid or not vim.api.nvim_win_is_valid(winid) then return end

  local toc_row = vim.api.nvim_win_get_cursor(0)[1]
  local target_lnum = toc_to_lnum[toc_row]

  if not target_lnum then return end

  -- 切換回主視窗並跳轉到精準行號
  vim.api.nvim_set_current_win(main_win)
  vim.api.nvim_win_set_cursor(main_win, { target_lnum, 0 })

  -- 可選：置中畫面
  -- vim.cmd("normal! zz")
end

-- ==================== 自動命令 ====================
function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged" }, {
    pattern = pattern,
    callback = function()
      if winid and vim.api.nvim_win_is_valid(winid) then
        vim.schedule(M.refresh)
      end
    end,
  })

  -- 快捷鍵建議
  -- vim.keymap.set("n", "<leader>co", M.open, { desc = "開啟 HelpTOC 常駐視窗" })
  -- vim.keymap.set("n", "<leader>cc", M.close, { desc = "關閉 HelpTOC" })

  -- vim.api.nvim_create_user_command('HelpToc', M.toggle, { desc = "開啟/關閉 HelpTOC 常駐視窗" })
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = pattern,
    callback = function()
      vim.api.nvim_buf_create_user_command(0, 'Helptoc', function(args)
          if args.fargs[1] == "open" then
            M.open()
          elseif args.fargs[1] == "close" then
            M.close()
          else
            M.toggle()
          end
        end,
        {
          desc = "Open/close the HelpTOC resident window",
          nargs = "?",
          complete = function(arg_lead)
            return vim.fn.matchfuzzy({ "open", "close" }, arg_lead)
          end,
        })
    end,
  })
end

return M
