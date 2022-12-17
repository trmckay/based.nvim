# based.nvim

based.nvim is a Neovim plugin for quickly converting buffer text to/from hex.

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
