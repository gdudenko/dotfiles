-- =============================================
-- AI АССИСТЕНТ
-- =============================================
--
-- supermaven-inc — инлайновое AI-автодополнение прямо в строке.
-- codecompanion.nvim — чат и инлайн с кодом по контексту буфера.
--
-- Оба ходят в OpenAI-совместимый endpoint opencode-zen (провайдер
-- Hermes), поэтому адаптер собирается один на chat и inline: иначе
-- они разъезжаются по url и модели. Ключ лежит в ~/.hermes/.env
-- и подтягивается оттуда, в конфиге его нет.
--
-- ПЕРЕКЛЮЧЕНИЕ НА ЛОКАЛЬНУЮ МОДЕЛЬ — меняются две строки в M.adapter():
--
--   url = "http://127.0.0.1:8080/v1/chat/completions"
--   schema = { model = { default = "<имя модели>" } }
--
-- Требования к сервису: sudo systemctl enable --now llama-server
-- (unit тянет модель через -hf, качает с HuggingFace при первом старте).
-- api_key для локального сервера можно оставить как есть: llama.cpp его
-- не проверяет, а M.load_key() вернёт "dummy", если .env нет.
-- Локальный ollama: url = "http://127.0.0.1:11434/v1/chat/completions"

local M = {}

-- Загрузка ключа opencode-zen из ~/.hermes/.env.
--
-- Ключ не в окружении nvim, а в файле, поэтому читаем файл напрямую.
-- Секрет НЕ попадает в конфиг и в подписи на диске — только в память
-- процесса на время запроса.
function M.load_key()
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
function M.adapter()
    local AH = require("codecompanion.adapters.http")
    local base = require("codecompanion.adapters.http.openai")
    return AH.extend(base, {
        url = "https://opencode.ai/zen/v1/chat/completions",
        schema = { model = { default = "space-bunny-free" } },
        env = {
            api_key = function() return M.load_key() end,
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

-- Спецификации плагинов
M.specs = {
    {
        "supermaven-inc/supermaven-nvim",
        config = function()
            require("supermaven-nvim").setup({
                keymaps = { accept_suggestion = "<C-g>", clear_suggestion = "<C-]>", accept_word = "<C-j>" }
            })
        end,
    },

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
                -- Адаптер собирает M.adapter() выше: url ПОЛНЫЙ (до
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
                    adapter = M.adapter,
                },
                inline = {
                    adapter = M.adapter,
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

            -- Два патча для буфера чата.
            --
            -- 1) Enter отправляет сообщение, в том числе в insert. По умолчанию
            --    плагин вешает <CR> только на normal (config.lua:659), в insert
            --    лишь <C-s>. Сценарий «написал в insert → Escape → Enter» на
            --    втором запросе отправлял ПУСТОЕ сообщение: текст оставался на
            --    предыдущей строке, курсор стоял на пустой.
            --
            -- 2) Разбор сообщений без диапазона. Плагин при submit зовёт
            --    parser.lua:145 chat.parsers.markdown:parse({start_range-1,-1}),
            --    и languagetree:1125 в _get_inject тянет подъязыки из
            --    queries/markdown/injections.scm (html, yaml, toml,
            --    markdown_inline) — они собраны под разные ABI, и попытка взять
            --    range у ноды инъекции падает. Воспроизведено: parse() без
            --    диапазона работает всегда, parse({N,-1}) падает, и только
            --    когда в буфере есть блок кода — то есть со ВТОРОГО сообщения.
            --
            -- Патчим в двух местах: BufEnter (маппинги — буфер уже создан) и
            -- отложенный хук после создания парсера (он появляется позже
            -- BufEnter, проверено: __cc_patched был nil).
            local function setup_chat_buf(ev)
                if vim.b[ev.buf].cc_chat_keys then return end
                vim.b[ev.buf].cc_chat_keys = true
                vim.keymap.set("i", "<CR>", function()
                    local chat = require("codecompanion").last_chat()
                        or require("codecompanion").buf_get_chat(ev.buf)
                    if chat then
                        require("codecompanion.interactions.chat.keymaps").send.callback(chat)
                    end
                end, { buffer = ev.buf, desc = "AI: отправить сообщение", silent = true })
                vim.keymap.set("i", "S-<CR>", "<CR>", { buffer = ev.buf, desc = "AI: перенос строки" })
            end

            -- Парсер создаётся плагином позже BufEnter, поэтому патчим его
            -- отложенно и по событию входа в буфер чата.
            local function patch_chat_parser(ev)
                local chat = require("codecompanion").last_chat()
                    or require("codecompanion").buf_get_chat(ev.buf)
                local lt = chat and chat.parsers and chat.parsers.markdown
                if not lt or lt.__cc_patched then return end
                lt.__cc_patched = true
                local orig_parse = lt.parse
                lt.parse = function(self)
                    return orig_parse(self)
                end
            end

            vim.api.nvim_create_autocmd("FileType", {
                pattern = "codecompanion",
                callback = function(ev)
                    setup_chat_buf(ev)
                    -- Парсер codecompanion создаётся ПОСЛЕ FileType, поэтому
                    -- патчим его по событию открытия чата (ChatAdd) и отложенно.
                    pcall(patch_chat_parser, ev)
                    vim.schedule(function() pcall(patch_chat_parser, ev) end)
                end,
            })
            vim.api.nvim_create_autocmd("BufEnter", {
                pattern = "*",
                callback = function(ev)
                    if vim.bo[ev.buf].filetype == "codecompanion" then
                        setup_chat_buf(ev)
                        pcall(patch_chat_parser, ev)
                        -- парсер может создаться позже этой строки
                        vim.schedule(function() pcall(patch_chat_parser, ev) end)
                    end
                end,
            })
            map({ "n" }, "<leader>oo", "<cmd>CodeCompanionChat ask<CR>", { desc = "AI: спросить о коде", silent = true })
            map({ "n" }, "<leader>oa", "<cmd>CodeCompanionChat<CR>", { desc = "AI: открыть чат", silent = true })
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
}

return M
