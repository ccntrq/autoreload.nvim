local M = {}
local uv = vim.uv or vim.loop

local defaults = {
    autoread = true,
    events = { "BufEnter", "FocusGained" },
    timer = {
        enabled = true,
        interval_ms = 3000,
        start_delay_ms = 0,
    },
    notify = {
        on_conflict = true,
        on_reload = true,
    },
}

local state = {
    timer = nil,
    group = "AutoReloadFile",
    opts = nil,
}

local function can_run_checktime()
    local in_cmdline_mode = vim.api.nvim_get_mode().mode == "c"
    local in_cmdwin = vim.fn.getcmdwintype() ~= ""
    local bufnr = vim.api.nvim_get_current_buf()
    local is_file_buffer = vim.bo[bufnr].buftype == ""
    return not in_cmdline_mode and not in_cmdwin and is_file_buffer
end

local function run_checktime()
    if can_run_checktime() then
        pcall(vim.cmd, "checktime")
    end
end

local function stop_timer()
    if state.timer then
        state.timer:stop()
        state.timer:close()
        state.timer = nil
    end
end

function M.setup(opts)
    state.opts = vim.tbl_deep_extend("force", defaults, opts or {})

    if state.opts.autoread then
        vim.opt.autoread = true
    end

    stop_timer()
    vim.api.nvim_create_augroup(state.group, { clear = true })

    vim.api.nvim_create_autocmd(state.opts.events, {
        group = state.group,
        pattern = "*",
        callback = run_checktime,
        desc = "Check for file changes when entering buffer or gaining focus",
    })

    vim.api.nvim_create_autocmd("FileChangedShell", {
        group = state.group,
        pattern = "*",
        callback = function()
            if not state.opts.notify.on_conflict then
                return
            end

            local bufnr = vim.api.nvim_get_current_buf()
            if vim.bo[bufnr].modified then
                vim.notify(
                    "File changed on disk but you have unsaved changes. Use :e! to reload from disk.",
                    vim.log.levels.WARN,
                    { title = "File Change Conflict", timeout = 0 }
                )
            end
        end,
        desc = "Notify when file changed externally with unsaved changes",
    })

    vim.api.nvim_create_autocmd("FileChangedShellPost", {
        group = state.group,
        pattern = "*",
        callback = function()
            if state.opts.notify.on_reload then
                vim.notify("File changed on disk and has been reloaded.", vim.log.levels.INFO, {
                    title = "File Reloaded",
                    timeout = 3000,
                })
            end
        end,
        desc = "Notify when file has been automatically reloaded",
    })

    if state.opts.timer.enabled then
        state.timer = uv.new_timer()
        state.timer:start(
            state.opts.timer.start_delay_ms,
            state.opts.timer.interval_ms,
            vim.schedule_wrap(run_checktime)
        )
    end
end

function M.stop()
    stop_timer()
    pcall(vim.api.nvim_del_augroup_by_name, state.group)
end

return M
