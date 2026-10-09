-- =============================================
-- ХЕЛПЕРЫ ДЛЯ PYTHON-ПРОЕКТОВ
-- =============================================
--
-- То, что нужно языковому серверу, чтобы корректно видеть Python-проект:
-- поиск venv, дописывание .gitignore и создание pyrightconfig.json.
--
-- Модуль не содержит настроек плагинов — только функции, которые зовёт
-- plugins/lsp.lua. Вынесено отдельно, потому что это файловая логика,
-- которой не место в настройке плагина.
--
-- Экспортирует:
--   apply_pyright_venv(settings, root_dir) — прописать venv в настройки LSP
--   ensure_pyright_config()                — создать pyrightconfig.json
--   ensure_gitignore()                     — дополнить .gitignore

local M = {}

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

function M.apply_pyright_venv(settings, root_dir)
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

-- Дописывает в .gitignore только те строки, которых там ещё нет.
-- Ничего не перезаписывает и не дублирует: без неё каждый
-- обработчик писал бы свой блок и задваивал строки.
local function gitignore_missing(root, entries, with_headers)
    local ignore_path = root .. "/.gitignore"
    local existing = {}

    if vim.fn.filereadable(ignore_path) == 1 then
        existing = vim.fn.readfile(ignore_path)
    end

    local present = {}
    for _, line in ipairs(existing) do
        local trimmed = vim.trim(line)
        -- и прямую запись, и вариант с ведущим /
        -- (venv/ и /venv/ для git равнозначны)
        present[trimmed] = true
        present[(trimmed:gsub("^/", ""))] = true
    end

    local missing = {}
    for _, entry in ipairs(entries) do
        if not present[entry] then
            missing[#missing + 1] = entry
        end
    end

    if #missing == 0 then
        return false
    end

    -- Комментарии-заголовки имеет смысл писать только когда
    -- файла не было: дописывая их в существующий, получим
    -- второй "# Python" посреди уже разобранного файла.
    local chunk = missing
    if with_headers and #existing > 0 then
        chunk = {}
        for _, line in ipairs(missing) do
            -- отбрасываем пустые строки и комментарии
            if line ~= "" and not line:match("^#") then
                chunk[#chunk + 1] = line
            end
        end
    end

    local ok, err = pcall(function()
        local f = assert(io.open(ignore_path, "a"))
        if #existing > 0 then
            -- не приклеиваем новую строку к последней
            f:write("\n")
        end
        f:write(table.concat(chunk, "\n") .. "\n")
        f:close()
    end)
    if not ok then
        vim.notify(
            "gitignore: не удалось дописать .gitignore: "
                .. tostring(err),
            vim.log.levels.WARN
        )
        return false
    end

    return true
end

-- Стандартный набор игнорируемых файлов для Python-проектов.
-- Создаётся/дополняется только в git-репозиториях: без .git
-- файл бессмысленен и только засоряет каталог.
local GITIGNORE_STANDARD = {
    "# Окружения",
    "venv/",
    ".venv/",
    "env/",
    "venv*/",
    "ENV/",
    "env.bak/",
    "venv.bak/",
    "",
    "# Python",
    "__pycache__/",
    "*.py[cod]",
    "*$py.class",
    "*.so",
    ".Python",
    ".installed.cfg",
    "*.egg",
    "*.egg-info/",
    "",
    "# Сборка пакетов",
    "build/",
    "dist/",
    "sdist/",
    "wheels/",
    "eggs/",
    ".eggs/",
    "parts/",
    "var/",
    "lib/",
    "lib64/",
    "pip-wheel-metadata/",
    "",
    "# Тесты и покрытие",
    ".pytest_cache/",
    ".tox/",
    ".nox/",
    ".cache/",
    ".hypothesis/",
    ".coverage",
    ".coverage.*",
    "coverage.xml",
    "htmlcov/",
    "nosetests.xml",
    "",
    "# Типизация и линтеры",
    ".mypy_cache/",
    ".dmypy.json",
    "dmypy.json",
    ".pyre/",
    ".pytype/",
    ".ruff_cache/",
    "",
    "# Секреты и локальные настройки",
    ".env",
    ".env.*",
    "!.env.example",
    "",
    "# Логи и базы",
    "*.log",
    "*.sqlite3",
    "",
    "# Редакторы",
    ".idea/",
    ".vscode/",
    "*.swp",
    "*.swo",
    "*~",
    "",
    "# Системный мусор",
    ".DS_Store",
    "Thumbs.db",
    "desktop.ini",
    "",
    "# Локальная конфигурация редактора",
    "pyrightconfig.json",
}

function M.ensure_gitignore()
    -- Ищем именно корень git-репозитория
    local root = vim.fs.root(0, { ".git" })
    if not root then
        return
    end

    -- .git бывает и файлом (worktree, submodule), и каталог
    local is_repo = vim.fn.isdirectory(root .. "/.git") == 1
        or vim.fn.filereadable(root .. "/.git") == 1
    if not is_repo then
        return
    end

    gitignore_missing(root, GITIGNORE_STANDARD, true)
end

-- Pyright-langserver игнорирует настройки, переданные по LSP:
-- python.venvPath/venv/pythonPath прилетают через
-- didChangeConfiguration уже после старта, а импорты он резолвит
-- при инициализации. Измерено: с этими настройками — ошибки
-- импорта остаются, с файлом pyrightconfig.json на диске — нет.
-- Поэтому создаём файл сами, если проекта с venv ещё не было.
function M.ensure_pyright_config()
    local root = vim.fs.root(0, {
        "pyrightconfig.json",
        "pyproject.toml",
        "setup.py",
        "requirements.txt",
        "manage.py",
        ".git",
        -- venv тоже маркер: Python-проект без requirements.txt
        -- и .git иначе остался бы без конфига
        "venv",
        ".venv",
    })
    if not root then
        return
    end

    -- Не трогаем существующий конфиг
    if vim.fn.filereadable(root .. "/pyrightconfig.json") == 1 then
        return
    end

    -- pyproject.toml уважаем, только если в нём уже есть секция
    -- [tool.pyright]: без неё он не задаёт настроек pyright, иначе
    -- мы бы молча перекрыли чужую конфигурацию.
    if vim.fn.filereadable(root .. "/pyproject.toml") == 1 then
        local has_pyright_section = false
        for _, line in ipairs(vim.fn.readfile(root .. "/pyproject.toml")) do
            if line:match("^%s*%[tool%.pyright%]") then
                has_pyright_section = true
                break
            end
        end
        if has_pyright_section then
            return
        end
    end

    local venv_name = find_venv(root)
    if not venv_name then
        return
    end

    local config_path = root .. "/pyrightconfig.json"
    local body = string.format(
        '{\n  "venvPath": ".",\n  "venv": "%s",\n'
        .. '  "typeCheckingMode": "basic"\n}\n',
        venv_name
    )

    local ok, err = pcall(function()
        local f = assert(io.open(config_path, "w"))
        f:write(body)
        f:close()
    end)
    if not ok then
        vim.notify(
            "pyright: не удалось создать pyrightconfig.json: "
                .. tostring(err),
            vim.log.levels.WARN
        )
        return
    end

    -- Файл машинный и одинаковый в каждом проекте, поэтому
    -- сразу прячем его от git, чтобы не светился в git status
    -- и случайно не попал в коммит.
    gitignore_missing(root, { "pyrightconfig.json" })
end

return M
