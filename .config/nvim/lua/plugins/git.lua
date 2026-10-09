-- =============================================
-- GIT
-- =============================================
--
-- gitsigns показывает изменения и даёт stage/reset по блокам,
-- neogit открывает интерфейс коммитов, diffview — просмотр и историю.
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require('gitsigns').setup({
                signs = {
                    add          = { text = '│' },
                    change       = { text = '│' },
                    delete       = { text = '_' },
                    topdelete    = { text = '‾' },
                    changedelete = { text = '~' },
                    untracked    = { text = '┆' },
                },
                current_line_blame = true,
                current_line_blame_opts = {
                    virt_text = true,
                    virt_text_pos = 'eol',
                    delay = 500,
                },
                on_attach = function(bufnr)
                    local gs = package.loaded.gitsigns

                    local function map(mode, l, r, opts)
                        opts = opts or {}
                        opts.buffer = bufnr
                        vim.keymap.set(mode, l, r, opts)
                    end

                    map('n', ']c', function()
                        if vim.wo.diff then return ']c' end
                        vim.schedule(function() gs.next_hunk() end)
                        return '<Ignore>'
                    end, { expr = true, desc = "Следующее изменение (Git)" })

                    map('n', '[c', function()
                        if vim.wo.diff then return '[c' end
                        vim.schedule(function() gs.prev_hunk() end)
                        return '<Ignore>'
                    end, { expr = true, desc = "Предыдущее изменение (Git)" })

                    map('n', '<leader>hs', gs.stage_hunk, { desc = "Git: Закоммитить блок (Stage Hunk)" })
                    map('n', '<leader>hr', gs.reset_hunk, { desc = "Git: Отменить изменения в блоке (Reset Hunk)" })
                    map('v', '<leader>hs', function() gs.stage_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
                        { desc = "Git: Stage выбранный блок" })
                    map('v', '<leader>hr', function() gs.reset_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
                        { desc = "Git: Reset выбранный блок" })
                    map('n', '<leader>hS', gs.stage_buffer, { desc = "Git: Stage весь файл" })
                    map('n', '<leader>hu', gs.undo_stage_hunk, { desc = "Git: Отменить последний Stage" })
                    map('n', '<leader>hR', gs.reset_buffer, { desc = "Git: Отменить все изменения в файле" })
                    map('n', '<leader>hp', gs.preview_hunk, { desc = "Git: Превью блока изменений" })
                    map('n', '<leader>hb', function() gs.blame_line { full = true } end,
                        { desc = "Git: Полный Blame строки" })
                    map('n', '<leader>hd', gs.diffthis, { desc = "Git: Diff текущего файла" })
                end
            })
        end,
    },
}
