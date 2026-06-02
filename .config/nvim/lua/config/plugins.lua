-- =============================================
-- УСТАНОВКА И НАСТРОЙКА ПЛАГИНОВ (LAZY.NVIM)
-- =============================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

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

    -- DJANGO ПОДСВЕТКА
    {
        "tweekmonster/django-plus.vim",
        ft = { "htmldjango", "html", "python" },
        config = function()
            vim.g.django_highlight_all = 1
            vim.g.django_filetype = 1
            vim.g.django_highlight_html = 1
        end,
    },

    -- NVIMTREE
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            vim.g.loaded_netrw = 1
            vim.g.loaded_netrwPlugin = 1
            local api = require("nvim-tree.api")
            local function send_cd_to_tmux(path)
                if not path then return end
                local safe_path = path:gsub("'", "'\\''")
                local tmux_cmd = string.format("tmux send-keys -t 2 'cd %s && pwd' Enter", safe_path)
                os.execute(tmux_cmd)
                vim.notify("📁 Tmux: перешел в " .. path, vim.log.levels.INFO)
            end

            require("nvim-tree").setup({
                view = { width = 35, number = false, relativenumber = false },
                renderer = {
                    icons = {
                        show = { file = true, folder = true, folder_arrow = true, git = true },
                        glyphs = { default = "", symlink = "", folder = { arrow_closed = "", arrow_open = "", default = "", open = "", empty = "", empty_open = "", symlink = "", symlink_open = "" } },
                    },
                    indent_markers = { enable = true, inline_arrows = true, icons = { corner = "└", edge = "│", item = "│", none = " " } },
                },
                filters = { dotfiles = false, custom = { "^\\.git$" } },
                git = { enable = true, ignore = false },
                update_focused_file = { enable = true, update_cwd = true },
                actions = {
                    open_file = { quit_on_open = false, window_picker = { enable = false } },
                    change_dir = { enable = true, global = true },
                },
                on_attach = function(bufnr)
                    local function opts(desc) return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true } end
                    vim.keymap.set("n", "<CR>", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "o", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
                    vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "C", function()
                        local node = api.tree.get_node_under_cursor()
                        if node and node.type == "directory" then
                            api.tree.change_root_to_node(node)
                            send_cd_to_tmux(node.absolute_path)
                        end
                    end, opts("Change Root & Sync Tmux"))
                end,
            })
            vim.keymap.set('n', '<leader>nt', api.tree.toggle, { desc = "Файловый менеджер" })
        end,
    },

    -- СТАТУСНАЯ СТРОКА
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons", "catppuccin/nvim" }, -- Добавлен catppuccin
        config = function()
            require("lualine").setup({
                options = {
                    theme = "auto" -- Изменено на auto, чтобы автоматически подхватывать catppuccin
                },
                sections = {
                    lualine_c = {
                        { 'diagnostics', sources = { 'nvim_diagnostic' }, symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' } },
                        { 'filetype', icon_only = true, separator = '', padding = { left = 1, right = 0 } },
                        { function() return vim.bo.filetype == 'htmldjango' and '󰌠 Django' or '' end, color = { fg = '#f38ba8', gui = 'bold' } }
                    }
                }
            })
        end,
    },

    -- АВТОДОПОЛНЕНИЕ СКОБОК И ЗАКРЫТИЕ ТЕГОВ
    { "windwp/nvim-autopairs",        event = "InsertEnter",                                                                          config = true },
    {
        "alvan/vim-closetag",
        ft = { "html", "htmldjango" },
        config = function()
            vim.g.closetag_filetypes =
            'html,htmldjango'
        end
    },

    -- ЛИНИИ ОТСТУПОВ
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

    -- TREESITTER
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = { "python", "lua", "bash", "javascript", "typescript", "html", "css" },
                highlight = { enable = true, additional_vim_regex_highlighting = false },
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
            local map = vim.keymap.set
            map('n', '<leader>ff', builtin.find_files, { desc = "Найти файлы" })
            map('n', '<leader>fg', builtin.live_grep, { desc = "Найти в файлах" })
            map('n', '<leader>fd', builtin.diagnostics, { desc = "Найти диагностики" })
            map('n', '<leader>dt',
                function() builtin.current_buffer_fuzzy_find({ prompt_title = "Поиск Django тегов", default_text = "{%" }) end,
                { desc = "Поиск Django тегов" })
        end
    },

    -- LSP И АВТОДОПОЛНЕНИЕ (ОБНОВЛЕНО ДЛЯ NEOVIM 0.11+)
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim",
            "hrsh7th/nvim-cmp", "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path",
            "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip",
        },
        config = function()
            require("mason").setup()
            require("mason-lspconfig").setup({ ensure_installed = { "pyright", "lua_ls", "bashls", "ts_ls", "html" } })

            local cmp = require("cmp")
            local luasnip = require("luasnip")

            cmp.setup({
                snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
                mapping = cmp.mapping.preset.insert({
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<CR>'] = cmp.mapping.confirm({ select = true }),
                    ['<Tab>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip
                                .expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ['<S-Tab>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({ { name = 'nvim_lsp' }, { name = 'luasnip' } },
                    { { name = 'buffer' }, { name = 'path' } }),
            })

            -- 1. Глобальные настройки для ВСЕХ LSP серверов (заменяет capabilities = capabilities)
            vim.lsp.config['*'] = {
                capabilities = require('cmp_nvim_lsp').default_capabilities()
            }

            -- 2. Глобальный маппинг для LSP (заменяет on_attach = on_attach)
            vim.api.nvim_create_autocmd('LspAttach', {
                group = vim.api.nvim_create_augroup('UserLspConfig', {}),
                callback = function(ev)
                    local opts = { buffer = ev.buf, noremap = true, silent = true }
                    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
                    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
                    vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format { async = true } end, opts)
                end,
            })

            -- Настройка Pyright с авто-поиском venv
            local function find_venv()
                local cwd = vim.fn.getcwd()
                for _, name in ipairs({ "venv", ".venv", "env" }) do
                    if vim.fn.isdirectory(cwd .. "/" .. name) == 1 then return name, cwd end
                end
                return nil, cwd
            end

            -- 3. НОВЫЙ СИНТАКСИС: vim.lsp.config вместо require("lspconfig").server.setup
            vim.lsp.config['pyright'] = {
                cmd = { 'pyright-langserver', '--stdio' },
                filetypes = { 'python' },
                root_markers = { 'pyproject.toml', 'setup.py', 'requirements.txt', 'manage.py', '.git' },
                settings = {
                    python = {
                        analysis = { typeCheckingMode = "basic", autoSearchPaths = true, diagnosticMode = "workspace" }
                    }
                },
                on_new_config = function(new_config, new_root_dir)
                    local venv_name, venv_path = find_venv()
                    if venv_name then
                        new_config.settings.python.venvPath = venv_path
                        new_config.settings.python.venv = venv_name
                    end
                end
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
                        telemetry = { enable = false }
                    }
                }
            }

            vim.lsp.config['bashls'] = {
                cmd = { 'bash-language-server', 'start' },
                filetypes = { 'sh', 'bash' },
            }

            vim.lsp.config['ts_ls'] = {
                cmd = { 'typescript-language-server', '--stdio' },
                filetypes = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
                root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
            }

            vim.lsp.config['html'] = {
                cmd = { 'vscode-html-language-server', '--stdio' },
                filetypes = { 'html', 'htmldjango' },
                init_options = {
                    configurationSection = { 'html', 'css', 'javascript' },
                    embeddedLanguages = { css = true, javascript = true },
                    provideFormatter = true
                },
            }

            -- 4. Включаем серверы (заменяет собой вызовы setup())
            vim.lsp.enable('pyright')
            vim.lsp.enable('lua_ls')
            vim.lsp.enable('bashls')
            vim.lsp.enable('ts_ls')
            vim.lsp.enable('html')
        end,
    },

    -- ФОРМАТИРОВАНИЕ
    {
        "stevearc/conform.nvim",
        config = function()
            require("conform").setup({
                formatters_by_ft = { python = { "isort", "black" }, lua = { "stylua" }, javascript = { "prettier" }, typescript = { "prettier" }, html = { "djlint" }, htmldjango = { "djlint" }, css = { "prettier" } },
                format_on_save = { timeout_ms = 1000, lsp_fallback = true },
            })
            vim.keymap.set('n', '<leader>lf', '<cmd>lua require("conform").format()<cr>', { desc = "Форматировать" })
        end,
    },

    -- AI АВТОДОПОЛНЕНИЕ
    {
        "supermaven-inc/supermaven-nvim",
        config = function()
            require("supermaven-nvim").setup({
                keymaps = { accept_suggestion = "<C-g>", clear_suggestion = "<C-]>", accept_word = "<C-j>" }
            })
        end,
    },

    -- ЛИНТИНГ
    {
        "mfussenegger/nvim-lint",
        config = function()
            require("lint").linters_by_ft = { python = { "flake8" }, lua = { "selene" }, sh = { "shellcheck" }, htmldjango = { "djlint" }, html = { "djlint" } }
            vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
                callback = function() vim.defer_fn(function() require("lint").try_lint() end, 100) end,
            })
        end,
    },

    -- DAP (ОТЛАДКА) - ИСПРАВЛЕНО И УЛУЧШЕНО
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

            -- ИСПРАВЛЕНО: используем nvim-dap-python как положено
            require("dap-python").setup("python")
            require("dap-python").test_runner = "pytest"

            -- Маппинги DAP
            local map = vim.keymap.set
            map('n', '<F5>', dap.continue, { desc = "Продолжить отладку" })
            map('n', '<F9>', dap.toggle_breakpoint, { desc = "Точка останова" })
            map('n', '<F10>', dap.step_over, { desc = "Шаг через" })
            map('n', '<F11>', dap.step_into, { desc = "Шаг внутрь" })
            map('n', '<F12>', dap.step_out, { desc = "Шаг наружу" })
            map('n', '<leader>du', dapui.toggle, { desc = "Показать/скрыть UI отладки" })

            -- Маппинги для pytest от nvim-dap-python
            map('n', '<leader>dt', function() require("dap-python").test_method() end,
                { desc = "Отладить тест под курсором" })
            map('n', '<leader>dc', function() require("dap-python").test_class() end,
                { desc = "Отладить класс под курсором" })

            dap.listeners.before.attach.dapui_config = function() dapui.open() end
            dap.listeners.before.launch.dapui_config = function() dapui.open() end
            dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
            dap.listeners.before.event_exited.dapui_config = function() dapui.close() end
        end,
    },

    -- НОВОЕ: PYTEST.NVIM
    {
        "richardhapb/pytest.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        ft = { "python" },
        config = function()
            require("pytest").setup({
                django = { enabled = true }, -- Автоматически понимает Django проекты
            })
        end,
    },

    -- НОВОЕ: VIM-SLIME (Улучшенная отправка кода в Tmux REPL)
    {
        "jpalardy/vim-slime",
        config = function()
            vim.g.slime_target = "tmux"
            vim.g.slime_default_config = { socket_name = "default", target_pane = "{right}" }
            vim.g.slime_dont_ask_default = 1
            -- Отправка абзаца в REPL: <leader>ss
            vim.keymap.set({ "n", "v" }, "<leader>ss", "<Plug>SlimeLineSend",
                { desc = "Отправить строку/выделение в REPL" })
        end,
    },

    -- GIT ИНТЕГРАЦИЯ
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
                current_line_blame = true, -- Включает виртуальный текст с автором строки
                current_line_blame_opts = {
                    virt_text = true,
                    virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
                    delay = 500,
                },
                on_attach = function(bufnr)
                    local gs = package.loaded.gitsigns

                    local function map(mode, l, r, opts)
                        opts = opts or {}
                        opts.buffer = bufnr
                        vim.keymap.set(mode, l, r, opts)
                    end

                    -- Навигация по изменениям
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

                    -- Действия с блоками кода (hunks)
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

    {
        "NeogitOrg/neogit",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "sindrets/diffview.nvim",        -- Необязательно, но отлично интегрируется
            "nvim-telescope/telescope.nvim", -- Необязательно
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

    -- АВТОСОХРАНЕНИЕ И СНИППЕТЫ
    { "Pocco81/auto-save.nvim",       config = function() require("auto-save").setup({ execution_message = { enabled = false } }) end },
    { "rafamadriz/friendly-snippets", config = function() require("luasnip.loaders.from_vscode").lazy_load() end },

    -- БАЗЫ ДАННЫХ
    { "tpope/vim-dadbod",             lazy = true,                                                                                    cmd = { "DB", "DBUI" } },
    { "kristijanhusak/vim-dadbod-ui", dependencies = { "tpope/vim-dadbod", "kristijanhusak/vim-dadbod-completion" },                  lazy = true,           cmd = { "DBUI", "DBUIToggle" } },

    -- ЛОКАЛЬНЫЙ AI (ИСПРАВЛЕНО: английские ключи для промптов)
    {
        "David-Kunz/gen.nvim",
        config = function()
            require('gen').setup({
                model = "Jackrong/Qwopus3.5-9B-Coder-GGUF:Q5_K_M",
                host = "http://127.0.0.1:8080",
                engine = "openai",
                show_prompt = true,
                show_model = true,
                no_auto_close = false,
                display_mode = "float",
            })

            -- Используем английские ключи, чтобы избежать проблем с парсингом кириллицы в :Gen
            require('gen').prompts = {
                ["ask"] = {
                    prompt =
                    "Вопрос о следующем коде:\n```$filetype\n$text\n```\n\nВопрос: $input\n\nОтветь на русском языке. Если нужно показать код, оформляй его в Markdown.",
                },
                ["explain"] = {
                    prompt =
                    "Объясни следующий код:\n```$filetype\n$text\n```\n\nДай подробное объяснение на русском языке.",
                },
                ["generate"] = {
                    prompt =
                    "Сгенерируй код на языке $filetype по описанию:\n$input\n\nПиши чистый, эффективный код. Ответь на русском языке, код оформи в блок.",
                },
            }

            local map = vim.keymap.set
            map({ 'n', 'v' }, '<leader>oo', ':Gen ask<CR>', { desc = "Спросить о коде (AI)", silent = true })
            map({ 'n', 'v' }, '<leader>oe', ':Gen explain<CR>', { desc = "Объяснить код (AI)", silent = true })
            map({ 'n', 'v' }, '<leader>og', ':Gen generate<CR>', { desc = "Сгенерировать код (AI)", silent = true })
            map({ 'n', 'v' }, '<leader>oc', ':Gen<CR>', { desc = "Выбрать AI промпт из списка", silent = true })
        end,
    },
})
