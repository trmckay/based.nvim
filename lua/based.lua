local M = {}


-- Extmark namespace in which to render virtual hint text
local extmark_ns


-- List of currently visible extmarks
local extmark_ids = {}


-- Default options
M.opts = {
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
    -- Render a hint
    --
    -- @param n number: the parsed value of an integer
    -- @param base string: the integer base ("hex" or "dec")
    -- @param winnr number: the window in which to render the hint
    -- @param line number: the line at which the number was parsed
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


-- Use C-like (effectively default) pattern-matching if the filetype is not defined
setmetatable(M.opts.patterns, {
    __index = function(table, _)
        return table.c
    end,
})


-- Given a list of patterns, try to parse an int with the given base
--
-- @param str string: what to parse
-- @param base number: integer base
-- @param base_patterns list[string]: list of lua-patterns
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


-- Parse an integer in the current buffer
--
-- @param str string: what to parse
-- @param base number|nil: integer base, nil if autodetected
-- @param bufnr number: used to get patterns for the buffer's filetype
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


-- Clear all hints from all windows
local clear_hints = function()
    for _, id in ipairs(extmark_ids) do
        vim.api.nvim_buf_del_extmark(0, extmark_ns, id)
    end
    extmark_ids = {}
end


-- Clear all hints when something happens
vim.api.nvim_create_autocmd("CursorMoved,ModeChanged,WinLeave", {
    pattern = "*",
    group = vim.api.nvim_create_augroup("Based", { clear = true }),
    callback = clear_hints,
})


-- Parse a string as an integer and render the hint
--
-- @param str string: what to parse
-- @param base number|nil: integer base, nil if autodetected
-- @param winnr number: window number
-- @param line number: line number
local parse_and_render = function(str, base, winnr, line)
    clear_hints()
    winnr = winnr or vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    local n, found_base = buf_parse_int(str, base, bufnr)
    if n then
        M.opts.renderer(n, found_base, winnr, line)
    end
end

-- Parse and convert the cursor word
--
-- @param base number|nil: integer base, nil if autodetected
local cword = function(base)
    parse_and_render(vim.fn.expand("<cword>"), base, 0, vim.api.nvim_win_get_cursor(0)[1])
end


-- Parse and convert a single-line visual selection
--
-- @param base number|nil: integer base, nil if autodetected
local visual = function(base)
    local vstart = vim.fn.getpos("v")
    local vend = vim.fn.getpos(".")

    -- TODO: I don't think there is an intuitive way to support multi-line selections,
    -- but maybe there is a good way to do this.
    if vend[2] - vstart[2] ~= 0 then
        return
    end

    local line = vstart[2] - 1

    -- Get single-line visual selection and strip leading/trailing whitespace
    local selection = vim.api.nvim_buf_get_lines(0, line, line + 1, false)[1]
    selection = selection:sub(vstart[3], vend[3])
    _, _, selection = selection:find("^%s*(.*)%s*$")

    parse_and_render(selection, base, 0, line + 1)
end


-- Parse and convert the cursor word when in normal mode or the
-- visual selection when in visual mode.
--
-- @param base number|nil: integer base, nil if autodetected
M.convert = function(base)
    local mode = vim.fn.mode()
    if mode == "n" then
        cword(base)
    elseif mode == "v" or mode == "V" then
        visual(base)
    end
end

-- Expose the lua API as a user-command
vim.api.nvim_create_user_command("BasedConvert", function(opts)
    M.convert(opts.fargs[1])
end, { nargs = "?" })


-- Change the defaults
--
-- @param user_opts table: see `:h based` for details
M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts)
end


return M
