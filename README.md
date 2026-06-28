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
  }
  foldlevel = 3,
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


## 支前的filetype


> [!NOTE] 當LSP寫 `-` 時不代表不能解析，只是使用自定的簡單方式來解析


| Support | filetype | LSP  | Note                             |
| ----    | ----     | ---- | ----                             |
| ✅      | markdown | -    |                                  |
| ✅      | help     | -    |                                  |
| ✅      | sh, bash | -    | 僅function, 且都當成level 1      |
| ✅      | lua      | ✅   |                                  |
