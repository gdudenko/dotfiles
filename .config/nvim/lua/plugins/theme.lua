-- =============================================
-- ЦВЕТОВАЯ СХЕМА И ПОДСВЕТКА ШАБЛОНОВ
-- =============================================
--
-- catppuccin (mocha) задаёт цвета и включает интеграции с плагинами,
-- которые подсвечивают свой вывод (treesitter, telescope, lualine, dap).
-- django-plus подсвечивает теги и переменные внутри htmldjango.
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        config = function()
            require("catppuccin").setup({
                flavour = "mocha",
                transparent_background = false,
                term_colors = true,

                integrations = {
                    treesitter = true,
                    nvimtree = true,
                    mason = true,
                    telescope = true,
                    dashboard = true,
                    which_key = true,
                    dap = { enabled = true, enable_ui = true },
                    native_lsp = {
                        enabled = true,
                        virtual_text = { errors = { "italic" }, hints = { "italic" }, warnings = { "italic" }, information = { "italic" } },
                        underlines = { errors = { "underline" }, hints = { "underline" }, warnings = { "underline" }, information = { "underline" } },
                    },
                },
                custom_highlights = function(colors)
                    return {
                        djangoTag = { fg = colors.red, bold = true },
                        djangoFilter = { fg = colors.blue, italic = true },
                        djangoVariable = { fg = colors.yellow },
                        djangoComment = { fg = colors.surface2, italic = true },
                        djangoStatement = { fg = colors.mauve, bold = true },
                    }
                end,
            })
            vim.cmd.colorscheme("catppuccin")
        end,
    },

    {
        "tweekmonster/django-plus.vim",
        ft = { "htmldjango", "html", "python" },
        config = function()
            vim.g.django_highlight_all = 1
            vim.g.django_filetype = 1
            vim.g.django_highlight_html = 1
        end,
    },
}
