-- =============================================
-- ПОИСК ПО ФАЙЛАМ И СИМВОЛАМ (TELESCOPE)
-- =============================================
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local builtin = require("telescope.builtin")
            local map = vim.keymap.set
            map('n', '<leader>ff', builtin.find_files, { desc = "Найти файлы" })
            map('n', '<leader>fg', builtin.live_grep, { desc = "Найти в файлах" })
            map('n', '<leader>fd', builtin.diagnostics, { desc = "Найти диагностики" })
            map('n', '<leader>dt',
                function() builtin.current_buffer_fuzzy_find({ prompt_title = "Поиск Django тегов", default_text = "{%" }) end,
                { desc = "Поиск Django тегов" })
            -- НОВОЕ: Поиск символов (функции/классы)
            map('n', '<leader>cs', builtin.lsp_document_symbols, { desc = "Символы файла (функции/классы)" })
            map('n', '<leader>cS', builtin.lsp_workspace_symbols, { desc = "Символы проекта (все файлы)" })
        end
    },
}
