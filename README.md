# based.nvim

based.nvim is a Neovim plugin for quickly converting buffer text to/from hex.

## Demo

https://user-images.githubusercontent.com/43476566/208255795-f4f5e50a-bfff-4b5b-bb37-2b836bdd2005.mov

## Example configuration

```lua
local based = require("based")

-- Not necessary if you don't want to override any defaults.
-- `:help based` for information on configuration keys
based.setup({
    highlight = "MyHighlightGroup"
})

vim.api.nvim_set_keybind({ "n", "v" }, "<C-b>", based.convert)                            -- Try to detect base and convert
vim.api.nvim_set_keybind({ "n", "v" }, "<leader>Bh", function() based.convert("hex") end) -- Convert from hex
vim.api.nvim_set_keybind({ "n", "v" }, "<leader>Bd", function() based.convert("dec") end) -- Convert from decimal
```
