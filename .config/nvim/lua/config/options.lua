-- =============================================
-- БАЗОВЫЕ НАСТРОЙКИ VIM
-- =============================================
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

-- =============================================
-- НАСТРОЙКА ДИАГНОСТИКИ
-- =============================================
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

-- =============================================
-- БАЗОВЫЕ МАППИНГИ
-- =============================================
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

-- Диагностика
map('n', '<leader>e', '<cmd>lua vim.diagnostic.open_float()<CR>', { desc = "Показать диагностику" })
map('n', '<leader>ql', '<cmd>lua vim.diagnostic.setloclist()<CR>', { desc = "Ошибки в loclist" })
map('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', { desc = "Пред. диагностика" })
map('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', { desc = "След. диагностика" })
map('n', '<leader>dd', '<cmd>lua vim.diagnostic.hide()<CR>', { desc = "Скрыть диагностику" })
map('n', '<leader>da', '<cmd>lua vim.diagnostic.show()<CR>', { desc = "Показать диагностику" })
