-- =============================================
-- ОТЛАДКА И ТЕСТЫ
-- =============================================
--
-- nvim-dap с интерфейсом dapui и адаптером для Python, pytest.nvim как
-- раннер тестов, vim-slime для отправки кода в REPL в tmux.
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "mfussenegger/nvim-dap-python",
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio",
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")
            dapui.setup()

            require("dap-python").setup("python")
            require("dap-python").test_runner = "pytest"

            local map = vim.keymap.set
            map('n', '<F5>', dap.continue, { desc = "Продолжить отладку" })
            map('n', '<F9>', dap.toggle_breakpoint, { desc = "Точка останова" })
            map('n', '<F10>', dap.step_over, { desc = "Шаг через" })
            map('n', '<F11>', dap.step_into, { desc = "Шаг внутрь" })
            map('n', '<F12>', dap.step_out, { desc = "Шаг наружу" })
            map('n', '<leader>du', dapui.toggle, { desc = "Показать/скрыть UI отладки" })

            -- Клавиша dx, а не dt: dt принадлежит telescope (поиск Django
            -- тегов), и DAP молча перезаписывал его — поиск был недостижим.
            map('n', '<leader>dx', function() require("dap-python").test_method() end,
                { desc = "Отладить тест под курсором" })
            map('n', '<leader>dC', function() require("dap-python").test_class() end,
                { desc = "Отладить класс под курсором" })

            dap.listeners.before.attach.dapui_config = function() dapui.open() end
            dap.listeners.before.launch.dapui_config = function() dapui.open() end
            dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
            dap.listeners.before.event_exited.dapui_config = function() dapui.close() end
        end,
    },

    {
        "richardhapb/pytest.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        ft = { "python" },
        config = function()
            require("pytest").setup({
                django = { enabled = true },
            })
        end,
    },

    {
        "jpalardy/vim-slime",
        config = function()
            vim.g.slime_target = "tmux"
            vim.g.slime_default_config = { socket_name = "default", target_pane = "{right}" }
            vim.g.slime_dont_ask_default = 1
            vim.keymap.set({ "n", "v" }, "<leader>ss", "<Plug>SlimeLineSend",
                { desc = "Отправить строку/выделение в REPL" })
        end,
    },
}
