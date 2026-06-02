-- =============================================
-- NEOVIM ENTRY POINT
-- =============================================

-- 1. Базовые настройки (vim.opt, keymaps, диагностика)
require("config.options")

-- 2. Утилиты для Tmux, Venv и Профилирования (_G.Tmux, VenvManager)
require("config.tmux_utils")

-- 3. Плагины (Lazy.nvim и все их настройки)
require("config.plugins")

-- 4. Автокоманды (Django шаблоны, проверка инструментов при старте)
require("config.autocmds")
