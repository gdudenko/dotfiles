-- =============================================
-- ПЛАГИНЫ (Lazy.nvim)
-- =============================================
--
-- Установка и настройка плагинов. Сами настройки разложены по темам
-- в lua/plugins/ — этот файл только собирает их в один список:
--
--   theme.lua        цвета (catppuccin) и подсветка шаблонов Django
--   nvim_tree.lua    дерево файлов + синхронизация cd с tmux
--   statusline.lua   хлебные крошки (navic) и строка состояния
--   editing.lua      парные скобки, закрытие тегов, линии отступов
--   treesitter.lua   грамматики и подсветка синтаксиса
--   telescope.lua    поиск по файлам и символам
--   aerial.lua       outline структуры файла
--   lsp.lua          языковые серверы и меню автодополнения
--   python_project.lua  хелперы venv/.gitignore/pyrightconfig (не плагин)
--   formatting.lua   форматирование (conform) и линтинг
--   debugging.lua    отладка (dap) и тесты (pytest)
--   git.lua          gitsigns, neogit, diffview
--   utilities.lua    which-key, surround, todo-comments, trouble, базы
--   ai.lua           supermaven и codecompanion
--
-- Порядок в списке важен только для читаемости: lazy.nvim сам разбирает
-- граф зависимостей по полю dependencies.
--
-- Добавляя плагин, клади его в тематический модуль, а не сюда.

-- =============================================
-- УСТАНОВКА LAZY.NVIM
-- =============================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- =============================================
-- СБОРКА СПЕЦИФИКАЦИЙ
-- =============================================

local specs = {}

-- ai.lua отдаёт не список, а модуль с полем specs: там же лежат
-- функция загрузки ключа и сборщик адаптера.
for _, module in ipairs({
    "theme",
    "nvim_tree",
    "statusline",
    "editing",
    "treesitter",
    "telescope",
    "aerial",
    "lsp",
    "formatting",
    "debugging",
    "git",
    "utilities",
}) do
    vim.list_extend(specs, require("plugins." .. module))
end

vim.list_extend(specs, require("plugins.ai").specs)

require("lazy").setup(specs)