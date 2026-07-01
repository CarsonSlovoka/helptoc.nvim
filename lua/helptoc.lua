-- Markdown + Help 常駐 TOC 視窗

local group = vim.api.nvim_create_augroup("HelpToc", {})
local M = {
  group = group
}

local winid = nil
local bufid = nil
local ns_id = vim.api.nvim_create_namespace("helptoc")

local toc_to_lnum = {} -- { toc_row = main_lnum } -- 用來儲存 TOC 行號 → 原 buffer 行號 的對應表
local lnum_to_toc = {} -- { main_lnum = toc_row } -- 反查表


local sorted_lnums = {} -- sync_cursor 中使用

local pattern = {
  "*.*",
  -- "*.md", "*.markdown",
  "*/doc/*.txt",
  -- "*.sh", "*.bash",
  -- "*.lua",
  -- "*.go",
  -- "*.rs",
  -- "*.py"
}

-- ==================== 配置 ====================
local config = {
  width = 38,
  position = "right", -- "right" 或 "left"
  auto_refresh = true,

  indent_size = "tree", -- number, auto, tree

  highlight = {
    heading1 = "Title",
    heading2 = "Function",
    heading3 = "Label",
    tree_lines = "Comment",
    cursor_line = nil, -- { link = "CursorLine" }, { bg = "#2f3e54" }
  },

  foldlevel = 3, -- 如果設定太多，不直接異動foldlevel下用熱鍵H, L調整要很久

  enable = {
    kind_icon = true,        -- 輔助識別: 󰈙, 󰏒, 󰌗, 󰏖, 󰠱, 󰆧, 󰜢, 󰜢, 󰙅, 󰉺, 󰒓, 󰊕, 󰀫, 󰏿, 󰙅, 󰉺, , 󰆕, 󰅲
    symbol_highlight = true, -- 在kind_icon啟動時，是不是要針對不同的icon給上不同的顏色
  },

  lsp_kinds = {
    -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/ 搜尋: CompletionItemKind
    -- https://github.com/microsoft/language-server-protocol/blob/ad04bde24d0c3850dcb6ec08e802f7e69c2ee5dc/_specifications/specification-3-16.md?plain=1#L4754-L4780
    vim.lsp.protocol.SymbolKind.Module,
    vim.lsp.protocol.SymbolKind.Namespace,
    vim.lsp.protocol.SymbolKind.Package,
    vim.lsp.protocol.SymbolKind.Class,
    vim.lsp.protocol.SymbolKind.Method,
    vim.lsp.protocol.SymbolKind.Property,
    vim.lsp.protocol.SymbolKind.Field,
    vim.lsp.protocol.SymbolKind.Constructor,
    vim.lsp.protocol.SymbolKind.Enum,
    vim.lsp.protocol.SymbolKind.Interface,
    vim.lsp.protocol.SymbolKind.Function,

    vim.lsp.protocol.SymbolKind.Constant,

    -- 👇這幾個滿多的呈現出來有好有壞(可能太雜)  可以用篩選的方式
    -- vim.lsp.protocol.SymbolKind.Array,
    -- vim.lsp.protocol.SymbolKind.Object,
    -- vim.lsp.protocol.SymbolKind.Key,

    vim.lsp.protocol.SymbolKind.EnumMember,
    vim.lsp.protocol.SymbolKind.Struct,
  },
}

-- ==================== 折疊運算 (Fold Expression) ====================
-- 定義全域函數供 Neovim 的 foldexpr 調用
_G.__helptoc_foldexpr = function()
  local lnum = vim.v.lnum
  local buf = vim.api.nvim_get_current_buf()
  local levels = vim.b[buf].helptoc_levels

  if not levels then return "0" end

  local cur_level = levels[lnum] or 0
  local next_level = levels[lnum + 1] or 0

  -- 如果下一行的層級更深，代表當前行是一個折疊區塊的起點 (使用 ">" 標記)
  if next_level > cur_level then
    return ">" .. cur_level
  else
    return tostring(cur_level)
  end
end

-- ==================== Icon, Highlight ====================
local function setup_highlights()
  local hl = vim.api.nvim_set_hl

  hl(ns_id, "SymbolKindFile", { fg = "#c0caf5" })
  hl(ns_id, "SymbolKindModule", { fg = "#c0caf5" })
  hl(ns_id, "SymbolKindNamespace", { fg = "#c0caf5" })
  hl(ns_id, "SymbolKindPackage", { fg = "#c0caf5" })
  hl(ns_id, "SymbolKindClass", { fg = "#7aa2f7", bold = true })
  hl(ns_id, "SymbolKindMethod", { fg = "#bb9af7", bold = true })
  hl(ns_id, "SymbolKindProperty", { fg = "#73daca" })
  hl(ns_id, "SymbolKindField", { fg = "#73daca" })
  hl(ns_id, "SymbolKindConstructor", { fg = "#9ece6a", bold = true })
  hl(ns_id, "SymbolKindEnum", { fg = "#ff9e64", bold = true })
  hl(ns_id, "SymbolKindInterface", { fg = "#73daca", bold = true })
  hl(ns_id, "SymbolKindFunction", { fg = "#9ece6a", bold = true })
  hl(ns_id, "SymbolKindVariable", { fg = "#bb9af7" })
  hl(ns_id, "SymbolKindConstant", { fg = "#ff9e64", bold = true })

  hl(ns_id, "SymbolKindString", { link = "Normal" })
  hl(ns_id, "SymbolKindNumber", { link = "Normal" })
  hl(ns_id, "SymbolKindBoolean", { link = "Normal" })

  hl(ns_id, "SymbolKindArray", { fg = "#e0af68" })
  hl(ns_id, "SymbolKindObject", { fg = "#e0af68" })
  hl(ns_id, "SymbolKindKey", { fg = "#bb9af7" })

  hl(ns_id, "SymbolKindNull", { link = "Normal" })

  hl(ns_id, "SymbolKindEnumMember", { fg = "#ff9e64" })
  hl(ns_id, "SymbolKindStruct", { fg = "#e0af68", bold = true })
  hl(ns_id, "SymbolKindEvent", { fg = "#ff9e64" })
  hl(ns_id, "SymbolKindOperator", { fg = "#73daca" })
  hl(ns_id, "SymbolKindTypeParameter", { fg = "#73daca", bold = true })
end

local kind_icons = {
  [vim.lsp.protocol.SymbolKind.File]          = { icon = "󰈙", hl = "SymbolKindFile" },
  [vim.lsp.protocol.SymbolKind.Module]        = { icon = "󰏒", hl = "SymbolKindModule" },
  [vim.lsp.protocol.SymbolKind.Namespace]     = { icon = "󰌗", hl = "SymbolKindNamespace" },
  [vim.lsp.protocol.SymbolKind.Package]       = { icon = "󰏖", hl = "SymbolKindPackage" },
  [vim.lsp.protocol.SymbolKind.Class]         = { icon = "󰠱", hl = "SymbolKindClass" }, --C
  [vim.lsp.protocol.SymbolKind.Method]        = { icon = "󰆧", hl = "SymbolKindMethod" }, --m
  [vim.lsp.protocol.SymbolKind.Property]      = { icon = "󰜢", hl = "SymbolKindProperty" },
  [vim.lsp.protocol.SymbolKind.Field]         = { icon = "󰜢", hl = "SymbolKindField" },
  [vim.lsp.protocol.SymbolKind.Constructor]   = { icon = "󰙅", hl = "SymbolKindConstructor" },
  [vim.lsp.protocol.SymbolKind.Enum]          = { icon = "󰉺", hl = "SymbolKindEnum" }, --E
  [vim.lsp.protocol.SymbolKind.Interface]     = { icon = "󰒓", hl = "SymbolKindInterface" }, --I
  [vim.lsp.protocol.SymbolKind.Function]      = { icon = "󰊕", hl = "SymbolKindFunction" }, --ƒ
  [vim.lsp.protocol.SymbolKind.Variable]      = { icon = "󰀫", hl = "SymbolKindVariable" },
  [vim.lsp.protocol.SymbolKind.Constant]      = { icon = "󰏿", hl = "SymbolKindConstant" },

  [vim.lsp.protocol.SymbolKind.String]        = { icon = "󰅳", hl = "SymbolKindString" },
  [vim.lsp.protocol.SymbolKind.Number]        = { icon = "󰎠", hl = "SymbolKindNumber" },
  [vim.lsp.protocol.SymbolKind.Boolean]       = { icon = "󰨙", hl = "SymbolKindBoolean" },

  [vim.lsp.protocol.SymbolKind.Array]         = { icon = "󰅨", hl = "SymbolKindArray" },
  [vim.lsp.protocol.SymbolKind.Object]        = { icon = "󰙅", hl = "SymbolKindObject" },
  [vim.lsp.protocol.SymbolKind.Key]           = { icon = "󰌆", hl = "SymbolKindKey" },

  [vim.lsp.protocol.SymbolKind.Null]          = { icon = "󰟢", hl = "SymbolKindNull" },

  [vim.lsp.protocol.SymbolKind.EnumMember]    = { icon = "󰉺", hl = "SymbolKindEnumMember" },
  [vim.lsp.protocol.SymbolKind.Struct]        = { icon = "󰙅", hl = "SymbolKindStruct" }, --S
  [vim.lsp.protocol.SymbolKind.Event]         = { icon = "", hl = "SymbolKindEvent" },
  [vim.lsp.protocol.SymbolKind.Operator]      = { icon = "󰆕", hl = "SymbolKindOperator" },
  [vim.lsp.protocol.SymbolKind.TypeParameter] = { icon = "󰅲", hl = "SymbolKindTypeParameter" },
}


-- ==================== LSP ====================
-- 取得 LSP Symbols 的封裝
local function get_lsp_symbols(bufnr)
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  vim.lsp.buf_request(bufnr, "textDocument/documentSymbol", params, function(err, result, ctx, _config)
    if err or not result then return end
    local entries = {}

    local function process_symbols(list, depth)
      for _, sym in ipairs(list) do
        if vim.tbl_contains(config.lsp_kinds, sym.kind) then
          table.insert(entries, {
            lnum = sym.selectionRange.start.line + 1,
            level = depth,
            text = sym.name,
            kind_icon = kind_icons[sym.kind] or { icon = "" }
          })
        end
        if sym.children then process_symbols(sym.children, depth + 1) end
      end
    end
    process_symbols(result, 1)
    M.render_toc(entries)
  end)
end

-- ==================== render ====================
function M.render_toc(entries)
  if not winid or not vim.api.nvim_win_is_valid(winid) then return end
  local toc_buf = vim.api.nvim_win_get_buf(winid)

  local lines = {}
  toc_to_lnum = {}
  local highlights = {}
  local fold_levels = {} -- 收集折疊層級

  local use_tree = config.indent_size == "tree"
  local indent_spaces = 0
  if not use_tree then
    indent_spaces = config.indent_size == "auto" and
        vim.api.nvim_get_option_value("shiftwidth", {}) or
        tonumber(config.indent_size) or 2
  end

  -- 1. 若使用 tree，預先計算每個節點是否為其所在分支的最後一個子節點
  local is_last = {}
  if use_tree then
    for i, entry in ipairs(entries) do
      is_last[i] = true
      for j = i + 1, #entries do
        if entries[j].level < entry.level then
          break              -- 遇到更淺層（上層）的標題，代表當前分支已結束
        elseif entries[j].level == entry.level then
          is_last[i] = false -- 遇到同層級的下一個標題，所以不是最後一個
          break
        end
      end
    end
  end

  -- 2. 構建文字與計算 Highlighting 範圍
  for i, entry in ipairs(entries) do
    local prefix = "" --   ─   │   ─   │   ┌   ┐   ┘

    if use_tree then
      if entry.level > 1 then
        -- 尋找對應層級 d 的祖先節點
        for d = 1, entry.level - 1 do
          local is_ancestor_last = true
          for p = i - 1, 1, -1 do
            if entries[p].level == d then
              is_ancestor_last = is_last[p]
              break
            end
          end
          if d == entry.level - 1 then
            -- 當前節點的前綴：判斷是否為分支的最後一個，畫分支符號
            prefix = prefix .. (is_last[i] and "└─ " or "├─ ")
          else
            -- 更上層祖先的前綴：如果上層分支還沒結束，需要畫垂直延伸線
            prefix = prefix .. (is_ancestor_last and "   " or "│  ")
          end
        end
      end
    else
      -- 原始空白縮排邏輯
      prefix = string.rep(string.rep(" ", indent_spaces), entry.level - 1)
    end

    if config.enable.kind_icon then
      table.insert(lines, prefix .. entry.kind_icon.icon .. " " .. entry.text)
    else
      table.insert(lines, prefix .. entry.text)
    end
    toc_to_lnum[i] = entry.lnum
    lnum_to_toc[entry.lnum] = i
    fold_levels[i] = entry.level -- 記錄行號對應的真實層級

    -- 判斷該層級文字的 Highlight
    local text_hl_group =
        (entry.level == 1 and config.highlight.heading1) or
        (entry.level == 2 and config.highlight.heading2) or
        config.highlight.heading3 or "Normal"

    -- 記錄此行的 highlight 資訊 (使用 byte length 來精確切分前綴與文字)
    table.insert(highlights, {
      line = #lines - 1,
      prefix_len = #prefix,
      text_hl = text_hl_group,
      kind_icon = config.enable.kind_icon and entry.kind_icon or {},
    })
  end

  -- Note: vim.b 與 vim.bo 不同. vim.bo 有指定的屬性不能隨意新增變數
  vim.b[toc_buf].helptoc_levels = fold_levels -- 新增此buffer的屬性，供 foldexpr 使用.
  vim.bo[toc_buf].modifiable = true
  vim.api.nvim_buf_set_lines(toc_buf, 0, -1, false, lines)

  -- 清空舊 highlight
  vim.api.nvim_buf_clear_namespace(toc_buf, ns_id, 0, -1)

  -- 套用 highlight
  for _, item in ipairs(highlights) do
    -- 如果是 Tree 模式且有前綴符號，幫前綴套上 Comment 顏色
    if use_tree and item.prefix_len > 0 then
      vim.hl.range(toc_buf, ns_id, config.highlight.tree_lines, { item.line, 0 }, { item.line, item.prefix_len })
    end

    -- vim.api.nvim_buf_add_highlight(toc_buf, ns_id, hl[2], hl[1], 0, -1) -- 此方法已棄用
    vim.hl.range(toc_buf, ns_id, item.text_hl, { item.line, item.prefix_len }, { item.line, -1 })
    -- vim.hl.range(buf, ns_id, hl.highlight, { hl.line_num, hl.start_col }, { hl.line_num, hl.end_col }) -- ns_id不可以用0，一定要建立

    -- 再往回設定kind_icon的顏色
    if config.enable.symbol_highlight and item.kind_icon.hl then
      vim.hl.range(toc_buf, ns_id, item.kind_icon.hl,
        { item.line, item.prefix_len },
        { item.line, item.prefix_len + #(item.kind_icon and item.kind_icon.icon or "") }
      )
    end
  end

  if config.highlight.cursor_line then
    vim.api.nvim_win_set_hl_ns(winid, ns_id)
    vim.api.nvim_set_hl(ns_id, "CursorLine", config.highlight.cursor_line) -- Note: 如果想要用指定的ns_id，一定要用 nvim_win_set_hl_ns 或 nvim_set_hl_ns 先激活後使用才會有效
  end

  vim.bo[toc_buf].modifiable = false
end

-- ==================== Parser ====================
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
        kind_icon = { icon = "" },
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
          kind_icon = { icon = "" },
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
          kind_icon = { icon = "" },
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
        kind_icon = { icon = "" },
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
        text = func_name,
        kind_icon = kind_icons[vim.lsp.protocol.SymbolKind.Function],
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

  -- local group = vim.api.nvim_create_augroup("HelpTocSync", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = vim.api.nvim_win_get_buf(main_win),
    callback = M.sync_cursor,
  })

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

  -- 設定動態折疊 (Fold)
  vim.wo[winid].foldmethod = "expr"
  vim.wo[winid].foldexpr = "v:lua.__helptoc_foldexpr()"
  vim.wo[winid].foldenable = true
  vim.wo[winid].foldlevel = config.foldlevel -- 預設全展開

  -- Keymaps (當前buffer才有的keymap)
  local opts = { noremap = true, silent = true, buffer = toc_buf }
  vim.keymap.set("n", "<CR>", function() M.jump_to_entry(main_win) end, opts)
  vim.keymap.set("n", "q", function() M.close() end, opts)
  vim.keymap.set("n", "r", M.refresh, opts)


  vim.keymap.set('n', '+', '<cmd>vertical resize +2<cr>',
    vim.tbl_deep_extend("force", opts, { desc = 'Increase window width' }))
  vim.keymap.set('n', '-', '<cmd>vertical resize -2<cr>',
    vim.tbl_deep_extend("force", opts, { desc = 'Decrease window width' }))

  -- 折疊層級控制 (H: 減少 foldlevel, L: 增加 foldlevel)
  vim.keymap.set("n", "H", function()
    local current_level = vim.wo[winid].foldlevel
    vim.wo[winid].foldlevel = math.max(0, current_level - 1)
  end, vim.tbl_deep_extend("force", opts, { desc = "Decrease Fold Level (Collapse)" }))

  vim.keymap.set("n", "L", function()
    local current_level = vim.wo[winid].foldlevel
    vim.wo[winid].foldlevel = math.min(6, current_level + 1)
  end, vim.tbl_deep_extend("force", opts, { desc = "Increase Fold Level (Expand)" }))


  -- LSP Kinds 的熱鍵
  -- vim.keymap.set("n", "<leader>f", function() -- 這可行，但是不直覺
  --     local current_kinds = table.concat(config.lsp_kinds, ", ")
  --
  --     vim.ui.input({
  --       prompt = "Enter LSP Kinds (comma-separated, e.g. 6,12,14): ",
  --       default = current_kinds
  --     }, function(input)
  --       -- 如果使用者按 Esc 取消，input 會是 nil
  --       if not input then
  --         return
  --       end
  --
  --       local new_kinds = {}
  --       -- 利用正則表達式抓取字串中的所有數字
  --       for num_str in input:gmatch("%d+") do
  --         table.insert(new_kinds, tonumber(num_str))
  --       end
  --       print(vim.inspect(new_kinds))
  --
  --       if #new_kinds > 0 then
  --         config.lsp_kinds = new_kinds
  --         M.refresh()
  --         vim.api.nvim_input("<C-w>p")
  --         vim.notify("LSP Kinds updated to: " .. table.concat(new_kinds, ", "), vim.log.levels.INFO)
  --       else
  --         vim.notify("Invalid input. Kinds must be numbers.", vim.log.levels.WARN)
  --       end
  --     end)
  --   end,
  --   vim.tbl_deep_extend("force", opts, { desc = "Filter LSP Symbol Kinds" })
  -- )
  vim.keymap.set("n", "<leader>f", function()
      require("helptoc.ui.filter-lsp").open_filter_ui(config.lsp_kinds, function(new_kinds)
        if #new_kinds > 0 then
          config.lsp_kinds = new_kinds
          M.refresh()
          vim.api.nvim_input("<C-w>p")
        else
          vim.notify("HelpTOC: At least one item must be selected, changes have been discarded.", vim.log.levels.WARN)
        end
      end)
    end,
    vim.tbl_deep_extend("force", opts, { desc = "Filter LSP Symbol Kinds" })
  )


  if config.enable.symbol_highlight then
    setup_highlights()
  end
  M.refresh()

  -- autocmd
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    desc = "[Helptoc] Make sure: q will automatically close it so that it can be opened again next time",
    -- pattern = pattern, -- 不能和buf一起使用
    buf = bufid,
    callback = function()
      M.close()
    end
  })

  vim.api.nvim_input("<C-w>pl") -- 回到前一個window, 使得TOC可以依據該文本來更新end
end

function M.close()
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
    winid = nil
    toc_to_lnum = {}
    lnum_to_toc = {}
    pcall(vim.api.nvim_del_augroup_by_name, "HelpTocSync")
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
  if #vim.lsp.get_clients({ bufnr = main_buf }) > 0 then
    -- Note: lsp 是異步的, 所以只能在裡面觸發render_toc
    get_lsp_symbols(main_buf)
  else
    -- 其他情況或無 LSP 時，退回使用原本的靜態 Parser
    local entries = get_entries(main_buf)
    M.render_toc(entries)
  end

  sorted_lnums = vim.tbl_keys(lnum_to_toc)
  table.sort(sorted_lnums)
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

-- 同步游標位置的函數
function M.sync_cursor()
  if not (winid and vim.api.nvim_win_is_valid(winid)) then return end

  local main_win = vim.api.nvim_get_current_win()
  -- 只有當焦點在主視窗時才處理同步，避免死循環
  if main_win == winid then
    return
  end

  local main_lnum = vim.api.nvim_win_get_cursor(main_win)[1]

  -- 找最近的 TOC entry (處理游標在兩個標題之間的情況)
  -- 二分搜尋找最大的 lnum <= main_lnum
  local target_toc_line = nil
  local left, right = 1, #sorted_lnums
  -- local n = 0  -- 小的文件可能找3, 4次，很大的TOC, 差不多找7, 8次就能找到
  while left <= right do
    -- n = n + 1
    local mid = math.floor((left + right) / 2)
    local lnum = sorted_lnums[mid]

    if lnum <= main_lnum then
      target_toc_line = lnum_to_toc[lnum]
      left = mid + 1 -- 繼續往右找更大的（更接近）
    else
      right = mid - 1
    end
  end
  -- print("找了 " .. n)

  local line_count = vim.api.nvim_buf_line_count(bufid or 0)
  if target_toc_line and target_toc_line > line_count then
    -- 已經離開了視窗，可能用tab切到另一個窗口，而TOC不再該窗口，這樣去移動會遇到`Invalid cursor Line: out of range`的錯誤
    -- 因此這種情況就直接關閉, 避免一直做無用的計算.
    -- TODO: 如果日後有支持多窗口，就可以改善這問題
    -- print("close")
    M.close()
    return
  end
  if target_toc_line and target_toc_line <= line_count then
    vim.api.nvim_win_set_cursor(winid, { target_toc_line, 0 })

    -- 可選：讓 TOC 視窗捲動一下，確保目標在視窗中間 -- Note: 如果 `vim.opt.scrolloff = 999` 已經是這樣了，那麼其實這個不設定也沒差
    vim.api.nvim_win_call(winid, function() vim.cmd("normal! zz") end)
  end
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
          local cmd = args.fargs[1]
          if cmd == "open" then
            M.open()
          elseif cmd == "close" then
            M.close()
          elseif cmd == "kinds" and args.fargs[2] then
            -- 允許輸入 :Helptoc kinds 6,12,14
            local new_kinds = {}
            for num_str in args.fargs[2]:gmatch("%d+") do
              table.insert(new_kinds, tonumber(num_str))
            end
            if #new_kinds > 0 then
              config.lsp_kinds = new_kinds
              M.refresh()
            end
          else
            M.toggle()
          end
        end,
        {
          desc = "Control HelpTOC window",
          nargs = "*",
          complete = function(a)
            local cmp_list = { "open", "close", "kinds" }
            return #a > 0 and vim.fn.matchfuzzy(cmp_list, a) or cmp_list
          end,
        })
    end,
  })
end

return M
