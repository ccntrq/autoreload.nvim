local M = {}
M.version = "1.0.0"
local uv = vim.uv or vim.loop

local defaults = {
    autoread = true,
    events = { "BufEnter", "FocusGained" },
    timer = {
        enabled = true,
        interval_ms = 3000,
        start_delay_ms = 0,
    },
    conflict = {
        -- How to handle a disk change that collides with unsaved buffer edits:
        --   "prompt" - blocking modal dialog you must answer to proceed
        --   "notify" - non-blocking warning notification (default)
        --   "none"   - keep the buffer silently, do nothing
        strategy = "notify",
        -- Actions offered (and their order) in the "prompt" dialog.
        actions = { "reload", "keep", "diff" },
        -- Action used when the dialog is dismissed with <Esc>.
        default = "keep",
    },
    notify = {
        on_conflict = true, -- legacy alias for conflict.strategy
        on_reload = true,
    },
}

local state = {
    timer = nil,
    group = "AutoReloadFile",
    opts = nil,
}

local action_labels = {
    reload = "&Reload (discard mine)",
    keep = "&Keep mine",
    diff = "&Diff against disk",
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

local function buffer_name(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        return "[No Name]"
    end
    return vim.fn.fnamemodify(name, ":~:.")
end

local function notify_reload(bufnr)
    if state.opts.notify.on_reload then
        vim.notify(('"%s" reloaded from disk.'):format(buffer_name(bufnr)), vim.log.levels.INFO, {
            title = "File Reloaded",
            timeout = 3000,
        })
    end
end

-- Open the modified buffer and its on-disk version side by side in diff mode.
local function open_diff(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    local ok, disk = pcall(vim.fn.readfile, name)
    if not ok then
        vim.notify(
            ('Could not read "%s" from disk to diff.'):format(buffer_name(bufnr)),
            vim.log.levels.ERROR,
            { title = "File Change Conflict" }
        )
        return
    end

    -- Show the modified buffer in the current window and turn on diff mode.
    vim.cmd("keepalt buffer " .. bufnr)
    vim.cmd("diffthis")

    -- Open the on-disk contents beside it in a throwaway scratch buffer.
    vim.cmd("vsplit")
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.filetype = vim.bo[bufnr].filetype
    vim.api.nvim_buf_set_lines(0, 0, -1, false, disk)
    vim.bo.modified = false
    vim.cmd("diffthis")
end

local function do_conflict_action(action, bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    if action == "reload" then
        vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("edit!")
        end)
        notify_reload(bufnr)
    elseif action == "diff" then
        open_diff(bufnr)
    end
    -- "keep" (and anything unknown): leave the buffer modified, do nothing.
end

-- Blocking modal dialog forcing the user to resolve the conflict.
local function prompt_conflict(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local actions = state.opts.conflict.actions
    local labels = {}
    local default_idx = 1
    for i, action in ipairs(actions) do
        labels[i] = action_labels[action] or action
        if action == state.opts.conflict.default then
            default_idx = i
        end
    end

    local msg = ('"%s" changed on disk, but you have unsaved changes.'):format(buffer_name(bufnr))
    local choice = vim.fn.confirm(msg, table.concat(labels, "\n"), default_idx)

    local action = (choice == 0) and state.opts.conflict.default or actions[choice]
    do_conflict_action(action, bufnr)
end

local function notify_conflict(bufnr)
    vim.notify(
        ('"%s" changed on disk but you have unsaved changes. Use :e! to reload from disk.'):format(
            buffer_name(bufnr)
        ),
        vim.log.levels.WARN,
        { title = "File Change Conflict", timeout = 0 }
    )
end

-- Decide what happens when Neovim detects a file changed on disk. We inspect
-- v:fcs_reason and only take over (v:fcs_choice = "") for the conflict case;
-- clean buffers get the normal autoread behavior.
local function on_file_changed_shell()
    local reason = vim.v.fcs_reason
    local bufnr = tonumber(vim.fn.expand("<abuf>")) or vim.api.nvim_get_current_buf()

    if reason == "deleted" then
        vim.v.fcs_choice = "" -- keep the buffer; the file is gone on disk
        vim.schedule(function()
            vim.notify(
                ('"%s" no longer exists on disk. Buffer kept; save to recreate it.'):format(buffer_name(bufnr)),
                vim.log.levels.WARN,
                { title = "File Change Conflict", timeout = 0 }
            )
        end)
        return
    end

    -- Clean buffer (reason: changed/time/mode): let autoread reload it.
    if reason ~= "conflict" then
        vim.v.fcs_choice = state.opts.autoread and "reload" or "ask"
        return
    end

    -- Conflict: disk changed AND the buffer has unsaved edits. We handle it.
    vim.v.fcs_choice = ""
    local strategy = state.opts.conflict.strategy
    if strategy == "prompt" then
        vim.schedule(function()
            prompt_conflict(bufnr)
        end)
    elseif strategy == "notify" then
        vim.schedule(function()
            notify_conflict(bufnr)
        end)
    end
    -- "none": nothing more to do, buffer is kept as-is.
end

-- Map the legacy notify.on_conflict flag onto conflict.strategy when the new
-- key was not provided, so existing configs keep working.
local function apply_legacy_compat(opts)
    local conflict_set = opts.conflict and opts.conflict.strategy ~= nil
    if not conflict_set and opts.notify and opts.notify.on_conflict ~= nil then
        local strategy = opts.notify.on_conflict and "notify" or "none"
        opts = vim.tbl_deep_extend("force", opts, { conflict = { strategy = strategy } })
    end
    return opts
end

function M.setup(opts)
    opts = apply_legacy_compat(opts or {})
    state.opts = vim.tbl_deep_extend("force", defaults, opts)

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
        callback = on_file_changed_shell,
        desc = "Resolve external file changes (reload, or prompt on conflict)",
    })

    vim.api.nvim_create_autocmd("FileChangedShellPost", {
        group = state.group,
        pattern = "*",
        callback = function()
            -- Fires after an autoread reload of a clean buffer; conflict
            -- reloads are announced by notify_reload() directly.
            notify_reload(vim.api.nvim_get_current_buf())
        end,
        desc = "Notify when a file has been automatically reloaded",
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
