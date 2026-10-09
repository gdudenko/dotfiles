-- =============================================
-- ХЛЕБНЫЕ КРОШКИ И СТАТУСНАЯ СТРОКА
-- =============================================
--
-- nvim-navic показывает путь к символу (хлебные крошки как в VSCode),
-- lualine — строку состояния с постоянной шпаргалкой по клавишам лидера.
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    {
        "SmiteshP/nvim-navic",
        dependencies = { "neovim/nvim-lspconfig" },
        config = function()
            require("nvim-navic").setup({
                icons = {
                    File          = "󰈙 ",
                    Module        = "󰆧 ",
                    Namespace     = "󰌗 ",
                    Package       = "󰏓 ",
                    Class         = "󰌗 ",
                    Method        = "󰆧 ",
                    Property      = "󰜢 ",
                    Field         = "󰜢 ",
                    Constructor   = " ",
                    Enum          = "󰕘 ",
                    Interface     = "󰜢 ",
                    Function      = "󰊕 ",
                    Variable      = "󰆧 ",
                    Constant      = "󰏿 ",
                    String        = "󰀬 ",
                    Number        = "󰎠 ",
                    Boolean       = " ",
                    Array         = "󰅪 ",
                    Object        = "󰅩 ",
                    Key           = "󰌋 ",
                    Null          = "󰟢 ",
                    Event         = " ",
                    Operator      = "󰆕 ",
                    TypeParameter = "󰊄 ",
                },
                highlight = true,
                separator = " > ",
                depth_limit = 0,
                lazy_update_context = false,
            })

            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if client and client.server_capabilities.documentSymbolProvider then
                        require("nvim-navic").attach(client, args.buf)
                    end
                end,
            })
        end,
    },

    {
        "nvim-lualine/lualine.nvim",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
            "catppuccin/nvim",
            "SmiteshP/nvim-navic",
        },
        config = function()
            -- Постоянная шпаргалка по самым частым командам лидера.
            -- Живёт в lualine_x, поэтому не занимает отдельную строку экрана.
            -- На узких окнах (<110 колонок) прячется, иначе lualine вытеснит
            -- имя файла, а неверные подсказки скрываются с края по одной.
            local hints = function()
                return " ff файл  fg поиск  g git  nt дерево  dr запуск  np venv  xx ошибки  "
            end
            local hints_visible = function()
                return vim.o.columns >= 110
            end
            require("lualine").setup({
                options = {
                    theme = "auto",
                    component_separators = { left = '│', right = '│' },
                    section_separators = { left = '', right = '' },
                },
                sections = {
                    lualine_a = { 'mode' },
                    lualine_b = { 'branch', 'diff' },
                    lualine_c = {
                        { 'diagnostics', sources = { 'nvim_diagnostic' }, symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' } },
                        { 'filetype',    icon_only = true,                separator = '',                                               padding = { left = 1, right = 0 } },
                        { 'filename',    path = 1 },
                        {
                            function() return require("nvim-navic").get_location() end,
                            cond = function()
                                return package.loaded["nvim-navic"] and
                                    require("nvim-navic").is_available()
                            end,
                            color = { fg = "#cba6f7", gui = "bold" },
                        },
                        { function() return vim.bo.filetype == 'htmldjango' and '󰌠 Django' or '' end, color = { fg = '#f38ba8', gui = 'bold' } }
                    },
                    lualine_x = {
                        { hints, color = { fg = "#7f849c", gui = "italic" }, separator = "", padding = { left = 0, right = 0 }, cond = hints_visible },
                        'encoding', 'fileformat'
                    },
                    lualine_y = { 'progress' },
                    lualine_z = { 'location' }
                },
                inactive_sections = {
                    lualine_c = { 'filename' },
                    lualine_x = { 'location' },
                },
            })
        end,
    },
}
