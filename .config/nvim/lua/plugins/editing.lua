-- =============================================
-- РЕДАКТИРОВАНИЕ: СКОБКИ, ТЕГИ, ЛИНИИ ОТСТУПОВ
-- =============================================
--
-- nvim-autopairs закрывает парные скобки и HTML-теги, indent-blankline
-- рисует вертикальные линии по уровням вложенности.
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    { "windwp/nvim-autopairs",        event = "InsertEnter",                                                                          config = true },
    {
        "alvan/vim-closetag",
        ft = { "html", "htmldjango" },
        config = function()
            vim.g.closetag_filetypes =
            'html,htmldjango'
        end
    },

    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("ibl").setup({
                indent = { char = "▏", highlight = { "IblIndent" } },
                scope = { enabled = true, show_start = true, show_end = false, highlight = { "IblScope" } },
            })
        end,
    },
}
