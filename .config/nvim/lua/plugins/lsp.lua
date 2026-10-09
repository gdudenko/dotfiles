-- =============================================
-- ЯЗЫКОВЫЕ СЕРВЕРЫ И АВТОДОПОЛНЕНИЕ (nvim-lspconfig + nvim-cmp)
-- =============================================
--
-- Mason ставит серверы, nvim-lspconfig настраивает pyright, lua_ls,
-- bashls, ts_ls и html, nvim-cmp отвечает за меню автодополнения.
--
-- Два нестандартных решения, оба описаны в комментариях внутри:
--   * подсказки LSP переводятся на русский (один словарь на hover и на
--     метки в меню автодополнения);
--   * настройки venv для pyright пишутся в pyrightconfig.json на диске,
--     а не передаются через LSP — иначе импорты не резолвятся.
--
-- Возвращает список спецификаций для lazy.nvim.

return {
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

        -- =============================================
        -- ПЕРЕВОД ПОДСКАЗОК LSP НА РУССКИЙ
        -- =============================================
        --
        -- Метки приходят из двух РАЗНЫХ мест, и это важно:
        --
        -- 1) Метка справа в меню автодополнения ("Method", "Snippet")
        --    — это nvim-cmp, а не pyright. Таблица
        --    lsp.CompletionItemKind лежит в его lua/cmp/types/lsp.lua
        --    и переводится через formatting.format.
        --
        -- 2) Метка в подсказке по K ("(method) def capitalize() -> str")
        --    — это текст, который присылает сам pyright. Никакой
        --    настройкой он не меняется, поэтому подменяем обработчик
        --    vim.lsp.buf.hover на свой.
        --
        -- Словарь ОДИН на оба места. Ключи в нижнем регистре, потому
        -- что nvim-cmp отдаёт метки с большой буквы (Method, Snippet),
        -- а pyright — с маленькой (method). Перед поиском ключ
        -- приводится к нижнему регистру, поэтому "Method" и "method"
        -- находят одно и то же.
        --
        -- Первые 25 — это полный список lsp.CompletionItemKind из
        -- nvim-cmp, ни одна не пропущена (был пропущен Snippet).
        -- Последние 6 — метки самого pyright, которых в LSP нет.
        -- Все значения с большой буквы: метка в интерфейсе должна
        -- выглядеть словом, а не частью предложения.
        local lsp_kinds_ru = {
            ["text"] = "Текст",
            ["method"] = "Метод",
            ["function"] = "Функция",
            ["constructor"] = "Конструктор",
            ["field"] = "Поле",
            ["variable"] = "Переменная",
            ["class"] = "Класс",
            ["interface"] = "Интерфейс",
            ["module"] = "Модуль",
            ["property"] = "Свойство",
            ["unit"] = "Единица",
            ["value"] = "Значение",
            ["enum"] = "Перечисление",
            ["keyword"] = "Ключевое слово",
            ["snippet"] = "Фрагмент",
            ["color"] = "Цвет",
            ["file"] = "Файл",
            ["reference"] = "Ссылка",
            ["folder"] = "Папка",
            ["enummember"] = "Элемент перечисления",
            ["constant"] = "Константа",
            ["struct"] = "Структура",
            ["event"] = "Событие",
            ["operator"] = "Оператор",
            ["typeparameter"] = "Параметр типа",
            ["enum member"] = "Элемент перечисления",
            ["type parameter"] = "Параметр типа",
            -- метки pyright, которых нет в LSP CompletionItemKind
            ["type"] = "Тип",
            ["parameter"] = "Параметр",
            ["type alias"] = "Псевдоним типа",
            ["type variable"] = "Переменная типа",
            ["param spec"] = "Парама спецификации",
            ["symbol"] = "Символ",
        }

        -- Меняет "(method) def foo()" на "(метод) def foo()".
        --
        -- Шаблон ловит только скобки из букв и пробелов, поэтому
        -- обычный код не портится: "x = (a + b)" и "tuple (int, str)"
        -- остаются как есть — там запятая или плюс, а не слово.
        local function translate_hover_lines(lines)
            local result = {}
            for _, line in ipairs(lines) do
                result[#result + 1] = line:gsub(
                    "%((%a[%a ]-)%)",
                    function(word)
                        local ru = lsp_kinds_ru[word:lower()]
                        if ru then
                            return "(" .. ru .. ")"
                        end
                        return nil
                    end
                )
            end
            return result
        end

        -- Свой hover вместо vim.lsp.buf.hover: та же логика nvim
        -- (0.12), но с переводом меток. Штатный buf.hover в этой
        -- версии принимает только config, обработчик туда не
        -- передать, поэтому пишем свой.
        local hover_ns = vim.api.nvim_create_namespace("ru_lsp_hover")

        local function hover_ru()
            local bufnr = vim.api.nvim_get_current_buf()
            local clients = vim.lsp.get_clients({ bufnr = bufnr })
            if #clients == 0 then
                vim.notify("Нет языкового сервера для этого файла")
                return
            end

            local params = vim.lsp.util.make_position_params(
                0, clients[1].offset_encoding
            )

            vim.lsp.buf_request_all(
                bufnr, "textDocument/hover", params,
                function(results, ctx)
                    local contents = {}
                    local syntax = "markdown"
                    local found = 0

                    -- В nvim 0.12 results — это таблица
                    -- { [client_id] = { result = ..., context = ... } }.
                    -- Поля client_id и err внутри значения НЕТ, id лежит
                    -- в ключе. Раньше читался resp.client_id (nil), и
                    -- подсветка символа не срабатывала.
                    for client_id, resp in pairs(results) do
                        local result = resp.result
                        if result and result.contents then
                            found = found + 1
                            local client = vim.lsp.get_client_by_id(client_id)
                            if found > 1 and client then
                                contents[#contents + 1] = "# " .. client.name
                            end
                            if type(result.contents) == "table"
                                and result.contents.kind == "plaintext"
                            then
                                if found == 1 then
                                    syntax = "plaintext"
                                end
                                if found > 1 then
                                    contents[#contents + 1] = "```"
                                end
                                vim.list_extend(contents, vim.split(
                                    result.contents.value or "", "\n",
                                    { trimempty = true }))
                                if found > 1 then
                                    contents[#contents + 1] = "```"
                                end
                            else
                                vim.list_extend(contents,
                                    vim.lsp.util.convert_input_to_markdown_lines(
                                        result.contents))
                            end

                            -- Подсветка символа, как делает nvim
                            local range = result.range
                            if range and client then
                                local s = range.start
                                local e = range["end"]
                                vim.hl.range(bufnr, hover_ns,
                                    "LspReferenceTarget",
                                    { s.line, s.character },
                                    { e.line, e.character },
                                    { priority = vim.hl.priorities.user })
                            end
                        end
                    end

                    if found == 0 then
                        vim.notify("Нет информации", vim.log.levels.INFO)
                        return
                    end

                    local _, winid = vim.lsp.util.open_floating_preview(
                        translate_hover_lines(contents), syntax,
                        { focus_id = "textDocument/hover" })

                    vim.api.nvim_create_autocmd("WinClosed", {
                        pattern = tostring(winid),
                        once = true,
                        callback = function()
                            vim.api.nvim_buf_clear_namespace(
                                ctx.bufnr, hover_ns, 0, -1)
                            return true
                        end,
                    })
                end
            )
        end

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
            formatting = {
                -- Метка справа в меню подсказок: Method -> Метод.
                -- Ключ приводим к нижнему регистру: nvim-cmp отдаёт
                -- метку с большой буквы, а в словаре она с маленькой.
                -- Подсветка при этом не теряется, она берётся из
                -- CmpItemKind<Kind> по номеру kind, а не по тексту.
                format = function(_, vim_item)
                    local ru = lsp_kinds_ru[(vim_item.kind or ""):lower()]
                    if ru then
                        vim_item.kind = ru
                    end
                    return vim_item
                end,
            },
        })

        vim.lsp.config["*"] = {
            capabilities = capabilities,
        }

        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("UserLspConfig", {}),
            callback = function(ev)
                local opts = { buffer = ev.buf, noremap = true, silent = true }

                vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                vim.keymap.set("n", "K", hover_ru, opts)
                vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
                vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
                vim.keymap.set("n", "<leader>f", function()
                    vim.lsp.buf.format({ async = true })
                end, opts)
            end,
        })

        -- Поиск venv, дописывание .gitignore и создание pyrightconfig.json
        -- живут в plugins/python_project.lua.
        local py = require("plugins.python_project")

        vim.api.nvim_create_autocmd("VimEnter", {
            callback = py.ensure_pyright_config,
        })
        vim.api.nvim_create_autocmd("VimEnter", {
            callback = py.ensure_gitignore,
        })
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
                "setup.cfg",
                "requirements.txt",
                "Pipfile",
                "poetry.lock",
                "manage.py",
                -- Scrapy: scrapy.cfg — единственный маркер проекта,
                -- созданный startproject. Без него pyright стартует
                -- с root_dir = nil, не видит ни venv, ни
                -- pyrightconfig.json, и ругается на неиспользуемые
                -- параметры и неразрешённые импорты.
                "scrapy.cfg",
                ".git",
                -- venv как последний маркер: у проекта может не быть
                -- ни одного из перечисленных выше файлов, но
                -- виртуальное окружение почти всегда есть
                "venv",
                ".venv",
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
                py.apply_pyright_venv(config.settings, root_dir)
            end,

            on_init = function(client)
                if not client.config.settings then
                    client.config.settings = vim.deepcopy(pyright_settings)
                end

                local root_dir = client.root_dir or client.config.root_dir
                py.apply_pyright_venv(client.config.settings, root_dir)

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
}
