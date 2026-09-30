-- =============================================
-- АВТОКОМАНДЫ
-- =============================================

-- Определение Django шаблонов
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*/templates/*.html", "*/templates/*.django" },
    callback = function() vim.bo.filetype = "htmldjango" end,
})

-- Настройка отступов для Django и Python
vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile", "FileType" }, {
    pattern = { "*/templates/*.html", "*.htmldjango", "htmldjango" },
    callback = function()
        vim.bo.tabstop = 2
        vim.bo.shiftwidth = 2
        vim.bo.softtabstop = 2
        vim.bo.expandtab = true
    end,
    desc = "Установить отступ 2 пробела для Django шаблонов",
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

-- ❌ БЫЛО: autocmd VimEnter сам вызывал VenvManager.select_venv() через 1 сек
--    после старта — вопрос/активация срабатывали без нажатия np. УБРАЛИ.
--
-- Эвристика «это Python-проект»: есть requirements.txt / pyproject.toml /
-- manage.py / .py-файлы в корне. Без неё подсказка всплывала бы всюду.
-- Объявлена ДО autocmd, чтобы не зависеть от порядка выполнения.
local function looks_like_python_project()
    local markers = {
        "requirements.txt", "pyproject.toml", "setup.py", "Pipfile",
        "manage.py", "environment.yml", "setup.cfg",
    }
    for _, m in ipairs(markers) do
        if vim.fn.filereadable(vim.fn.getcwd() .. "/" .. m) == 1 then
            return true
        end
    end
    local py = vim.fn.glob(vim.fn.getcwd() .. "/*.py", false, true)
    return #py > 0
end

-- ✅ Подсказка при старте. Ничего не активирует и не создаёт молча —
--    только сообщает, что делать дальше.
--
-- Раньше здесь стояло `if found then ... end`, из-за чего при ОТСУТСТВИИ venv
-- не происходило вообще ничего: пользователь не получал никакого сигнала,
-- хотя диалог создания через <Пробел>np существует и работает. Теперь
-- сообщаем оба случая.
vim.api.nvim_create_autocmd("VimEnter", {
    pattern = "*",
    callback = function()
        vim.defer_fn(function()
            local ok, mod = pcall(require, "config.tmux_utils")
            if not ok then return end
            local found = mod.VenvManager.find_venv()
            if found then
                vim.notify(
                    ("🐍 Найден venv: %s — нажмите <Пробел>np для активации"):format(
                        vim.fn.fnamemodify(found, ":t")
                    ),
                    vim.log.levels.INFO
                )
            else
                -- Только если это выглядит Python-проектом, чтобы не
                -- доставать подсказками при открытии любой папки.
                if looks_like_python_project() then
                    vim.notify(
                        "🐍 Виртуальное окружение не найдено — "
                            .. "нажмите <Пробел>np, чтобы создать его",
                        vim.log.levels.WARN
                    )
                end
            end
        end, 1000)
    end,
    desc = "Подсказка о venv: найден или требует создания (без автоактивации)",
})
-- Если подсказка не нужна — удалите весь блок VimEnter выше.

-- Информация о горячих клавишах при старте
vim.defer_fn(function()
    print(
    "🚀 NEOVIM + TMUX ИНТЕГРАЦИЯ | <ПРОБЕЛ>nt - Дерево | <ПРОБЕЛ>rr - Запуск | <ПРОБЕЛ>dr - Django Server | <Пробел>np - Venv")
end, 200)
