-- =============================================
-- УДОБСТВА: КЛАВИШИ, ОБЁРТЫВАНИЕ, TODO, ДИАГНОСТИКА, БАЗЫ
-- =============================================
--
-- which-key показывает расшифровку клавиш лидера, nvim-surround оборачивает
-- выделение в парные символы, todo-comments ищет TODO/FIXME, trouble —
-- список ошибок, vim-dadbod работает с базами данных.
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {

    -- 1. Шпаргалка по клавишам
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        init = function()
            vim.o.timeout = true
            vim.o.timeoutlen = 300
        end,
        config = function()
            -- v3: постоянной шпаргалки лидера здесь нет — она живёт в lualine.
            -- Здесь только раскрытие подсказки по нажатию: узкое окно, одна
            -- колонка, без рамки, чтобы не перекрывать код.
            -- Названия групп для which-key.
            --
            -- Без них v3 показывает «+4 keymaps» вместо смысла. Ставим через
            -- wk.add: этот способ помечает узел именно как группу, не создавая
            -- лишней команды (в отличие от keymap.set, который занял бы сам
            -- префикс и вытеснил бы <leader>f — он одновременно команда LSP-формат).
            require("which-key").add({
                { "<leader>f", group = "Поиск" },
                { "<leader>p", group = "Python" },
                { "<leader>x", group = "Ошибки" },
                { "<leader>d", group = "Django" },
                { "<leader>g", group = "Git" },
                { "<leader>h", group = "Git: hunks" },
                { "<leader>o", group = "Outline" },
                { "<leader>t", group = "Tmux" },
            })

            require("which-key").setup({
                delay = function(ctx)
                    return ctx.plugin and 0 or 150
                end,
                expand = function(node)
                    -- группы с 1-2 потомками показывать сразу, остальные — свёрнутыми
                    return node and #node:children() <= 2 or false
                end,
                layout = {
                    -- min/max в символах НА КОЛОНКУ. Было 18-30, и описания
                    -- вроде "Символы файла (функции/классы)" резались
                    -- многоточием. 24-46 держит их целиком на окне 110+.
                    width = { min = 24, max = 46 },
                    spacing = 3,
                },
                win = {
                    no_overlap = true,
                    padding = { 0, 1 },
                    title = false,
                    border = "none",
                    wo = { winblend = 0 },
                },
                keys = {
                    scroll_down = "<c-d>",
                    scroll_up = "<c-u>",
                },
                icons = {
                    -- Пустая строка убирает лишний символ "+" перед названием
                    -- группы. Раньше читалось как "+Поиск и файлы" — плюс
                    -- ничего не значил и дублировал сам факт группировки.
                    group = "",
                    breadcrumb = "»",
                    separator = " ",
                    mappings = false,
                    colors = false,
                    rules = {},
                },
                show_help = false,
                show_keys = true,
                sort = { "local", "group", "alphanum" },
                notify = true,
            })
        end,
    },

    {
        "kylechui/nvim-surround",
        version = "*",
        event = "VeryLazy",
        config = function()
            require("nvim-surround").setup({})
        end
    },

    {
        "folke/todo-comments.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("todo-comments").setup({
                signs = true,
            })
            local builtin = require("telescope.builtin")
            vim.keymap.set('n', '<leader>ft', "<cmd>TodoTelescope<CR>", { desc = "Найти TODO/FIXME" })
        end,
    },

    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("trouble").setup({
                icons = {},
            })
            vim.keymap.set("n", "<leader>xx", function() require("trouble").toggle() end,
                { desc = "Список ошибок (Trouble)" })
            vim.keymap.set("n", "<leader>xw", function() require("trouble").toggle("workspace_diagnostics") end,
                { desc = "Ошибки проекта" })
            vim.keymap.set("n", "<leader>xd", function() require("trouble").toggle("document_diagnostics") end,
                { desc = "Ошибки файла" })
        end,
    },

    {
        "NeogitOrg/neogit",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "sindrets/diffview.nvim",
            "nvim-telescope/telescope.nvim",
        },
        config = function()
            require('neogit').setup({
                integrations = {
                    diffview = true
                }
            })
            vim.keymap.set('n', '<leader>gg', require('neogit').open, { desc = "Открыть Neogit (Статус)" })
            vim.keymap.set('n', '<leader>gc', function() require('neogit').open({ "commit" }) end,
                { desc = "Git: Сделать коммит" })
        end,
    },

    {
        "sindrets/diffview.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            vim.keymap.set('n', '<leader>gd', "<cmd>DiffviewOpen<CR>", { desc = "Git: Открыть Diff (изменения)" })
            vim.keymap.set('n', '<leader>gD', "<cmd>DiffviewClose<CR>", { desc = "Git: Закрыть Diff" })
            vim.keymap.set('n', '<leader>gh', "<cmd>DiffviewFileHistory %<CR>", { desc = "Git: История текущего файла" })
            vim.keymap.set('n', '<leader>gH', "<cmd>DiffviewFileHistory<CR>", { desc = "Git: История ветки" })
        end,
    },

    { "Pocco81/auto-save.nvim",       config = function() require("auto-save").setup({ execution_message = { enabled = false } }) end },
    { "rafamadriz/friendly-snippets", config = function() require("luasnip.loaders.from_vscode").lazy_load() end },

    { "tpope/vim-dadbod",             lazy = true,                                                                                    cmd = { "DB", "DBUI" } },
    { "kristijanhusak/vim-dadbod-ui", dependencies = { "tpope/vim-dadbod", "kristijanhusak/vim-dadbod-completion" },                  lazy = true,           cmd = { "DBUI", "DBUIToggle" } },
}
