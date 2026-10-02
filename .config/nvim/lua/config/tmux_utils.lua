-- =============================================
-- TMUX ИНТЕГРАЦИЯ И УТИЛИТЫ
-- =============================================
_G.Tmux = {}

Tmux.send_command = function(command, pane_target)
    local pane = pane_target or "2" -- По умолчанию терминальная панель (2)
    -- Экранируем кавычки, чтобы пути с пробелами не ломали tmux/bash
    local safe_command = command:gsub('"', '\\"')
    local cmd = string.format('tmux send-keys -t %s "%s" Enter', pane, safe_command)
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
        if vim.bo.filetype == 'htmldjango' then
            vim.notify("🔄 Django шаблон, запуск сервера", vim.log.levels.INFO)
            Tmux.send_command('python manage.py runserver')
            return
        else
            vim.notify("🌐 HTML файл, откройте в браузере", vim.log.levels.INFO)
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

-- =============================================
-- МЕНЕДЖЕР VENV
-- =============================================
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
        local venv_name = vim.fn.fnamemodify(found_venv, ":t")
        -- vim.fn.confirm работает СИНХРОННО и блокирует выполнение до ответа
        local choice = vim.fn.confirm(
            "🔍 Обнаружено виртуальное окружение: " .. venv_name .. "\nИспользовать его для этого проекта?",
            "&Да\n&Нет",
            1 -- 1 - курсор по умолчанию на "Да"
        )

        if choice == 1 then -- Пользователь выбрал "Да"
            Tmux.send_command('source "' .. found_venv .. '/bin/activate"')
            vim.notify("✅ Виртуальное окружение активировано: " .. venv_name, vim.log.levels.INFO)
        else
            vim.notify("❌ Активация отменена", vim.log.levels.INFO)
        end
    else
        local choice = vim.fn.confirm(
            "Виртуальное окружение не найдено.\nСоздать новое?",
            "&Создать venv\n&Пропустить",
            1
        )

        if choice == 1 then -- Пользователь выбрал "Создать venv"
            -- vim.fn.input тоже синхронный
            local venv_name = vim.fn.input("Имя окружения (по умолчанию venv): ", "venv")
            if venv_name == "" then venv_name = "venv" end

            local create_cmd = string.format('python3 -m venv "%s"', venv_name)
            Tmux.send_command(create_cmd)

            -- Раньше здесь стоял vim.defer_fn на 1500 мс, который вслепую
            -- слал source. Это не работало: создание venv занимает ~2700 мс,
            -- поэтому activate уезжал в терминал ДО появления папки и падал.
            -- Вместо слепой задержки ждём внутри терминала и активируем
            -- только когда venv реально готов.
            local wait_and_activate = string.format(
                [[while [ ! -f "%1$s/bin/activate" ]; do sleep 0.3; done; source "%1$s/bin/activate" && echo "✅ venv %1$s активирован" || echo "❌ не удалось активировать %1$s"]],
                venv_name
            )
            vim.defer_fn(function()
                Tmux.send_command(wait_and_activate)
                vim.notify(
                    ("⏳ Ожидание готовности venv: %s — активация произойдёт в терминале"):format(venv_name),
                    vim.log.levels.INFO
                )
            end, 300)
        else
            vim.notify("❌ Создание отменено", vim.log.levels.INFO)
        end
    end
end

-- Маппинги для Venv и Tmux
local map = vim.keymap.set
-- Добавил <leader>np (возможно, вы имели в виду именно его)
map('n', '<leader>np', VenvManager.select_venv, { desc = 'Python: создать или выбрать venv' })
map('n', '<leader>pv', VenvManager.select_venv, { desc = 'Python: создать или выбрать venv' })
map('n', '<leader>tv', VenvManager.select_venv, { desc = "Управление виртуальным окружением" })
map('n', '<leader>tc', function()
    local command = vim.fn.input("Команда в tmux: ")
    if command ~= "" then Tmux.send_command(command) end
end, { desc = "Выполнить команду в tmux" })
map('n', '<leader>rr', Tmux.run_current_file, { desc = "Запустить текущий файл в tmux" })

-- DJANGO TMUX КОМАНДЫ
map('n', '<leader>dm', function() Tmux.send_command('python manage.py migrate') end, { desc = "Django migrate" })
map('n', '<leader>dmm', function() Tmux.send_command('python manage.py makemigrations') end,
    { desc = "Django makemigrations" })
map('n', '<leader>dr', function() Tmux.send_command('python manage.py runserver') end, { desc = "Django runserver" })
map('n', '<leader>dtc', function() Tmux.send_command('python manage.py test') end, { desc = "Django тесты" })

-- =============================================
-- ПРОФИЛИРОВАНИЕ PYTHON
-- =============================================
local PythonProfiler = {}

PythonProfiler.simple_profile = function()
    if vim.bo.filetype ~= 'python' then return vim.notify("Это не Python", vim.log.levels.WARN) end
    local current_file = vim.fn.expand('%:p')
    local profile_cmd = string.format('python -m cProfile -o profile.stats "%s"', current_file)
    Tmux.send_command('clear')
    Tmux.send_command(profile_cmd)
    vim.notify("📊 Запущено профилирование файла...", vim.log.levels.INFO)
    vim.defer_fn(function()
        Tmux.send_command(
            'python -c "import pstats; p = pstats.Stats(\'profile.stats\'); p.strip_dirs().sort_stats(\'cumulative\').print_stats(20)"')
    end, 500)
end

map('n', '<leader>pp', function()
    if vim.bo.filetype ~= 'python' then return end
    local current_file = vim.fn.expand('%:p')
    Tmux.send_command('clear')
    Tmux.send_command(string.format('python -m cProfile "%s"', current_file))
end, { desc = "Профилировать Python файл (cProfile)" })

map('n', '<leader>pm', function()
    if vim.bo.filetype ~= 'python' then return end
    local current_file = vim.fn.expand('%:p')
    Tmux.send_command('clear')
    Tmux.send_command(string.format('python -m memory_profiler "%s"', current_file))
    vim.notify("🧠 Запущено профилирование памяти...", vim.log.levels.INFO)
end, { desc = "Профилирование памяти Python" })

map('n', '<leader>ps', PythonProfiler.simple_profile, { desc = "Быстрое профилирование Python" })

return {
    VenvManager = VenvManager,
    PythonProfiler = PythonProfiler,
}
