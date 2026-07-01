local M = {}

M.kinds_map = {
  -- https://github.com/microsoft/language-server-protocol/blob/ad04bde24d0c3850dcb6ec08e802f7e69c2ee5dc/_specifications/specification-3-16.md?plain=1#L4754-L4780
  [vim.lsp.protocol.SymbolKind.File]          = { icon = "󰈙", name = "File", hl = "SymbolKindFile" },
  [vim.lsp.protocol.SymbolKind.Module]        = { icon = "󰏒", name = "Module", hl = "SymbolKindModule" },
  [vim.lsp.protocol.SymbolKind.Namespace]     = { icon = "󰌗", name = "Namespace", hl = "SymbolKindNamespace" },
  [vim.lsp.protocol.SymbolKind.Package]       = { icon = "󰏖", name = "Package", hl = "SymbolKindPackage" },
  [vim.lsp.protocol.SymbolKind.Class]         = { icon = "󰠱", name = "Class", hl = "SymbolKindClass" }, --C
  [vim.lsp.protocol.SymbolKind.Method]        = { icon = "󰆧", name = "Method", hl = "SymbolKindMethod" }, --m
  [vim.lsp.protocol.SymbolKind.Property]      = { icon = "󰜢", name = "Property", hl = "SymbolKindProperty" },
  [vim.lsp.protocol.SymbolKind.Field]         = { icon = "󰜢", name = "Field", hl = "SymbolKindField" },
  [vim.lsp.protocol.SymbolKind.Constructor]   = { icon = "󰙅", name = "Constructor", hl = "SymbolKindConstructor" },
  [vim.lsp.protocol.SymbolKind.Enum]          = { icon = "󰉺", name = "Enum", hl = "SymbolKindEnum" }, --E
  [vim.lsp.protocol.SymbolKind.Interface]     = { icon = "󰒓", name = "Interface", hl = "SymbolKindInterface" }, --I
  [vim.lsp.protocol.SymbolKind.Function]      = { icon = "󰊕", name = "Function", hl = "SymbolKindFunction" }, --ƒ
  [vim.lsp.protocol.SymbolKind.Variable]      = { icon = "󰀫", name = "Variable", hl = "SymbolKindVariable" },
  [vim.lsp.protocol.SymbolKind.Constant]      = { icon = "󰏿", name = "Constant", hl = "SymbolKindConstant" },

  [vim.lsp.protocol.SymbolKind.String]        = { icon = "󰅳", name = "String", hl = "SymbolKindString" },
  [vim.lsp.protocol.SymbolKind.Number]        = { icon = "󰎠", name = "Number", hl = "SymbolKindNumber" },
  [vim.lsp.protocol.SymbolKind.Boolean]       = { icon = "󰨙", name = "Boolean", hl = "SymbolKindBoolean" },

  [vim.lsp.protocol.SymbolKind.Array]         = { icon = "󰅨", name = "Array", hl = "SymbolKindArray" },
  [vim.lsp.protocol.SymbolKind.Object]        = { icon = "󰙅", name = "Object", hl = "SymbolKindObject" },
  [vim.lsp.protocol.SymbolKind.Key]           = { icon = "󰌆", name = "Key", hl = "SymbolKindKey" },

  [vim.lsp.protocol.SymbolKind.Null]          = { icon = "󰟢", name = "Null", hl = "SymbolKindNull" },

  [vim.lsp.protocol.SymbolKind.EnumMember]    = { icon = "󰉺", name = "EnumMember", hl = "SymbolKindEnumMember" },
  [vim.lsp.protocol.SymbolKind.Struct]        = { icon = "󰙅", name = "Struct", hl = "SymbolKindStruct" }, --S
  [vim.lsp.protocol.SymbolKind.Event]         = { icon = "", name = "Event", hl = "SymbolKindEvent" },
  [vim.lsp.protocol.SymbolKind.Operator]      = { icon = "󰆕", name = "Operator", hl = "SymbolKindOperator" },
  [vim.lsp.protocol.SymbolKind.TypeParameter] = { icon = "󰅲", name = "TypeParameter", hl = "SymbolKindTypeParameter" },
}

return M
