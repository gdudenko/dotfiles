-- =============================================
-- ПОДСВЕТКА СИНТАКСИСА (TREESITTER)
-- =============================================
--
-- Ветка main у nvim-treesitter — полностью несовместимый rewrite
-- («treat as a different plugin»), поэтому способ установки парсеров
-- зафиксирован. Подробности — в комментариях внутри.
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            local ts = require("nvim-treesitter")

            -- setup без аргументов использует значения по умолчанию,
            -- включая install_dir = stdpath('data')/site. Явно задаём
            -- install_dir, чтобы путь не «уехал» при смене stdpath.
            ts.setup({
                install_dir = vim.fn.stdpath("data") .. "/site",
            })

            -- Парсеры. Установка асинхронная, поэтому для запуска при
            -- старте (и для :checkhealth) ждём завершения.
            --
            -- yaml раньше был исключён: ikatyang/tree-sitter-yaml давал
            -- ABI 14, а nvim 0.12 требует 15. На main парсеры ставятся
            -- из репозитория nvim-treesitter, а не ikatyang, поэтому
            -- ограничение снято — yaml вернули. Проверено после установки:
            -- все 12 парсеров грузятся через vim.treesitter.language.add,
            -- и :checkhealth nvim-treesitter показывает по ним галочки
            -- в колонках H (highlights), L (locals), F (folds),
            -- I (indents) и J (injections).
            --
            -- markdown и markdown_inline обязательны: ими разбираются
            -- сообщения и буфер чата (ts_parse_buffer в chat/context.lua).
            ts.install({
                "python", "lua", "bash", "javascript", "typescript",
                "html", "css", "markdown", "markdown_inline",
                "json", "toml", "yaml",
            }):wait(300000)

            -- Подсветка и отступы. На master включались ключами
            -- highlight.enable и indent.enable, теперь их надо включать
            -- самому: подсветку — через vim.treesitter.start(),
            -- отступы — через indentexpr из плагина.
            --
            -- Без indentexpr отступы после обновления стали бы обычными
            -- (cindent/autoindent), то есть регрессией относительно
            -- того, что было на master. Формально отступы помечены в
            -- README как experimental, но на master они работали, и
            -- возвращать к старому поведению незачем.
            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("RuTreesitter", {
                    clear = true,
                }),
                callback = function(ev)
                    -- Не у всех filetypes есть грамматика: NvimTree,
                    -- help, prompt, NvimNotify и т.п. Внутри
                    -- vim.treesitter.start() стоит assert(get_parser()),
                    -- который на отсутствии парсера роняет всё событие
                    -- (ошибка «Parser could not be created»). Поэтому
                    -- сначала спрашиваем у language.add(), есть ли
                    -- парсер, и только потом стартуем подсветку.
                    --
                    -- indentexpr ставится под тем же условием: он зовёт
                    -- nvim-treesitter.indent.get_indent, который без
                    -- разобранного дерева тоже падает.
                    local ft = vim.bo[ev.buf].filetype
                    local lang = ft ~= ""
                        and vim.treesitter.language.get_lang(ft)
                    if not lang or not vim.treesitter.language.add(lang) then
                        return
                    end
                    vim.treesitter.start(ev.buf, lang)
                    vim.bo[ev.buf].indentexpr =
                        "v:lua.require'nvim-treesitter'.indentexpr()"
                end,
            })
        end,
    },
}
