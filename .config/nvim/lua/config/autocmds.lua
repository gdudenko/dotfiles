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
  desc = "Установить отступ 2 пробела для Django шаблонов"
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

-- Предложение активировать venv при входе в проект
vim.api.nvim_create_autocmd({ "VimEnter" }, {
  pattern = "*",
  callback = function()
    vim.defer_fn(function()
      if vim.fn.isdirectory(vim.fn.getcwd()) == 1 then
        -- Проверяем, есть ли venv в проекте
        local venv_exists = vim.fn.isdirectory(vim.fn.getcwd() .. "/venv") == 1 
                            or vim.fn.isdirectory(vim.fn.getcwd() .. "/.venv") == 1
        if venv_exists then
          require("config.tmux_utils").VenvManager.select_venv()
        end
      end
    end, 1000)
  end,
})

-- Информация о горячих клавишах при старте
vim.defer_fn(function()
  print("🚀 NEOVIM + TMUX ИНТЕГРАЦИЯ | <ПРОБЕЛ>nt - Дерево | <ПРОБЕЛ>rr - Запуск | <ПРОБЕЛ>dr - Django Server")
end, 200)
