local M = {}

local lsp_kinds_map = require("helptoc.lsp").kinds_map

local config = {
  check_style = "emoji"
}


---@param lsp_kinds table 當前選擇的內容
---@param cb function 需要自定選擇後的行為
function M.open_filter_ui(lsp_kinds, cb)
  local buf = vim.api.nvim_create_buf(false, true)

  -- 將 buftype 設為 acwrite，這允許我們攔截 :w 指令
  -- vim.bo[buf].buftype = "nofile"
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"

  -- 給定一個虛擬檔名（加上 buf id 避免名稱衝突），否則 :w 會報錯 "No file name"
  vim.api.nvim_buf_set_name(buf, "HelpTOC_Filter_" .. buf)

  -- 建立當前選取狀態的快速查詢表
  local selected = {}
  for _, v in ipairs(lsp_kinds) do
    selected[v] = true
  end

  local lines = {
    "# LSP Symbols filter settings",
    "# ---------------------------------------------",
    "# Operation tips",
    "# <CR> or <Space> : Switch the check state",
    "# q or :w         : apply settings and close window",
    "# <Esc>           : Abandon changes and close",
    "# ---------------------------------------------",
    "",
    -- "# :w           : Apply settings (save but don't close)", 目前沒有辦法即時刷新TOC, 要到回到原始文件才可以，所以這樣也沒辦法preview, 不如不要

  }

  -- 將選項依序印出
  local mark
  for i = 1, 26 do
    if lsp_kinds_map[i] then
      if config.check_style == "emoji" then
        mark = selected[i] and "✅" or "🔳"
      else
        mark = selected[i] and "[v]" or "[ ]"
      end
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
  vim.bo[buf].modified = false -- 初始化為「未修改」狀態

  -- 設定浮動視窗位置（置中）
  local width = 65
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

  local ns_id = vim.api.nvim_create_namespace("helptoc")
  vim.api.nvim_win_set_hl_ns(win, ns_id)
  vim.api.nvim_set_hl(ns_id, "CursorLine", { bg = vim.g.terminal_color_4 or "#00c6ff", fg = "#003b4f" }) -- Note: 如果用✅, 🔳 游標可能會被檔住, 所以一定要CursorLine來輔助
  vim.wo.cursorline = true

  -- 綁定切換按鍵 (Toggle)
  local function toggle()
    local r = vim.api.nvim_win_get_cursor(win)[1]
    local line = vim.api.nvim_buf_get_lines(buf, r - 1, r, false)[1]

    local new_line = nil

    if config.check_style == "emoji" then
      if line:match("^🔳") then
        new_line = line:gsub("^🔳", "✅")
      elseif line:match("^✅") then
        new_line = line:gsub("^✅", "🔳")
      end
    else
      if line:match("^%[% %]") then
        new_line = line:gsub("^%[% %]", "[x]")
      elseif line:match("^%[v%]") then
        new_line = line:gsub("^%[v%]", "[ ]")
      end
    end

    if new_line then
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, r - 1, r, false, { new_line })
      vim.bo[buf].modifiable = false
      vim.bo[buf].modified = true -- 觸發已修改狀態 (標籤頁會顯示 + 號)
    end
  end

  local opts = { buffer = buf, silent = true }
  vim.keymap.set('n', '<CR>', toggle, opts)
  vim.keymap.set('n', '<Space>', toggle, opts)

  -- 儲存設定
  local function apply_settings()
    local new_kinds = {}
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local pattern = config.check_style == "emoji" and
        "^✅%s+(%d+)" or
        "^%[v%]%s+(%d+)"

    for _, l in ipairs(all_lines) do
      -- 正則匹配：抓取以 "[x]" 開頭的行，並提取後面的數字
      local id_str = l:match(pattern)
      if id_str then
        table.insert(new_kinds, tonumber(id_str))
      end
    end

    cb(new_kinds)
    if #new_kinds > 0 then
      vim.bo[buf].modified = false -- 存檔成功，清除修改標記
      return true
    end
    return false
  end

  -- 攔截 :w 與 :wq (BufWriteCmd)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      apply_settings()
      vim.api.nvim_win_close(win, true) -- 目前沒辦法preview, 所以儲完就一律關閉
    end
  })

  local function close_ui(save)
    if save then
      -- 若要求儲存但失敗(例如全不選)，則中斷並保持視窗開啟
      if not apply_settings() then return end
    end
    vim.api.nvim_win_close(win, true)
  end

  -- q = 套用並關閉
  vim.keymap.set('n', 'q', function() close_ui(true) end,
    vim.tbl_extend("force", opts, { desc = "Save and Close" }))

  -- <Esc> = 不存檔直接關閉 (放棄變更)
  vim.keymap.set('n', '<Esc>', function() close_ui(false) end,
    vim.tbl_extend("force", opts, { desc = "Discard and Close" }))
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts)
end

return M
