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
            hex = { "^h(%x*)" },
            dec = { "^d(%x*)", "^(%d*)$" },
        },
        dts = {
            hex = { "^0[xX](%x*)$", "@(%x*)$" },
            dec = { "^(%d*)$" },
        },
    },
    renderer = function(n, base, winnr, line)
        local hint

        if base == "hex" then
            hint = string.format(" => %d", n, n)
        elseif base == "dec" then
            hint = string.format(" => 0x%x", n, n)
        else
            return
        end

        local bufnr = vim.api.nvim_win_get_buf(winnr)

        if not extmark_ns then
            extmark_ns = vim.api.nvim_create_namespace("Based")
        end

        local id = vim.api.nvim_buf_set_extmark(bufnr or 0, extmark_ns, line - 1, -1, {
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

local buf_parse_int = function(str, base, bufnr)
    local ft_patterns = M.opts.patterns[vim.api.nvim_buf_get_option(bufnr or 0, "filetype")]

    if base == "hex" then
        parse_int(str, 16, vim.list_extend(ft_patterns.hex, { "(%x*)" }))
    end

    if base == "dec" then
        parse_int(str, 10, vim.list_extend(ft_patterns.dec, { "(%d*)" }))
    end

    local n = parse_int(str, 16, ft_patterns.hex)
    if n then
        return n, "hex"
    end
    n = parse_int(str, 10, ft_patterns.dec)
    if n  then
        return n, "dec"
    end
end

local clear_hints = function()
    for _, id in ipairs(extmark_ids) do
        vim.api.nvim_buf_del_extmark(0, extmark_ns, id)
    end
    extmark_ids = {}
end

vim.api.nvim_create_autocmd("CursorMoved,ModeChanged", {
    pattern = "*",
    group = vim.api.nvim_create_augroup("Based", { clear = true }),
    callback = clear_hints,
})

local parse_and_render = function(str, base, winnr, line)
    winnr = winnr or vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    local n, found_base = buf_parse_int(str, base, bufnr)
    if n then
        M.opts.renderer(n, found_base, winnr, line)
    end
end

local cword = function(base)
    parse_and_render(vim.fn.expand("<cword>"), base, 0, vim.api.nvim_win_get_cursor(0)[1])
end

local visual = function(base)
    local a_orig = vim.fn.getreg("a")
    local mode = vim.fn.mode()
    if mode ~= "v" and mode ~= "V" then
        vim.cmd([[normal! gv]])
    end
    vim.cmd([[normal! "aygv]])
    local selection = vim.fn.getreg("a")
    vim.fn.setreg("a", a_orig)
    local line = vim.fn.getpos("v")[2]
    for offset, line_text in ipairs(vim.fn.split(selection, "\n")) do
        local _, _, text = line_text:find("^%s*(.*)%s*$")
        parse_and_render(text, base, 0, line + offset - 1)
    end
end

M.convert = function(base)
    if vim.fn.mode() == "n" then
        cword(base)
    else
        visual(base)
    end
end

vim.api.nvim_create_user_command("BasedConvert", function(opts)
    M.convert(opts.fargs[1])
end, { nargs = "?" })

M.setup = function(user_opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, user_opts)
end

return M
