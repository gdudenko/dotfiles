-- =============================================
-- ФОРМАТИРОВАНИЕ И ЛИНТИНГ
-- =============================================
--
-- conform запускает isort/black/autopep8 для Python, stylua для Lua,
-- prettier для JS/TS/CSS и djlint для шаблонов. nvim-lint проверяет
-- код после сохранения и выхода из режима вставки.
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    {
        "stevearc/conform.nvim",
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    python = { "isort", "black", "autopep8" },
                    lua = { "stylua" },
                    javascript = { "prettier" },
                    typescript = { "prettier" },
                    html = { "djlint" },
                    htmldjango = { "djlint" },
                    css = { "prettier" },
                },
                formatters = {
                    black = {
                        command = "black",
                        args = {
                            "--skip-string-normalization", "--fast",
                            "--line-length", "79",
                            "-"
                        },
                        stdin = true,
                    },
                    isort = {
                        command = "isort",
                        args = {
                            "--stdout",
                            "--profile",
                            "black",
                            "--line-length", "79",
                            "$FILENAME"
                        },
                        stdin = false,
                    },
                    autopep8 = {
                        command = "autopep8",
                        args = {
                            "--select", "E501",
                            "--max-line-length", "79",
                            "-"
                        },
                        stdin = true,
                    },
                    djlint = {
                        command = "djlint",
                        args = { "--reformat", "--indent", "2", "-" },
                        stdin = true,
                    },
                    prettier = {
                        command = "prettier",
                        args = { "--stdin-filepath", "$FILENAME" },
                        stdin = true,
                    },
                },
                format_on_save = {
                    timeout_ms = 2000,
                    lsp_fallback = true,
                },
            })
            vim.keymap.set('n', '<leader>lf', '<cmd>lua require("conform").format()<cr>', { desc = "Форматировать" })
        end,
    },

    {
        "mfussenegger/nvim-lint",
        config = function()
            require("lint").linters_by_ft = { python = { "flake8" }, lua = { "selene" }, sh = { "shellcheck" }, htmldjango = { "djlint" }, html = { "djlint" } }
            vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
                callback = function() vim.defer_fn(function() require("lint").try_lint() end, 100) end,
            })
        end,
    },
}
