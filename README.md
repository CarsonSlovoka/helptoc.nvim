# HelpToc

常駐 TOC 視窗


## config

```lua
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
```

## keymap

- `q`: close
- `<CR>`: jump
- `r`: refresh
- `+`: Increase window width
- `-`: Decrease window width

## 支前的filetype

- [v] Markdown
- [v] Help
- [ ] sh
