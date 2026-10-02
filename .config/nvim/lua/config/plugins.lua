-- =============================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Загрузка ключа opencode-zen из ~/.hermes/.env.
--
-- Ключ не в окружении nvim, а в файле, поэтому читаем файл напрямую.
-- Секрет НЕ попадает в конфиг и в подписи на диске — только в память
-- процесса на время запроса.
_G.CCLoadKey = function()
    local path = vim.fn.expand("~/.hermes/.env")
    if vim.fn.filereadable(path) == 0 then return "" end
    for _, line in ipairs(vim.fn.readfile(path)) do
        local k, v = line:match("^%s*(%u[%u%d_]*)%s*=%s*(.-)%s*$")
        if k == "OPENCODE_ZEN_API_KEY" then
            -- Снимаем возможные кавычки, .env их допускает
            v = v:gsub('^["\']', ""):gsub('["\']$', "")
            return v
        end
    end
    return ""
end

-- Сборка адаптера codecompanion под конкретный OpenAI-совместимый endpoint.
-- Одна функция на chat и inline: иначе они разъезжаются (было именно так —
-- в inline остался url без /chat/completions и model не в schema, то есть
-- inline не работал бы).
--
-- url нужен ПОЛНЫМ, до /chat/completions: при url без пути запрос попадает
-- в корень API и приходит HTML вместо JSON.
-- Модель — через schema.model.default, поле model верхнего уровня не
-- попадает в schema (оставался дефолт gpt-4.1).
--
-- ПЕРЕКЛЮЧЕНИЕ НА ЛОКАЛЬНУЮ МОДЕЛЬ — меняются только эти две строки:
--
--   url = "http://127.0.0.1:8080/v1/chat/completions"
--   schema = { model = { default = "<имя модели>" } }
--
-- Требования к сервису: sudo systemctl enable --now llama-server
-- (unit тянет модель через -hf, качает с HuggingFace при первом старте).
-- api_key для локального сервера можно оставить как есть: llama.cpp его
-- не проверяет, а CCLoadKey вернёт "dummy", если .env нет.
-- Локальный ollama: url = "http://127.0.0.1:11434/v1/chat/completions"
local function cc_adapter()
    local AH = require("codecompanion.adapters.http")
    local base = require("codecompanion.adapters.http.openai")
    return AH.extend(base, {
        url = "https://opencode.ai/zen/v1/chat/completions",
        schema = { model = { default = "space-bunny-free" } },
        env = {
            api_key = function() return _G.CCLoadKey() end,
        },
        -- Cloudflare отвечает 403 (error code 1010) на запросы вообще без
        -- User-Agent. Проверено сравнением: пустой UA -> 403, непустой -> 200.
        headers = {
            ["Content-Type"] = "application/json",
            Authorization = "Bearer ${api_key}",
            ["User-Agent"] = "curl/8.22.0",
        },
    })
end


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
                        glyphs = { default = "󰈔", symlink = "󰈙", folder = { arrow_closed = "", arrow_open = "", default = "", open = "", empty = "", empty_open = "", symlink = "" } },
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

                    -- НАВИГАЦИЯ И ОТКРЫТИЕ
                    vim.keymap.set("n", "<CR>", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "o", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "<2-LeftMouse>", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
                    vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))

                    -- ФАЙЛОВЫЕ ОПЕРАЦИИ
                    vim.keymap.set("n", "a", api.fs.create, opts("Create File/Dir"))
                    vim.keymap.set("n", "d", api.fs.remove, opts("Delete"))
                    vim.keymap.set("n", "r", api.fs.rename, opts("Rename"))
                    vim.keymap.set("n", "e", api.fs.rename_basename, opts("Rename Basename"))
                    vim.keymap.set("n", "c", api.fs.copy.node, opts("Copy"))
                    vim.keymap.set("n", "p", api.fs.paste, opts("Paste"))
                    vim.keymap.set("n", "x", api.fs.cut, opts("Cut"))
                    vim.keymap.set("n", "y", api.fs.copy.filename, opts("Copy Name"))

                    -- СИНХРОНИЗАЦИЯ С TMUX
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

    -- BREADCRUMBS (ХЛЕБНЫЕ КРОШКИ КАК В VSCODE)
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

    -- СТАТУСНАЯ СТРОКА
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
                ensure_installed = {
                    "python", "lua", "bash", "javascript", "typescript", "html", "css",
                    -- Нужны самому codecompanion: yaml — парсит frontmatter промптов,
                    -- markdown и markdown_inline — разбирают сообщения и буфер чата
                    -- (ts_parse_buffer в chat/context.lua),
                    -- json — конфиги и ответы API
                    "yaml", "markdown", "markdown_inline", "json", "toml",
                },
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
            -- НОВОЕ: Поиск символов (функции/классы)
            map('n', '<leader>cs', builtin.lsp_document_symbols, { desc = "Символы файла (функции/классы)" })
            map('n', '<leader>cS', builtin.lsp_workspace_symbols, { desc = "Символы проекта (все файлы)" })
        end
    },

    -- СИМВОЛЫ (OUTLINE КАК В VSCODE)
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

    -- LSP И АВТОДОПОЛНЕНИЕ (ОБНОВЛЕНО ДЛЯ NEOVIM 0.11+)
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
            "saadparwaiz1/cmp_luasnip",
        },
        config = function()
            require("mason").setup()
            require("mason-lspconfig").setup({
                ensure_installed = { "pyright", "lua_ls", "bashls", "ts_ls", "html" },
            })

            local cmp = require("cmp")
            local luasnip = require("luasnip")
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<CR>"] = cmp.mapping.confirm({ select = true }),
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources(
                    { { name = "nvim_lsp" }, { name = "luasnip" } },
                    { { name = "buffer" }, { name = "path" } }
                ),
            })

            vim.lsp.config["*"] = {
                capabilities = capabilities,
            }

            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserLspConfig", {}),
                callback = function(ev)
                    local opts = { buffer = ev.buf, noremap = true, silent = true }

                    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
                    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
                    vim.keymap.set("n", "<leader>f", function()
                        vim.lsp.buf.format({ async = true })
                    end, opts)
                end,
            })

            local function normalize_dir(path)
                if not path or path == "" then
                    return nil
                end

                path = vim.fn.fnamemodify(path, ":p")

                if vim.fn.isdirectory(path) ~= 1 then
                    path = vim.fn.fnamemodify(path, ":h")
                end

                return path
            end

            local function is_venv_dir(path)
                if vim.fn.isdirectory(path) ~= 1 then
                    return false
                end

                if vim.fn.filereadable(path .. "/pyvenv.cfg") == 1 then
                    return true
                end

                if vim.fn.has("win32") == 1 then
                    return vim.fn.executable(path .. "/Scripts/python.exe") == 1
                        or vim.fn.executable(path .. "/python.exe") == 1
                end

                return vim.fn.executable(path .. "/bin/python") == 1
                    or vim.fn.executable(path .. "/bin/python3") == 1
            end

            local function find_venv(root_dir)
                local base_path = normalize_dir(root_dir) or vim.fn.getcwd()
                base_path = vim.fn.fnamemodify(base_path, ":p")

                for _, name in ipairs({ ".venv", "venv", "env" }) do
                    local venv_path = base_path .. "/" .. name
                    if is_venv_dir(venv_path) then
                        return name, base_path, venv_path
                    end
                end

                return nil, base_path, nil
            end

            local function get_python_executable(venv_path)
                if vim.fn.has("win32") == 1 then
                    if vim.fn.executable(venv_path .. "/Scripts/python.exe") == 1 then
                        return venv_path .. "/Scripts/python.exe"
                    end

                    if vim.fn.executable(venv_path .. "/python.exe") == 1 then
                        return venv_path .. "/python.exe"
                    end

                    return venv_path .. "/Scripts/python.exe"
                else
                    if vim.fn.executable(venv_path .. "/bin/python") == 1 then
                        return venv_path .. "/bin/python"
                    end

                    if vim.fn.executable(venv_path .. "/bin/python3") == 1 then
                        return venv_path .. "/bin/python3"
                    end

                    return venv_path .. "/bin/python"
                end
            end

            local function apply_pyright_venv(settings, root_dir)
                if type(settings) ~= "table" then
                    return
                end

                local venv_name, venv_parent, venv_path = find_venv(root_dir)
                if not venv_name or not venv_path then
                    return
                end

                settings.python = settings.python or {}
                settings.python.analysis = settings.python.analysis or {}

                -- То, что обычно понимает Pyright через LSP
                settings.python.analysis.venvPath = venv_parent
                settings.python.analysis.venv = venv_name

                -- Дублируем на случай совместимости с разными клиентами/сборками
                settings.python.venvPath = venv_parent
                settings.python.venv = venv_name
                settings.python.pythonPath = get_python_executable(venv_path)
            end
            local pyright_settings = {
                python = {
                    analysis = {
                        typeCheckingMode = "basic",
                        autoSearchPaths = true,
                        diagnosticMode = "workspace",
                    },
                },
            }

            vim.lsp.config["pyright"] = {
                capabilities = capabilities,
                cmd = { "pyright-langserver", "--stdio" },
                filetypes = { "python" },
                root_markers = {
                    "pyproject.toml",
                    "setup.py",
                    "requirements.txt",
                    "manage.py",
                    ".git",
                },
                settings = pyright_settings,

                before_init = function(params, config)
                    local root_dir = config and config.root_dir or nil

                    if not root_dir and params and params.rootUri then
                        local ok, fname = pcall(vim.uri_to_fname, params.rootUri)
                        if ok then
                            root_dir = fname
                        end
                    end

                    if not root_dir and params and params.rootPath then
                        root_dir = params.rootPath
                    end

                    config.settings = vim.deepcopy(pyright_settings)
                    apply_pyright_venv(config.settings, root_dir)
                end,

                on_init = function(client)
                    if not client.config.settings then
                        client.config.settings = vim.deepcopy(pyright_settings)
                    end

                    local root_dir = client.root_dir or client.config.root_dir
                    apply_pyright_venv(client.config.settings, root_dir)

                    vim.schedule(function()
                        pcall(function()
                            client.notify("workspace/didChangeConfiguration", {
                                settings = client.config.settings,
                            })
                        end)
                    end)
                end,
            }

            vim.lsp.config["lua_ls"] = {
                capabilities = capabilities,
                cmd = { "lua-language-server" },
                filetypes = { "lua" },
                root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        diagnostics = { globals = { "vim" } },
                        workspace = {
                            library = vim.api.nvim_get_runtime_file("", true),
                            checkThirdParty = false,
                        },
                        telemetry = { enable = false },
                    },
                },
            }

            vim.lsp.config["bashls"] = {
                capabilities = capabilities,
                cmd = { "bash-language-server", "start" },
                filetypes = { "sh", "bash" },
            }

            vim.lsp.config["ts_ls"] = {
                capabilities = capabilities,
                cmd = { "typescript-language-server", "--stdio" },
                filetypes = {
                    "javascript",
                    "typescript",
                    "javascriptreact",
                    "typescriptreact",
                },
                root_markers = {
                    "package.json",
                    "tsconfig.json",
                    "jsconfig.json",
                    ".git",
                },
            }

            vim.lsp.config["html"] = {
                capabilities = capabilities,
                cmd = { "vscode-html-language-server", "--stdio" },
                filetypes = { "html", "htmldjango" },
                init_options = {
                    configurationSection = { "html", "css", "javascript" },
                    embeddedLanguages = {
                        css = true,
                        javascript = true,
                    },
                    provideFormatter = true,
                },
            }

            vim.lsp.enable({
                "pyright",
                "lua_ls",
                "bashls",
                "ts_ls",
                "html",
            })
        end,
    },

    -- ФОРМАТИРОВАНИЕ (CONFORM) С ISORT, BLACK И AUTOPEP8
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

    -- PYTEST.NVIM
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

    -- VIM-SLIME
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
                current_line_blame = true,
                current_line_blame_opts = {
                    virt_text = true,
                    virt_text_pos = 'eol',
                    delay = 500,
                },
                on_attach = function(bufnr)
                    local gs = package.loaded.gitsigns

                    local function map(mode, l, r, opts)
                        opts = opts or {}
                        opts.buffer = bufnr
                        vim.keymap.set(mode, l, r, opts)
                    end

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

    -- =============================================
    -- УДОБСТВА И НАВИГАЦИЯ
    -- =============================================

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

    -- 2. Обертывание текста в кавычки/скобки/теги
    {
        "kylechui/nvim-surround",
        version = "*",
        event = "VeryLazy",
        config = function()
            require("nvim-surround").setup({})
        end
    },

    -- 3. Поиск TODO/FIXME по проекту
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

    -- 4. Список ошибок во всем проекте
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

    -- АВТОСОХРАНЕНИЕ И СНИППЕТЫ
    { "Pocco81/auto-save.nvim",       config = function() require("auto-save").setup({ execution_message = { enabled = false } }) end },
    { "rafamadriz/friendly-snippets", config = function() require("luasnip.loaders.from_vscode").lazy_load() end },

    -- БАЗЫ ДАННЫХ
    { "tpope/vim-dadbod",             lazy = true,                                                                                    cmd = { "DB", "DBUI" } },
    { "kristijanhusak/vim-dadbod-ui", dependencies = { "tpope/vim-dadbod", "kristijanhusak/vim-dadbod-completion" },                  lazy = true,           cmd = { "DBUI", "DBUIToggle" } },

    -- AI АССИСТЕНТ
    --
    -- Заменил gen.nvim на codecompanion.nvim. Причины конкретные:
    --   1. gen.nvim склеивает URL сам ("http://" + host + port), из-за
    --      переданного host со схемой получалось http://http://127.0.0.1:8080:11434
    --   2. опция engine = "openai" в gen.nvim не существует — в коде плагина
    --      ноль упоминаний, значение уходило в пустоту
    --   3. codecompanion — чистый Lua, зависимость только plenary (уже стоит),
    --      в отличие от avante.nvim, которому нужен Rust или бинарник на 18 МБ
    --
    -- Ключи берутся из переменных окружения, в конфиге их нет.
    -- Пока переменная не задана, плагин работает, но запросы падают —
    -- об этом сообщает стартовое уведомление ниже.
    --
    -- Адаптер opencode-zen: провайдер Hermes, base_url https://opencode.ai/zen/v1,
    -- модель space-bunny-free. Проверен curl'ом — отвечает 200.
    -- Ключ лежит в ~/.hermes/.env как OPENCODE_ZEN_API_KEY, поэтому
    -- options.env ниже подтягивает его ОТТУДА и не требует дублирования
    -- секрета в .zshrc или в этом файле.
    {
        "olimorris/codecompanion.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        -- Команды И клавиши. Одного cmd мало: при cmd config() с маппингами
        -- не выполняется, пока команду не вызвать — но вызвать её можно было
        -- только по несуществующей клавише. Замкнутый круг, из-за которого
        -- <leader>oo не существовал. event = "VeryLazy" разрывает его.
        cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
        event = "VeryLazy",
        opts = {
            opts = {
                log_level = "WARN",
                send_code = true,
            },
            -- Свой endpoint задаётся через strategies.chat.adapter таблицей:
            -- resolve() на init.lua:321-330 идёт в Adapter.new(adapter) и НЕ
            -- применяет strategies.chat.opts — init_adapter зовёт
            -- resolve(config.interactions.chat.adapter) БЕЗ opts (chat/init.lua:417).
            -- Поэтому url в chat.opts молча игнорировался.
            strategies = {
                -- Контекст файла. /buffer в плагине есть, но по умолчанию
                -- шлёт только ДИФФ (default_params = "diff"), а для вопроса
                -- «объясни этот код» нужен весь файл — поэтому all.
                --
                -- Ключ обязательно strategies.shared, а не interactions:
                -- config.lua:1625 делает args.strategies = nil и пересобирает
                -- interactions ИЗ defaults, из-за чего любой мой interactions
                -- затирался молча (проверено — default_params оставался diff).
                shared = {
                    editor_context = {
                        buffer = { opts = { default_params = "all", contains_code = true } },
                        selection = { opts = { contains_code = true } },
                        viewport = { opts = { contains_code = true } },
                        diagnostics = { opts = { contains_code = true } },
                    },
                },
                -- Адаптер собирает cc_adapter() выше: url ПОЛНЫЙ (до
                -- /chat/completions), модель через schema.model.default.
                -- Оба поля на верхнем уровне strategies.chat молча
                -- игнорируются — init_adapter зовёт resolve() без opts
                -- (chat/init.lua:417), и запрос уходил на api.openai.com, где
                -- OpenAI отвечает 403 unsupported_country_region_territory
                -- (в логе: set-cookie Domain=api.openai.com, cf-ray -FRA).
                -- Общие для chat и inline опции адаптера. Именно отсюда
                -- resolve() (init.lua:347) берёт параметры:
                -- extend(config.adapters.http[adapter], opts).
                --
                -- Раньше url был отдельным полем в strategies.chat и молча
                -- игнорировался — запрос уходил на api.openai.com, где OpenAI
                -- отвечает 403 unsupported_country_region_territory (в логе
                -- ответа видно set-cookie Domain=api.openai.com, cf-ray -FRA).
                chat = {
                    adapter = cc_adapter,
                },
                inline = {
                    adapter = cc_adapter,
                },
                -- Фон по умолчанию шлёт ТЕКСТ ЗАПРОСА на
                -- api.githubcopilot.com (adapter = "copilot" в config.lua:83) —
                -- он генерирует заголовок чата при каждом открытии. Ключ
                -- opencode-zen при этом не уходит, там свой GitHub OAuth-токен,
                -- но содержимое запроса уходило на серверы GitHub. Выключаем.
                background = {
                    enabled = false,
                },
            },
            slash_commands = {
                {
                    name = "ask",
                    description = "Спросить о коде",
                    -- Сигнатура пользовательских slash-команд:
                    -- { Chat, config, context, opts }, НЕ function(chat)
                    callback = function(Chat, _, _, _)
                        local bufnr = vim.api.nvim_get_current_buf()
                        local code = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
                        Chat:add_user_message({
                            content = ("Вопрос о следующем коде:\n```%s\n%s\n```\n\nОтветь на русском языке."):format(
                                vim.bo[bufnr].filetype,
                                code
                            ),
                            opts = { is_visual = true },
                        })
                        Chat:submit()
                    end,
                    opts = { index = 2, desc = "Спросить о коде" },
                },
                {
                    name = "explain",
                    description = "Объяснить код",
                    callback = function(Chat, _, _, _)
                        local bufnr = vim.api.nvim_get_current_buf()
                        local code = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
                        Chat:add_user_message({
                            content = ("Объясни следующий код:\n```%s\n%s\n```\n\nДай подробное объяснение на русском языке."):format(
                                vim.bo[bufnr].filetype,
                                code
                            ),
                            opts = { is_visual = true },
                        })
                        Chat:submit()
                    end,
                    opts = { index = 3, desc = "Объяснить код" },
                },
            },
        },
        config = function(_, opts)
            require("codecompanion").setup(opts)

            local map = vim.keymap.set
            -- Прицепить текущий файл к чату.
            --
            -- НЕ через CodeCompanionChat add: там get_context()
            -- (utils/context.lua:103) в обычном режиме возвращает ПУСТЫЕ
            -- lines — они заполняются только при визуальном выделении.
            -- Из-за этого в сообщение уходило «Here is some code from
            -- /path/file.py:» и ````python```` без единой строки кода,
            -- а модель отвечала «the provided snippet is empty».
            --
            -- Здесь читаем буфер напрямую через format_buffer_for_llm —
            -- он отдаёт полное содержимое с нумерацией строк.
            local attach_buffer = function()
                local bufnr = vim.api.nvim_get_current_buf()
                local chat = require("codecompanion").last_chat()
                if not chat then
                    chat = require("codecompanion").chat()
                    if not chat then
                        vim.notify("AI: не удалось открыть чат", vim.log.levels.ERROR)
                        return
                    end
                end
                local path = vim.api.nvim_buf_get_name(bufnr)
                local ok, buf = pcall(
                    require("codecompanion.interactions.chat.helpers").format_buffer_for_llm,
                    bufnr,
                    path,
                    { message = "Here is the content of the file I have open:" }
                )
                if not ok then
                    vim.notify("AI: не удалось прочитать файл — " .. tostring(buf), vim.log.levels.ERROR)
                    return
                end
                chat:add_message({
                    role = "user",
                    content = buf.content,
                }, {
                    _meta = {
                        source = "editor_context",
                        tag = require("codecompanion.interactions.shared.tags").BUFFER,
                    },
                    context = { id = buf.id, path = path },
                    visible = false,
                })
                vim.notify(("AI: файл %s добавлен в чат"):format(vim.fn.fnamemodify(path, ":t")),
                    vim.log.levels.INFO)
            end
            map({ "n" }, "<leader>ob", attach_buffer, { desc = "AI: прицепить текущий файл", silent = true })
            map({ "n" }, "<leader>oo", "<cmd>CodeCompanionChat ask<CR>", { desc = "AI: спросить о коде", silent = true })
            map({ "n" }, "<leader>oa", "<cmd>CodeCompanionChat<CR>", { desc = "AI: открыть чат", silent = true })
            map({ "n" }, "<leader>oo", "<cmd>CodeCompanionChat ask<CR>", { desc = "AI: спросить о коде", silent = true })
            map({ "n", "v" }, "<leader>oe", "<cmd>CodeCompanionChat explain<CR>", { desc = "AI: объяснить код", silent = true })
            map({ "n", "v" }, "<leader>og", "<cmd>CodeCompanion inline<CR>", { desc = "AI: сгенерировать по описанию", silent = true })
            map({ "n" }, "<leader>oc", "<cmd>CodeCompanion<CR>", { desc = "AI: выбор действия", silent = true })

            -- Сообщаем оба состояния. Раньше подсказка молчала при
            -- отсутствии ключа, и пользователь не понимал, почему не отвечает.
            -- Ключ лежит в файле, а не в окружении, поэтому проверяем файл.
            vim.defer_fn(function()
                local envfile = vim.fn.expand("~/.hermes/.env")
                local has_file_key = false
                if vim.fn.filereadable(envfile) == 1 then
                    local pat = string.char(94) .. "OPENCODE_ZEN_API_KEY" .. string.char(61)
                    local out = vim.fn.system({ "grep", "-c", "-e", pat, envfile })
                    local num = tonumber(vim.trim(out or "")) or 0
                    has_file_key = num > 0
                end
                local has_env_key = vim.env.OPENAI_API_KEY or vim.env.OPENROUTER_API_KEY
                    or vim.env.GEMINI_API_KEY or vim.env.ANTHROPIC_API_KEY

                if has_file_key or has_env_key then
                    vim.notify("🤖 AI: ключ найден. <Пробел>oa — чат, <Пробел>oe — объяснить, <Пробел>og — сгенерировать", vim.log.levels.INFO)
                else
                    vim.notify(
                        "🤖 AI: ключ не найден. Ожидается OPENCODE_ZEN_API_KEY в ~/.hermes/.env "
                            .. "или один из OPENAI_API_KEY / OPENROUTER_API_KEY / GEMINI_API_KEY в окружении",
                        vim.log.levels.WARN
                    )
                end
            end, 1200)
        end,
    },
})
