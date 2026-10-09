-- =============================================
-- СТРУКТУРА ФАЙЛА (AERIAL) — OUTLINE КАК В VSCODE
-- =============================================
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    {
        "stevearc/aerial.nvim",
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("aerial").setup({
                layout = {
                    default_direction = "right",
                    placement = "edge",
                },
                attach_mode = "global",
                backends = { "lsp", "treesitter", "markdown", "man" },
                filter_kind = {
                    "Class", "Constructor", "Enum", "Function", "Interface",
                    "Module", "Method", "Struct", "Property",
                },
                show_guides = true,
                icons = {
                    File = "󰈙",
                    Module = "󰆧",
                    Namespace = "󰌗",
                    Package = "󰏓",
                    Class = "󰌗",
                    Method = "󰆧",
                    Property = "󰜢",
                    Field = "󰜢",
                    Constructor = "",
                    Enum = "󰕘",
                    Interface = "󰜢",
                    Function = "󰊕",
                    Variable = "󰆧",
                    Constant = "󰏿",
                    String = "󰀬",
                    Number = "󰎠",
                    Boolean = "",
                    Array = "󰅪",
                    Object = "󰅩",
                    Key = "󰌋",
                    Null = "󰟢",
                    Event = "",
                    Operator = "󰆕",
                    TypeParameter = "󰊄",
                },
            })
            vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle!<CR>", { desc = "Outline (функции/классы)" })
            vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { desc = "Предыдущий символ" })
            vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { desc = "Следующий символ" })
        end,
    },
}
