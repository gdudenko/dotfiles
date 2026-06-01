-- =============================================
-- NEOVIM + TMUX ИНТЕГРАЦИЯ С ПРОФИЛИРОВАНИЕМ PYTHON И ПОДДЕРЖКОЙ DJANGO
-- =============================================

-- 1. БАЗОВЫЕ НАСТРОЙКИ
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.mouse = 'a'
vim.opt.updatetime = 300
vim.opt.timeoutlen = 500
vim.opt.syntax = 'on'

-- Автоматическое определение типа файла Django
vim.g.django_filetype = 1
vim.g.django_highlight_all = 1
vim.g.django_html_in_strings = 1

-- 2. НАСТРОЙКА ДИАГНОСТИКИ
vim.diagnostic.config({
    virtual_text = {
        prefix = "●",
        spacing = 4,
    },
    float = {
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
        focusable = false,
    },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "✗",
            [vim.diagnostic.severity.WARN] = "⚠",
            [vim.diagnostic.severity.INFO] = "ℹ",
            [vim.diagnostic.severity.HINT] = "→",
        },
    },
})

local function show_diagnostic_float()
    local opts = {
        focusable = true,
        close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
        border = 'rounded',
        source = 'always',
        prefix = '',
    }
    vim.diagnostic.open_float(nil, opts)
end

vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
        if vim.fn.mode() == 'n' then
            show_diagnostic_float()
        end
    end
})

-- 3. МАППИНГИ (РУССКАЯ РАСКЛАДКА)
local map = vim.keymap.set

-- Навигация с русской раскладкой
map({ 'n', 'v' }, 'h', 'h', { noremap = true })
map({ 'n', 'v' }, 'р', 'h', { noremap = true })
map({ 'n', 'v' }, 'j', 'j', { noremap = true })
map({ 'n', 'v' }, 'о', 'j', { noremap = true })
map({ 'n', 'v' }, 'k', 'k', { noremap = true })
map({ 'n', 'v' }, 'л', 'k', { noremap = true })
map({ 'n', 'v' }, 'l', 'l', { noremap = true })
map({ 'n', 'v' }, 'д', 'l', { noremap = true })
map({ 'n', 'v' }, 'ш', 'i', { noremap = true })
map({ 'n', 'v' }, 'ф', 'a', { noremap = true })

-- Системные команды
map('n', '<leader>w', '<cmd>w<CR>', { desc = "Сохранить" })
map('n', '<leader>qq', '<cmd>q<CR>', { desc = "Закрыть" })
map('n', '<leader>r', '<cmd>source $MYVIMRC<CR>', { desc = "Перезагрузить конфиг" })

-- 4. МАППИНГИ ДЛЯ УПРАВЛЕНИЯ ДИАГНОСТИКОЙ
map('n', '<leader>e', '<cmd>lua vim.diagnostic.open_float()<CR>', { desc = "Показать диагностику" })
map('n', '<leader>ql', '<cmd>lua vim.diagnostic.setloclist()<CR>', { desc = "Показать ошибки в loclist" })
map('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', { desc = "Предыдущая диагностика" })
map('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', { desc = "Следующая диагностика" })
map('n', '<leader>dd', '<cmd>lua vim.diagnostic.hide()<CR>', { desc = "Скрыть диагностику" })
map('n', '<leader>da', '<cmd>lua vim.diagnostic.show()<CR>', { desc = "Показать диагностику" })

-- 5. TMUX ИНТЕГРАЦИЯ (ГЛОБАЛЬНАЯ ТАБЛИЦА)
_G.Tmux = {}

Tmux.send_command = function(command, pane_target)
    local pane = pane_target or "2" -- По умолчанию терминальная панель (2)
    local cmd = string.format('tmux send-keys -t %s "%s" Enter', pane, command)
    os.execute(cmd)
    vim.notify("📡 Команда отправлена в tmux: " .. command, vim.log.levels.INFO)
end

Tmux.run_current_file = function()
    local current_file = vim.fn.expand('%:p')
    if current_file == '' then
        vim.notify("❌ Нет открытого файла", vim.log.levels.ERROR)
        return
    end

    local file_extension = vim.fn.expand('%:e')
    local command

    if file_extension == 'py' then
        command = string.format('python "%s"', current_file)
    elseif file_extension == 'lua' then
        command = string.format('lua "%s"', current_file)
    elseif file_extension == 'sh' or file_extension == 'bash' then
        command = string.format('bash "%s"', current_file)
    elseif file_extension == 'js' then
        command = string.format('node "%s"', current_file)
    elseif file_extension == 'ts' then
        command = string.format('npx ts-node "%s"', current_file)
    elseif file_extension == 'html' or file_extension == 'htm' then
        local buftype = vim.bo.filetype
        if buftype == 'htmldjango' then
            vim.notify("🔄 Это Django шаблон, запуск сервера Django", vim.log.levels.INFO)
            Tmux.send_command('python manage.py runserver')
            return
        else
            vim.notify("🌐 Это HTML файл, откройте в браузере", vim.log.levels.INFO)
            return
        end
    else
        vim.notify("❌ Неподдерживаемый тип файла: ." .. file_extension, vim.log.levels.WARN)
        return
    end

    Tmux.send_command('clear')
    Tmux.send_command(command)
    vim.notify("🚀 Запускаю: " .. vim.fn.fnamemodify(current_file, ':t'), vim.log.levels.INFO)
end

-- Заглушка для activate_venv, чтобы скрипт create_panes.sh не вызывал ошибку
Tmux.activate_venv = function(path)
    vim.notify("🔄 Активация venv для " .. path .. " (вызывается из скрипта)", vim.log.levels.INFO)
    -- В реальности здесь можно было бы отправить команду активации в терминальную панель,
    -- но это сложно без знания точной панели. Оставлено как информационное сообщение.
end

-- 6. LAZY.NVIM УСТАНОВКА
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- 7. ПЛАГИНЫ
require("lazy").setup({
    -- ЦВЕТОВАЯ СХЕМА
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
                    dap = {
                        enabled = true,
                        enable_ui = true,
                    },
                    native_lsp = {
                        enabled = true,
                        virtual_text = {
                            errors = { "italic" },
                            hints = { "italic" },
                            warnings = { "italic" },
                            information = { "italic" },
                        },
                        underlines = {
                            errors = { "underline" },
                            hints = { "underline" },
                            warnings = { "underline" },
                            information = { "underline" },
                        },
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

    -- DJANGO ПОДСВЕТКА
    {
        "tweekmonster/django-plus.vim",
        ft = { "htmldjango", "html", "python" },
        config = function()
            vim.g.django_highlight_all = 1
            vim.g.django_filetype = 1
            vim.g.django_highlight_html = 1
            vim.cmd([[
                hi link djangoTag Statement
                hi link djangoFilter Type
                hi link djangoVariable Identifier
                hi link djangoComment Comment
                hi link djangoStatement PreProc
                hi djangoTagBlock guifg=#f38ba8 gui=bold
                hi djangoTagIf guifg=#cba6f7 gui=bold
                hi djangoTagFor guifg=#cba6f7 gui=bold
                hi djangoTagComment guifg=#6c7086 gui=italic
                hi djangoTagUrl guifg=#89b4fa
                hi djangoTagTrans guifg=#a6e3a1
                hi djangoTagLoad guifg=#fab387
                hi djangoTagExtends guifg=#f9e2af
                hi djangoTagInclude guifg=#74c7ec
            ]])
        end,
    },

    -- NVIMTREE (С ФИЛЬТРАМИ ДЛЯ SQLITE)
    {
        "nvim-tree/nvim-tree.lua",
        lazy = false,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            vim.g.loaded_netrw = 1
            vim.g.loaded_netrwPlugin = 1

            local api = require("nvim-tree.api")

            local function send_cd_to_tmux(path)
                if not path then return end
                local safe_path = path:gsub('"', '\\"'):gsub("'", "\\'")
                local tmux_cmd = string.format('tmux send-keys -t 2 "cd \'%s\' && pwd" Enter', safe_path)
                os.execute(tmux_cmd)
                vim.notify("📁 Tmux: перешел в " .. path, vim.log.levels.INFO)
            end

            require("nvim-tree").setup({
                view = {
                    width = 35,
                    number = false,
                    relativenumber = false,
                },
                renderer = {
                    icons = {
                        show = {
                            file = true,
                            folder = true,
                            folder_arrow = true,
                            git = true,
                        },
                        glyphs = {
                            default = "",
                            symlink = "",
                            folder = {
                                arrow_closed = "",
                                arrow_open = "",
                                default = "",
                                open = "",
                                empty = "",
                                empty_open = "",
                                symlink = "",
                                symlink_open = "",
                            },
                        },
                    },
                    indent_markers = {
                        enable = true,
                        inline_arrows = true,
                        icons = {
                            corner = "└",
                            edge = "│",
                            item = "│",
                            none = " ",
                        },
                    },
                },
                filters = {
                    dotfiles = false,
                    custom = { "^\\.git$" }, -- показываем все, кроме .git
                },
                git = {
                    enable = true,
                    ignore = false, -- НЕ игнорировать файлы из .gitignore
                },
                sync_root_with_cwd = false,
                update_focused_file = {
                    enable = true,
                    update_cwd = true,
                },
                actions = {
                    open_file = {
                        quit_on_open = false,
                        window_picker = {
                            enable = false,
                        },
                    },
                    change_dir = {
                        enable = true,
                        global = true,
                    },
                },
                on_attach = function(bufnr)
                    local function opts(desc)
                        return {
                            desc = "nvim-tree: " .. desc,
                            buffer = bufnr,
                            noremap = true,
                            silent = true,
                            nowait = true
                        }
                    end

                    vim.keymap.set("n", "<CR>", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "o", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "<2-LeftMouse>", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "<C-e>", api.node.navigate.parent_close, opts("Close Directory"))

                    vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
                    vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "<C-k>", api.node.navigate.sibling.next, opts("Next Sibling"))
                    vim.keymap.set("n", "<C-j>", api.node.navigate.sibling.prev, opts("Previous Sibling"))

                    vim.keymap.set("n", "a", api.fs.create, opts("Create"))
                    vim.keymap.set("n", "d", api.fs.remove, opts("Delete"))
                    vim.keymap.set("n", "r", api.fs.rename, opts("Rename"))
                    vim.keymap.set("n", "x", api.fs.cut, opts("Cut"))
                    vim.keymap.set("n", "c", api.fs.copy.node, opts("Copy"))
                    vim.keymap.set("n", "p", api.fs.paste, opts("Paste"))
                    vim.keymap.set("n", "y", api.fs.copy.filename, opts("Copy Name"))
                    vim.keymap.set("n", "Y", api.fs.copy.relative_path, opts("Copy Relative Path"))
                    vim.keymap.set("n", "gy", api.fs.copy.absolute_path, opts("Copy Absolute Path"))

                    vim.keymap.set("n", "R", api.tree.reload, opts("Refresh"))
                    vim.keymap.set("n", "H", api.tree.toggle_hidden_filter, opts("Toggle Dotfiles"))
                    vim.keymap.set("n", "I", api.tree.toggle_gitignore_filter, opts("Toggle Git Ignore"))

                    vim.keymap.set("n", "s", api.node.run.system, opts("Run System"))
                    vim.keymap.set("n", "f", api.live_filter.start, opts("Filter"))
                    vim.keymap.set("n", "F", api.live_filter.clear, opts("Clean Filter"))
                    vim.keymap.set("n", "q", api.tree.close, opts("Close"))
                    vim.keymap.set("n", "W", api.tree.collapse_all, opts("Collapse All"))
                    vim.keymap.set("n", "E", api.tree.expand_all, opts("Expand All"))

                    vim.keymap.set("n", "C", function()
                        local node = api.tree.get_node_under_cursor()
                        if node and node.type == "directory" then
                            api.tree.change_root_to_node(node)
                            send_cd_to_tmux(node.absolute_path)
                            vim.notify("📁 Корень установлен: " .. node.name, vim.log.levels.INFO)
                        end
                    end, opts("Change Root & Sync with Tmux"))

                    vim.keymap.set("n", "u", function()
                        api.tree.change_root_to_parent()
                        local new_root = api.tree.get_nodes().absolute_path
                        send_cd_to_tmux(new_root)
                    end, opts("Up Directory"))

                    vim.keymap.set("n", "<C-t>", api.node.open.tab, opts("Open: New Tab"))
                    vim.keymap.set("n", "<C-v>", api.node.open.vertical, opts("Open: Vertical Split"))
                    vim.keymap.set("n", "<C-x>", api.node.open.horizontal, opts("Open: Horizontal Split"))
                end,
            })

            map('n', '<leader>nt', api.tree.toggle, { desc = "Файловый менеджер" })
            map('n', '<leader>nf', api.tree.focus, { desc = "Фокус на файловый менеджер" })
            map('n', '<leader>nr', api.tree.reload, { desc = "Обновить файловый менеджер" })

            vim.api.nvim_create_autocmd("User", {
                pattern = "NvimTreeRootChanged",
                callback = function(data)
                    local new_root = data.data.new_root
                    if new_root and new_root.absolute_path then
                        vim.defer_fn(function()
                            send_cd_to_tmux(new_root.absolute_path)
                        end, 100)
                    end
                end,
            })

            vim.api.nvim_create_autocmd({ "VimEnter" }, {
                callback = function(data)
                    local directory = vim.fn.isdirectory(data.file) == 1
                    if directory then
                        vim.cmd.cd(data.file)
                        api.tree.open()
                    end
                end,
            })

            vim.api.nvim_create_autocmd("QuitPre", {
                callback = function()
                    local tree_wins = {}
                    local tree_tabpages = {}

                    for _, win in ipairs(vim.api.nvim_list_wins()) do
                        local buf = vim.api.nvim_win_get_buf(win)
                        local buf_name = vim.api.nvim_buf_get_name(buf)
                        if buf_name:match("NvimTree") then
                            table.insert(tree_wins, win)
                            table.insert(tree_tabpages, vim.api.nvim_win_get_tabpage(win))
                        end
                    end

                    if #tree_wins == 1 then
                        local tree_win = tree_wins[1]
                        local tree_tab = tree_tabpages[1]
                        local tab_wins = vim.api.nvim_tabpage_list_wins(tree_tab)

                        if #tab_wins == 1 then
                            vim.api.nvim_win_close(tree_win, true)
                        end
                    end
                end,
            })
        end,
    },

    -- СТАТУСНАЯ СТРОКА
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("lualine").setup({
                options = {
                    theme = "catppuccin",
                },
                sections = {
                    lualine_c = {
                        {
                            'diagnostics',
                            sources = { 'nvim_diagnostic' },
                            symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' },
                        },
                        {
                            'filetype',
                            icon_only = true,
                            separator = '',
                            padding = { left = 1, right = 0 },
                        },
                        {
                            function()
                                local ft = vim.bo.filetype
                                if ft == 'htmldjango' then
                                    return '󰌠 Django'
                                end
                                return ''
                            end,
                            color = { fg = '#f38ba8', gui = 'bold' },
                        }
                    }
                }
            })
        end,
    },

    -- АВТОДОПОЛНЕНИЕ СКОБОК
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup({
                disable_filetype = { "TelescopePrompt", "vim" },
            })
        end,
    },

    -- ЛИНИИ ОТСТУПОВ
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            -- Настраиваем символы под вашу тему Catppuccin Mocha
            local catppuccin_colors = {
                mauve = "#cba6f7",
                overlay1 = "#6c7086",
                surface1 = "#45475a",
            }

            require("ibl").setup({
                indent = {
                    char = "▏", -- тонкая вертикальная линия (менее навязчивая чем "│")
                    tab_char = "▏",
                    highlight = { "IblIndent" },
                    smart_indent_cap = true,
                    repeat_linebreak = true,
                },
                scope = {
                    enabled = true,
                    show_start = true,
                    show_end = false,
                    highlight = { "IblScope" },
                    priority = 1000,
                    include = {
                        node_type = {
                            python = { "block", "function_definition", "if_statement", "for_statement", "while_statement", "try_statement", "with_statement" },
                        },
                    },
                },
                whitespace = {
                    highlight = { "IblWhitespace" },
                    remove_blankline_trail = true,
                },
                exclude = {
                    filetypes = {
                        "help", "alpha", "dashboard", "NvimTree", "Trouble",
                        "lazy", "mason", "notify", "toggleterm", "lazyterm",
                        "gitcommit", "gitrebase", "spectre_panel",
                    },
                },
            })

            -- Кастомные хайлайты под Catppuccin Mocha
            vim.api.nvim_set_hl(0, "IblIndent", { fg = catppuccin_colors.surface1, nocombine = true })
            vim.api.nvim_set_hl(0, "IblScope", { fg = catppuccin_colors.mauve, bold = true, nocombine = true })
            vim.api.nvim_set_hl(0, "IblWhitespace", { fg = catppuccin_colors.overlay1, nocombine = true })

            -- Маппинг для переключения видимости линий
            vim.keymap.set("n", "<leader>ti", function()
                local config = require("ibl.config").get_config(0)
                local enabled = config.indent.enabled
                require("ibl").setup_buffer(0, { indent = { enabled = not enabled } })
                vim.notify(
                    (not enabled and "✅" or "❌") .. " Линии отступов " .. (not enabled and "включены" or "выключены"),
                    vim.log.levels.INFO)
            end, { desc = "Переключить линии отступов" })
        end,
    },

    -- TREESITTER (БЕЗ DJANGO ПАРСЕРА)
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "python", "lua", "bash", "javascript",
                    "typescript", "html", "css"
                },
                highlight = {
                    enable = true,
                    additional_vim_regex_highlighting = false,
                },
                indent = { enable = true },
            })
        end,
    },

    -- TELESCOPE
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local builtin = require("telescope.builtin")
            map('n', '<leader>ff', builtin.find_files, { desc = "Найти файлы" })
            map('n', '<leader>fg', builtin.live_grep, { desc = "Найти в файлах" })
            map('n', '<leader>fd', builtin.diagnostics, { desc = "Найти диагностики" })
            map('n', '<leader>dt', function()
                builtin.current_buffer_fuzzy_find({
                    prompt_title = "Поиск Django тегов",
                    default_text = "{%",
                })
            end, { desc = "Поиск Django тегов" })
        end
    },

    -- LSP
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/nvim-cmp",
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "L3MON4D3/LuaSnip",
        },
        config = function()
            require("mason").setup()
            require("mason-lspconfig").setup({
                ensure_installed = { "pyright", "lua_ls", "bashls", "ts_ls", "html" }
            })

            local cmp = require("cmp")
            local cmp = require("cmp")
            cmp.setup({
                snippet = {
                    expand = function(args)
                        require('luasnip').lsp_expand(args.body)
                    end,
                },
                experimental = {
                    ghost_text = true, -- ← серая подсказка
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<CR>'] = cmp.mapping.confirm({ select = true }),
                    ['<Tab>'] = cmp.mapping.select_next_item(),
                    ['<S-Tab>'] = cmp.mapping.select_prev_item(),

                    -- === ВОТ НОВЫЕ КЛАВИШИ (как в Supermaven) ===
                    ['<C-g>'] = cmp.mapping.confirm({ select = true }),
                    ['<C-j>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            -- Вставляем только первое слово из выделенного пункта
                            local entry = cmp.get_selected_entry()
                            if entry then
                                local word = entry.completion_item.label:match("^(%S+)")
                                if word then
                                    vim.api.nvim_put({ word }, 'c', false, true)
                                    cmp.abort()
                                else
                                    cmp.confirm({ select = true })
                                end
                            else
                                cmp.confirm({ select = true })
                            end
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ['<C-]>'] = cmp.mapping.abort(),
                    -- ============================================
                }),
                sources = cmp.config.sources({
                    { name = 'nvim_lsp' },
                    { name = 'buffer' },
                    { name = 'path' },
                }),
            })

            local capabilities = require('cmp_nvim_lsp').default_capabilities()

            local on_attach = function(client, bufnr)
                vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
                local bufopts = { noremap = true, silent = true, buffer = bufnr }
                map('n', 'gd', vim.lsp.buf.definition, bufopts)
                map('n', 'K', vim.lsp.buf.hover, bufopts)
                map('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
                map('n', '<leader>ca', vim.lsp.buf.code_action, bufopts)
                map('n', '<leader>f', function() vim.lsp.buf.format { async = true } end, bufopts)
            end

            -- Функция для поиска виртуального окружения в текущей директории
            local function find_venv()
                local cwd = vim.fn.getcwd()
                local venv_names = { "venv", ".venv", "env" }
                for _, name in ipairs(venv_names) do
                    local venv_path = cwd .. "/" .. name
                    if vim.fn.isdirectory(venv_path) == 1 then
                        return name, cwd
                    end
                end
                return nil, cwd
            end

            -- Настройки LSP для pyright
            vim.lsp.config['pyright'] = {
                cmd = { 'pyright-langserver', '--stdio' },
                filetypes = { 'python' },
                root_markers = { 'pyproject.toml', 'setup.py', 'requirements.txt', 'manage.py', '.git' },
                settings = {
                    python = {
                        analysis = {
                            typeCheckingMode = "basic",
                            useLibraryCodeForTypes = true,
                            autoSearchPaths = true,
                            diagnosticMode = "workspace",
                            stubPath = vim.fn.expand("~/.local/lib/pyright-stubs/stubs"),
                            reportMissingTypeStubs = "warning",
                            reportUnknownMemberType = "none",
                            diagnosticSeverityOverrides = {
                                reportMissingModuleSource = 'none',
                            }
                        }
                    }
                },
                on_new_config = function(new_config, new_root_dir)
                    -- Функция поиска venv (оставлена без изменений)
                    local function find_venv()
                        local cwd = new_root_dir or vim.fn.getcwd()
                        local venv_names = { "venv", ".venv", "env" }
                        for _, name in ipairs(venv_names) do
                            local venv_path = vim.fs.joinpath(cwd, name)
                            if vim.fn.isdirectory(venv_path) == 1 then
                                return name, cwd
                            end
                        end
                        return nil, cwd
                    end

                    local venv_name, venv_path = find_venv()
                    if venv_name then
                        new_config.settings = vim.tbl_deep_extend("force", new_config.settings or {}, {
                            python = {
                                analysis = {
                                    venv = venv_name,
                                    venvPath = venv_path,
                                }
                            }
                        })
                    end
                end,
                capabilities = capabilities,
                on_attach = on_attach,
            }

            vim.lsp.config['lua_ls'] = {
                cmd = { 'lua-language-server' },
                filetypes = { 'lua' },
                root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
                settings = {
                    Lua = {
                        runtime = { version = 'LuaJIT' },
                        diagnostics = { globals = { 'vim' } },
                        workspace = { library = vim.api.nvim_get_runtime_file("", true) },
                        telemetry = { enable = false },
                    },
                },
                capabilities = capabilities,
                on_attach = on_attach,
            }

            vim.lsp.config['bashls'] = {
                cmd = { 'bash-language-server', 'start' },
                filetypes = { 'sh', 'bash' },
                capabilities = capabilities,
                on_attach = on_attach,
            }

            vim.lsp.config['ts_ls'] = {
                cmd = { 'typescript-language-server', '--stdio' },
                filetypes = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
                root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
                capabilities = capabilities,
                on_attach = on_attach,
            }

            vim.lsp.config['html'] = {
                cmd = { 'vscode-html-language-server', '--stdio' },
                filetypes = { 'html', 'htmldjango' },
                init_options = {
                    configurationSection = { 'html', 'css', 'javascript' },
                    embeddedLanguages = {
                        css = true,
                        javascript = true
                    },
                    provideFormatter = true
                },
                capabilities = capabilities,
                on_attach = on_attach,
            }

            vim.lsp.enable('pyright')
            vim.lsp.enable('lua_ls')
            vim.lsp.enable('bashls')
            vim.lsp.enable('ts_ls')
            vim.lsp.enable('html')
        end,
    },

    -- ФОРМАТИРОВАНИЕ (CONFORM) С ISORT И BLACK
    {
        "stevearc/conform.nvim",
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    python = { "isort", "black" },
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
                    timeout_ms = 1000,
                    lsp_fallback = true,
                },
            })

            map('n', '<leader>lf', '<cmd>lua require("conform").format()<cr>', { desc = "Форматировать" })
        end,
    },

    -- ЛОКАЛЬНЫЙ AI-АВТОДОПОЛНЕНИЕ (LLM.NVIM + OLLAMA)
    {
        "supermaven-inc/supermaven-nvim",
        config = function()
            require("supermaven-nvim").setup({
                keymaps = {
                    accept_suggestion = "<C-g>",
                    clear_suggestion = "<C-]>",
                    accept_word = "<C-j>",
                },
            })
        end,
    },

    -- ЛИНТИНГ
    {
        "mfussenegger/nvim-lint",
        config = function()
            require("lint").linters_by_ft = {
                python = { "flake8" },
                lua = { "selene" },
                sh = { "shellcheck" },
                htmldjango = { "djlint" },
                html = { "djlint" },
            }

            require("lint").linters.flake8 = {
                cmd = "flake8",
                stdin = true,
                args = {
                    "--format=%(path)s:%(row)d:%(col)d:%(code)s:%(text)s", -- ← ключевое исправление
                    "--no-show-source",
                    "--stdin-display-name",
                    function() return vim.api.nvim_buf_get_name(0) end, -- динамическое имя файла
                    "--max-line-length=79",
                    "-",                                                -- чтение из stdin
                },
                ignore_exitcode = true,
                parser = require("lint.parser").from_pattern(
                    "[^:]+:(%d+):(%d+):(%w+):(.+)",       -- pattern для парсинга
                    { "lnum", "col", "code", "message" }, -- группы захвата
                    nil,
                    {
                        source = "flake8",
                        severity = vim.diagnostic.severity.WARN,
                    }
                ),
            }

            require("lint").linters.djlint = {
                cmd = "djlint",
                stdin = true,
                args = { "--check", "-" },
                stream = "stderr",
                ignore_exitcode = true,
                parser = require("lint.parser").from_errorformat(
                    "Line %l:%c %m",
                    { source = "djlint" }
                ),
            }

            vim.api.nvim_create_autocmd({ "BufWritePost" }, {
                callback = function()
                    vim.defer_fn(function()
                        require("lint").try_lint()
                    end, 100)
                end,
            })

            vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost", "InsertLeave" }, {
                callback = function()
                    vim.defer_fn(function()
                        require("lint").try_lint()
                    end, 100)
                end,
            })
        end,
    },

    -- DAP (ОТЛАДКА)
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
            local dap_python = require("dap-python")
            dap_python.test_runner = "pytest"
            local function setup_pytest_debug()
                local dap = require("dap")
                local dap_python = require("dap-python")
                dap.configurations.python = dap.configurations.python or {}
                table.insert(dap.configurations.python, {
                    type = "python",
                    request = "launch",
                    name = "Pytest: текущий файл",
                    program = "${workspaceFolder}/venv/bin/pytest", -- путь к pytest в виртуальном окружении
                    args = { "${file}", "-v", "-s" },               -- аргументы pytest
                    console = "integratedTerminal",
                    justMyCode = false,                             -- заходить в сторонний код
                })

                -- Более умный вариант: определяет, тест ли под курсором
                dap_python.test_runner = "pytest" -- указываем, что используем pytest

                -- Создаём маппинг для отладки теста под курсором (функция, тест-метод)
                vim.keymap.set('n', '<leader>dt', function()
                    dap_python.test_method()
                end, { desc = "Отладить тест под курсором (pytest)" })

                vim.keymap.set('n', '<leader>dc', function()
                    dap_python.test_class()
                end, { desc = "Отладить тест-класс под курсором" })
            end

            dap.configurations.python = {
                {
                    type = "python",
                    request = "launch",
                    name = "Запустить Python файл",
                    program = "${file}",
                    pythonPath = function()
                        return vim.fn.exepath("python3") or vim.fn.exepath("python")
                    end,
                },
                {
                    type = "python",
                    request = "attach",
                    name = "Присоединиться к процессу",
                    processId = require("dap.utils").pick_process,
                    pythonPath = function()
                        return vim.fn.exepath("python3") or vim.fn.exepath("python")
                    end,
                }
            }

            table.insert(dap.configurations.python, {
                type = "python",
                request = "launch",
                name = "Профилировать Python файл",
                program = "${file}",
                pythonPath = function()
                    return vim.fn.exepath("python3") or vim.fn.exepath("python")
                end,
                args = { "--profile", "profile.stats" },
                console = "integratedTerminal",
            })

            map('n', '<F5>', function()
                if vim.bo.filetype == 'python' then
                    dap.continue()
                end
            end, { desc = "Продолжить отладку" })

            map('n', '<F9>', function()
                if vim.bo.filetype == 'python' then
                    dap.toggle_breakpoint()
                end
            end, { desc = "Установить/убрать точку останова" })

            map('n', '<F10>', function()
                if vim.bo.filetype == 'python' then
                    dap.step_over()
                end
            end, { desc = "Шаг через" })

            map('n', '<F11>', function()
                if vim.bo.filetype == 'python' then
                    dap.step_into()
                end
            end, { desc = "Шаг внутрь" })

            map('n', '<F12>', function()
                if vim.bo.filetype == 'python' then
                    dap.step_out()
                end
            end, { desc = "Шаг наружу" })

            map('n', '<leader>pp', function()
                if vim.bo.filetype ~= 'python' then
                    vim.notify("Это не Python файл", vim.log.levels.WARN)
                    return
                end

                local current_file = vim.fn.expand('%:p')
                if current_file == '' then
                    vim.notify("Нет открытого файла", vim.log.levels.ERROR)
                    return
                end

                local profile_cmd = string.format('python -m cProfile -o profile.stats "%s"', current_file)
                Tmux.send_command('clear')
                Tmux.send_command(profile_cmd)
                vim.notify("📊 Запущено профилирование файла...", vim.log.levels.INFO)

                vim.defer_fn(function()
                    Tmux.send_command(
                        'python -c "import pstats; p = pstats.Stats(\"profile.stats\"); p.strip_dirs().sort_stats(\"cumulative\").print_stats(20)"')
                    vim.notify("📈 Результаты профилирования готовы в терминале", vim.log.levels.INFO)
                end, 500)
            end, { desc = "Профилировать Python файл" })

            map('n', '<leader>pa', function()
                if vim.bo.filetype ~= 'python' then
                    vim.notify("Это не Python файл", vim.log.levels.WARN)
                    return
                end

                vim.cmd('vnew')
                vim.api.nvim_buf_set_name(0, 'Профилирование Python')
                vim.api.nvim_buf_set_option(0, 'filetype', 'python')

                local lines = {
                    "# Анализ результатов профилирования",
                    "# Используйте следующие команды:",
                    "",
                    "import pstats",
                    "from pstats import SortKey",
                    "",
                    "# Загрузить результаты профилирования",
                    "p = pstats.Stats('profile.stats')",
                    "",
                    "# Варианты сортировки:",
                    "# - SortKey.CUMULATIVE  - кумулятивное время",
                    "# - SortKey.TIME       - внутреннее время",
                    "# - SortKey.CALLS      - количество вызовов",
                    "",
                    "# Вывести топ-20 функций по кумулятивному времени",
                    "p.strip_dirs().sort_stats(SortKey.CUMULATIVE).print_stats(20)",
                    "",
                    "# Вывести топ-10 функций по внутреннему времени",
                    "# p.strip_dirs().sort_stats(SortKey.TIME).print_stats(10)",
                    "",
                    "# Вывести все вызовы определенной функции",
                    "# p.print_callers('название_функции')",
                    "",
                    "# Вывести все функции, которые вызывает определенная функция",
                    "# p.print_callees('название_функции')",
                }

                vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
                vim.notify("📊 Готовы команды для анализа профилирования", vim.log.levels.INFO)
            end, { desc = "Анализ профилирования Python" })

            map('n', '<leader>pm', function()
                if vim.bo.filetype ~= 'python' then
                    vim.notify("Это не Python файл", vim.log.levels.WARN)
                    return
                end

                local current_file = vim.fn.expand('%:p')
                if current_file == '' then
                    vim.notify("Нет открытого файла", vim.log.levels.ERROR)
                    return
                end

                local check_cmd = 'python -c "import memory_profiler; print(\"memory_profiler установлен\")"'
                local handle = io.popen(check_cmd .. ' 2>&1')
                local result = handle:read('*a')
                handle:close()

                if result:match("ModuleNotFoundError") then
                    vim.notify("⚠️  memory_profiler не установлен. Установите: pip install memory_profiler",
                        vim.log.levels.WARN)
                    Tmux.send_command('pip install memory_profiler')
                    vim.notify("Устанавливаю memory_profiler...", vim.log.levels.INFO)
                end

                local profile_cmd = string.format('python -m memory_profiler "%s"', current_file)
                Tmux.send_command('clear')
                Tmux.send_command(profile_cmd)
                vim.notify("🧠 Запущено профилирование памяти...", vim.log.levels.INFO)
            end, { desc = "Профилирование памяти Python" })

            map('n', '<leader>du', function()
                dapui.toggle()
            end, { desc = "Показать/скрыть UI отладки" })

            dap.listeners.before.attach.dapui_config = function()
                dapui.open()
            end
            dap.listeners.before.launch.dapui_config = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated.dapui_config = function()
                dapui.close()
            end
            dap.listeners.before.event_exited.dapui_config = function()
                dapui.close()
            end
        end,
    },

    -- АВТОСОХРАНЕНИЕ
    {
        "Pocco81/auto-save.nvim",
        config = function()
            require("auto-save").setup({
                enabled = true,
                trigger_events = { "InsertLeave", "TextChanged", "FocusLost" },
                debounce_delay = 1000,
                execution_message = {
                    message = function()
                        return "💾 Автосохранение: " .. vim.fn.expand('%:t')
                    end,
                    dim = 0.18,
                    cleaning_interval = 1250,
                },
            })
        end,
    },

    -- DJANGO SNIPPETS
    {
        "rafamadriz/friendly-snippets",
        config = function()
            require("luasnip.loaders.from_vscode").lazy_load()
        end,
    },

    -- DJANGO CLOSETAG
    {
        "alvan/vim-closetag",
        ft = { "html", "htmldjango" },
        config = function()
            vim.g.closetag_filenames = '*.html,*.htmldjango,*.django'
            vim.g.closetag_filetypes = 'html,htmldjango'
            vim.g.closetag_regions = {
                ['typescript.tsx'] = 'jsxRegion,tsxRegion',
                ['javascript.jsx'] = 'jsxRegion',
                ['htmldjango'] = 'htmlRegion',
            }
        end,
    },

    -- DADBOD (SQL)
    {
        "tpope/vim-dadbod",
        lazy = true,
        cmd = { "DB", "DBUI" },
    },
    {
        "kristijanhusak/vim-dadbod-ui",
        dependencies = {
            "tpope/vim-dadbod",
            "kristijanhusak/vim-dadbod-completion",
        },
        lazy = true,
        cmd = { "DBUI", "DBUIToggle" },
        config = function()
            vim.g.db_ui_auto_execute_table_helpers = 1
            vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/dadbod_ui"
        end,
    },

    -- ЛОКАЛЬНЫЙ AI (GEN.NVIM + LLAMA-SERVER)
    {
        "David-Kunz/gen.nvim",
        config = function()
            require('gen').setup({
                model = "Jackrong/Qwopus3.5-9B-Coder-GGUF:Q5_K_M", -- Имя модели, которую отдает llama-server
                host = "http://127.0.0.1:8080",                    -- Адрес вашего llama-server
                engine = "openai",                                 -- Используем OpenAI-совместимый API формат
                show_prompt = true,
                show_model = true,
                no_auto_close = false,
                display_mode = "float",     -- Открывать ответ в плавающем окне
                no_serve_on_startup = true, -- Не пытаться запустить ollama сервер
            })

            -- Кастомные промпты (адаптировано под gen.nvim)
            -- $text - выделенный текст, $filetype - тип файла, $input - ваш ввод
            require('gen').prompts = {
                ["Спросить о коде"] = {
                    prompt =
                    "Вопрос о следующем коде:\n```$filetype\n$text\n```\n\nВопрос: $input\n\nОтветь на русском языке. Если нужно показать код, оформляй его в Markdown.",
                },
                ["Объяснить код"] = {
                    prompt =
                    "Объясни следующий код:\n```$filetype\n$text\n```\n\nДай подробное объяснение на русском языке.",
                },
                ["Сгенерировать код"] = {
                    prompt =
                    "Сгенерируй код на языке $filetype по описанию:\n$input\n\nПиши чистый, эффективный код. Ответь на русском языке, код оформи в блок.",
                },
            }

            -- Маппинги
            local map = vim.keymap.set
            map({ 'n', 'v' }, '<leader>oo', ':Gen Спросить о коде<CR>', { desc = "Спросить о коде (AI)", silent = true })
            map({ 'n', 'v' }, '<leader>oc', ':Gen<CR>', { desc = "Выбрать AI промпт", silent = true })
        end,
    },
})

-- 8. ФУНКЦИЯ ДЛЯ БЫСТРОГО ПРОФИЛИРОВАНИЯ PYTHON
local PythonProfiler = {}

PythonProfiler.simple_profile = function()
    if vim.bo.filetype ~= 'python' then
        vim.notify("Это не Python файл", vim.log.levels.WARN)
        return
    end

    local current_file = vim.fn.expand('%:p')
    if current_file == '' then
        vim.notify("Нет открытого файла", vim.log.levels.ERROR)
        return
    end

    local temp_script = os.tmpname() .. '_profile.py'
    local script_content = string.format([[
import cProfile
import pstats
import sys

def run_profiling():
    profiler = cProfile.Profile()
    profiler.enable()

    import importlib.util
    spec = importlib.util.spec_from_file_location("__main__", r'%s')
    module = importlib.util.module_from_spec(spec)

    try:
        spec.loader.exec_module(module)
    except SystemExit:
        pass

    profiler.disable()
    stats = pstats.Stats(profiler)
    stats.strip_dirs()

    print("=" * 80)
    print("РЕЗУЛЬТАТЫ ПРОФИЛИРОВАНИЯ: %s")
    print("=" * 80)

    print("\\nТоп-15 функций по кумулятивному времени:")
    print("-" * 80)
    stats.sort_stats('cumulative').print_stats(15)

    print("\\nТоп-10 функций по внутреннему времени:")
    print("-" * 80)
    stats.sort_stats('time').print_stats(10)

    print("\\nТоп-10 функций по количеству вызовов:")
    print("-" * 80)
    stats.sort_stats('calls').print_stats(10)

if __name__ == "__main__":
    run_profiling()
]], current_file, vim.fn.fnamemodify(current_file, ':t'))

    local file = io.open(temp_script, 'w')
    file:write(script_content)
    file:close()

    Tmux.send_command('clear')
    Tmux.send_command('python "' .. temp_script:gsub('"', '\\"') .. '"')
    vim.notify("📊 Запущено профилирование с детальным анализом...", vim.log.levels.INFO)

    vim.defer_fn(function()
        os.remove(temp_script)
    end, 5000)
end

map('n', '<leader>ps', function()
    PythonProfiler.simple_profile()
end, { desc = "Быстрое профилирование Python" })

-- 9. МЕНЕДЖЕР VENV
local VenvManager = {}

VenvManager.find_venv = function()
    local cwd = vim.fn.getcwd()
    local venv_candidates = {
        cwd .. "/venv",
        cwd .. "/.venv",
        cwd .. "/env",
    }

    for _, venv_path in ipairs(venv_candidates) do
        local activate_script = venv_path .. "/bin/activate"
        if vim.fn.filereadable(activate_script) == 1 then
            return venv_path
        end
    end
    return nil
end

VenvManager.select_venv = function()
    local found_venv = VenvManager.find_venv()

    if found_venv then
        vim.ui.select({ "Да", "Нет" }, {
            prompt = "🔍 Обнаружено виртуальное окружение: " ..
                vim.fn.fnamemodify(found_venv, ":t") .. "\nИспользовать его для этого проекта?",
        }, function(choice)
            if choice == "Да" then
                Tmux.send_command('source ' .. found_venv .. '/bin/activate')
                vim.notify("✅ Виртуальное окружение активировано: " .. found_venv, vim.log.levels.INFO)
            end
        end)
    else
        vim.ui.select({ "Создать venv", "Пропустить" }, {
            prompt = "Виртуальное окружение не найдено. Создать?",
        }, function(choice)
            if choice == "Создать venv" then
                vim.ui.input({
                    prompt = "Команда Python (по умолчанию python3):",
                    default = "python3"
                }, function(python_cmd)
                    if python_cmd == nil then return end

                    vim.ui.input({
                        prompt = "Имя окружения (по умолчанию venv):",
                        default = "venv"
                    }, function(venv_name)
                        if venv_name == nil then return end

                        python_cmd = python_cmd:gsub("%s+$", "")
                        venv_name = venv_name:gsub("%s+$", "")

                        if python_cmd == "" then python_cmd = "python3" end
                        if venv_name == "" then venv_name = "venv" end

                        local create_cmd = python_cmd .. " -m venv " .. venv_name
                        Tmux.send_command(create_cmd)

                        local activate_cmd = "source ./" .. venv_name .. "/bin/activate"
                        Tmux.send_command(activate_cmd)

                        vim.notify("✅ Виртуальное окружение создано и активировано: " .. venv_name, vim.log.levels.INFO)
                    end)
                end)
            end
        end)
    end
end

-- 10. АВТОКОМАНДЫ ДЛЯ DJANGO И ОТСТУПОВ
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*/templates/*.html", "*/templates/*.django" },
    callback = function()
        vim.bo.filetype = "htmldjango"
    end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile", "FileType" }, {
    pattern = { "*/templates/*.html", "*.htmldjango", "htmldjango" },
    callback = function()
        vim.bo.tabstop = 2
        vim.bo.shiftwidth = 2
        vim.bo.softtabstop = 2
        vim.bo.expandtab = true
        vim.bo.autoindent = true
    end,
    desc = "Установить отступ 2 пробела для Django шаблонов"
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    callback = function()
        vim.bo.tabstop = 4
        vim.bo.shiftwidth = 4
        vim.bo.softtabstop = 4
        vim.bo.expandtab = true
    end,
})

vim.api.nvim_create_autocmd({ "VimEnter" }, {
    pattern = "*",
    callback = function()
        vim.defer_fn(function()
            if vim.fn.isdirectory(vim.fn.getcwd()) == 1 then
                VenvManager.select_venv()
            end
        end, 1000)
    end,
})

-- 11. КЛАВИШИ ДЛЯ УПРАВЛЕНИЯ VENV И DJANGO
map('n', '<leader>pv', function()
    VenvManager.select_venv()
end, { desc = 'Select Python venv' })

map('n', '<leader>dm', function()
    Tmux.send_command('python manage.py migrate')
end, { desc = "Django migrate" })

map('n', '<leader>dmm', function()
    Tmux.send_command('python manage.py makemigrations')
end, { desc = "Django makemigrations" })

map('n', '<leader>dr', function()
    Tmux.send_command('python manage.py runserver')
end, { desc = "Django runserver" })

map('n', '<leader>dtc', function()
    Tmux.send_command('python manage.py test')
end, { desc = "Django тесты" })

map('n', '<leader>is', function()
    vim.cmd('w')
    vim.cmd('!isort --profile black %')
    vim.cmd('e!')
    vim.notify("✅ Импорты отсортированы", vim.log.levels.INFO)
end, { desc = "Сортировать импорты (isort)" })

map('n', '<leader>ia', function()
    vim.cmd('!isort .')
    vim.cmd('e!')
end, { desc = "Сортировать импорты во всем проекте" })

map('n', '<leader>ic', function()
    vim.cmd('!isort --check-only --diff .')
end, { desc = "Проверить импорты во всем проекте" })

map('n', '<leader>tc', function()
    local command = vim.ui_input({
        prompt = "Введите команду для выполнения в терминале:",
        default = ""
    })

    if command and command ~= "" then
        Tmux.send_command(command)
    end
end, { desc = "Выполнить команду в tmux" })

map('n', '<leader>tv', function() VenvManager.select_venv() end, { desc = "Управление виртуальным окружением" })

map('n', '<leader>rr', Tmux.run_current_file, { desc = "Запустить текущий файл в терминале tmux" })

-- 12. ИНФОРМАЦИЯ ПРИ ЗАГРУЗКЕ
vim.defer_fn(function()
    print("🚀 NEOVIM + TMUX ИНТЕГРАЦИЯ С ПРОФИЛИРОВАНИЕМ PYTHON И DJANGO")
    print("=" .. string.rep("=", 50))
    print("📋 ОСНОВНЫЕ КОМАНДЫ:")
    print("   <ПРОБЕЛ>nt  - Файловый менеджер")
    print("   <ПРОБЕЛ>lf  - Форматировать код")
    print("   <ПРОБЕЛ>rr  - Запустить код в tmux")
    print("   <ПРОБЕЛ>tc  - Команда в tmux")
    print("   <ПРОБЕЛ>tv  - Управление venv")
    print("")
    print("🎨 DJANGO КОМАНДЫ:")
    print("   <ПРОБЕЛ>dm  - Django migrate")
    print("   <ПРОБЕЛ>dmm - Django makemigrations")
    print("   <ПРОБЕЛ>dr  - Django runserver")
    print("   <ПРОБЕЛ>dtc - Django тесты")
    print("   <ПРОБЕЛ>dt  - Поиск Django тегов")
    print("")
    print("📊 ПРОФИЛИРОВАНИЕ PYTHON:")
    print("   <ПРОБЕЛ>pp  - Запустить cProfile")
    print("   <ПРОБЕЛ>pa  - Анализ профилирования")
    print("   <ПРОБЕЛ>pm  - Профилирование памяти")
    print("   <ПРОБЕЛ>ps  - Быстрое профилирование")
    print("")
    print("📦 СОРТИРОВКА ИМПОРТОВ (isort):")
    print("   <ПРОБЕЛ>is  - Сортировать импорты в текущем файле")
    print("   <ПРОБЕЛ>ia  - Сортировать импорты во всем проекте")
    print("   <ПРОБЕЛ>ic  - Проверить импорты во всем проекте")
    print("")
    print("🐞 ОТЛАДКА:")
    print("   F5          - Продолжить отладку")
    print("   F9          - Установить точку останова")
    print("   F10         - Шаг через")
    print("   F11         - Шаг внутрь")
    print("   F12         - Шаг наружу")
    print("   <ПРОБЕЛ>du  - Показать UI отладки")
    print("")
    print("🤖 AI-ПОМОЩНИК (ЛОКАЛЬНЫЙ):")
    print("   <ПРОБЕЛ>ll  - Принудительный вызов автодополнения")
    print("   (работает автоматически через меню nvim-cmp)")
    print("")
    print("🗄️  БАЗЫ ДАННЫХ:")
    print("   :DBUI       - Открыть интерфейс Dadbod")
    print("=" .. string.rep("=", 50))

    vim.schedule(function()
        local missing_tools = {}

        if vim.fn.executable('python3') == 0 then
            table.insert(missing_tools, "python3")
        end

        if vim.fn.executable('black') == 0 then
            table.insert(missing_tools, "black")
        end

        if vim.fn.executable('flake8') == 0 then
            table.insert(missing_tools, "flake8")
        end

        if vim.fn.executable('tmux') == 0 then
            table.insert(missing_tools, "tmux")
        end

        if vim.fn.executable('djlint') == 0 then
            vim.notify("⚠️  djlint не установлен (для форматирования Django шаблонов)", vim.log.levels.WARN)
            vim.notify("   Установите: pip install --user djlint", vim.log.levels.INFO)
        end

        if vim.fn.executable('isort') == 0 then
            vim.notify("⚠️  isort не установлен (для сортировки импортов)", vim.log.levels.WARN)
            vim.notify("   Установите: pip install --user isort", vim.log.levels.INFO)
        end

        if #missing_tools > 0 then
            vim.notify("⚠️  Отсутствуют инструменты: " .. table.concat(missing_tools, ", "), vim.log.levels.WARN)
            vim.notify("   Установите: sudo pacman -S python python-black python-flake8 tmux", vim.log.levels.INFO)
        else
            vim.notify("✅ Все инструменты установлены", vim.log.levels.INFO)
        end
    end)
end, 100)

print("✅ Конфигурация Neovim с профилированием Python, Django и локальным AI загружена!")
