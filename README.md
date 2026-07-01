# HelpToc

常駐 TOC 視窗


## config

```lua
local config = {
  width = 38,
  position = "right", -- "right" 或 "left"
  auto_refresh = true,
  indent_size = "tree",  -- {auto 用抓預設的indent_size, 數字, tree} 如果是tree的indent_size都是用3, 因為會在前綴用`─,│,─,│,┌,┐,┘`. 用非tree則不會有這些前綴
  highlight = {
    heading1 = "Title",
    heading2 = "Function",
    heading3 = "Label",
    tree_lines = "Comment",

    cursor_line = nil,
    -- cursor_line = { link = "CursorLine" }
    -- cursor_line = cursor_line = { bg = vim.g.terminal_color_4 or "#00c6ff", fg = "#003b4f" }
  }
  foldlevel = 3,

  enable = {
    kind_icon = true, -- 預設啟用. 在名稱前加上圖標，輔助識別: 󰈙, 󰏒, 󰌗, 󰏖, 󰠱, 󰆧, 󰜢, 󰜢, 󰙅, 󰉺, 󰒓, 󰊕, 󰀫, 󰏿, 󰙅, 󰉺, , 󰆕, 󰅲
    symbol_highlight = true, -- 在kind_icon啟動時，是不是要針對不同的icon給上不同的顏色
  }
  lsp_kinds = {
    -- https://github.com/microsoft/language-server-protocol/blob/ad04bde24d0c3850dcb6ec08e802f7e69c2ee5dc/_specifications/specification-3-16.md?plain=1#L4754-L4780
    -- ...
    vim.lsp.protocol.SymbolKind.Property,
    -- ...
    vim.lsp.protocol.SymbolKind.Function,
    -- ...
  }
}
```

## command

- `:Helptoc`

## keymap

- `q`: close
- `<CR>`: jump
- `r`: refresh

- `+`: Increase window width
- `-`: Decrease window width

- `H`: Decrease Fold Level (Collapse)
- `L`: Increase Fold Level (Expand)

- `F`: Filter LSP Symbol Kinds


## 支前的filetype


> [!NOTE] 當LSP寫 `-` 時不代表不能解析，只是使用自定的簡單方式來解析


| Support | filetype      | LSP  | Note                                            |
| :--:    | ----          | :--: | ----                                            |
| ✅      | markdown      | -    |                                                 |
| ✅      | help          | -    |                                                 |
| ✅      | sh, bash      | -    | 僅function, 且都當成level 1                     |
| ✅      | lua           | ✅   |                                                 |
| ✅      | rust          | ✅   |                                                 |
| ✅      | go            | ✅   |                                                 |
| ✅      | python        | ✅   |                                                 |
| ✅      | swift         | ✅   |                                                 |
| ✅      | javascript    | ✅   |                                                 |
| ✅      | ...           | ✅   | 有lsp的都能使用                                 |


> [!NOTE] 上面有註記LSP的項目，是有測試過，確定能使用且效果還可以的項目
>
> 至於其它的語言，其實只要有lsp支持，都能靠夠使用


## TODO

- [ ] 多window支持: 當前使用winid, bufid這些變數是單一的，所以當前最多不能在一個window使用. 也就是開兩個tab分別想在不同的md中都使用，就沒有辦法

