local M = {}

M.opts = {}

local extmark_ns
local extmark_ids = {}

local defaults = {
    patterns = {
        c = {
            hex = { "^0[xX](%x*)$" },
            dec = { "^(%d*)$" },
        },
        verilog = {
            hex = { "^h(%x*)" },
            dec = { "^d(%x*)", "^(%d*)$" },
        },
        systemverilog = {
            hex = { "%h(%x*)" },
            dec = { "%d(%x*)", "^(%d*)$" },
        },
    },
    renderer = function(n, base, winnr)
        local hint

        if base == "hex" then
            hint = string.format(" => %d", n, n)
        elseif base == "dec" then
            hint = string.format(" => 0x%x", n, n)
        else
            return
        end

        local cursor = vim.api.nvim_win_get_cursor(winnr)
        local bufnr = vim.api.nvim_win_get_buf(winnr)

        if not extmark_ns then
            extmark_ns = vim.api.nvim_create_namespace("Based")
        end

        local id = vim.api.nvim_buf_set_extmark(bufnr or 0, extmark_ns, cursor[1] - 1, -1, {
            virt_text_pos = "overlay",
            virt_text = {
                { hint, M.opts.highlight },
            },
        })

        table.insert(extmark_ids, id)
    end,
    highlight = "Comment",
}

M.opts = defaults

-- Use C-like pattern-matching if the filetype is not defined
setmetatable(defaults.patterns, {
    __index = function(table, _)
        return table.c
    end,
})

local parse_int = function(str, base, base_patterns)
    for _, p in ipairs(base_patterns) do
        local _, _, digits = str:find(p)
        if digits then
            local n = tonumber(digits, base)
            if n then
                return n
            end
        end
    end
end

local buf_parse_int = function(str, bufnr)
    local ft_patterns = M.opts.patterns[vim.api.nvim_buf_get_option(bufnr or 0, "filetype")]
    local n = parse_int(str, 16, ft_patterns.hex)
    if n then
        return n, "hex"
    end
    n = parse_int(str, 10, ft_patterns.dec)
    if n then
        return n, "dec"
    end
end

local clear_hints = function()
    for _, id in ipairs(extmark_ids) do
        vim.api.nvim_buf_del_extmark(0, extmark_ns, id)
    end
    extmark_ids = {}
end

vim.api.nvim_create_autocmd("CursorMoved", {
    pattern = "*",
    group = vim.api.nvim_create_augroup("Based", { clear = true }),
    callback = clear_hints,
})

M.parse_and_render = function(str, winnr)
    winnr = winnr or vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    local n, base = buf_parse_int(str, bufnr)
    if n then
        M.opts.renderer(n, base, winnr)
    end
end

M.cword = function()
    M.parse_and_render(vim.fn.expand("<cword>"))
end

vim.api.nvim_create_user_command("BasedConvert", M.cword, { nargs = 0 })

M.setup = function(user_opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, user_opts)
end

return M
