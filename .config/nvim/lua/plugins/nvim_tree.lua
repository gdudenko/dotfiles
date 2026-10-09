-- =============================================
-- ДЕРЕВО ФАЙЛОВ (NVIM-TREE)
-- =============================================
--
-- Кроме показа дерева отправляет cd в соседнюю панель tmux по <leader>cd:
-- переход в каталог в редакторе и в терминале не должен расходиться.
--
-- -- Возвращает список спецификаций для lazy.nvim.

return {
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            vim.g.loaded_netrw = 1
            vim.g.loaded_netrwPlugin = 1
            local api = require("nvim-tree.api")

            local function send_cd_to_tmux(path)
                if not path then return end
                local safe_path = path:gsub("'", "'\\''")
                local tmux_cmd = string.format("tmux send-keys -t 2 'cd %s && pwd' Enter", safe_path)
                os.execute(tmux_cmd)
                vim.notify("📁 Tmux: перешел в " .. path, vim.log.levels.INFO)
            end

            require("nvim-tree").setup({
                view = { width = 35, number = false, relativenumber = false },
                renderer = {
                    icons = {
                        show = { file = true, folder = true, folder_arrow = true, git = true },
                        glyphs = { default = "󰈔", symlink = "󰈙", folder = { arrow_closed = "", arrow_open = "", default = "", open = "", empty = "", empty_open = "", symlink = "" } },
                    },
                    indent_markers = { enable = true, inline_arrows = true, icons = { corner = "└", edge = "│", item = "│", none = " " } },
                },
                filters = { dotfiles = false, custom = { "^\\.git$" } },
                git = { enable = true, ignore = false },
                update_focused_file = { enable = true, update_cwd = true },
                actions = {
                    open_file = { quit_on_open = false, window_picker = { enable = false } },
                    change_dir = { enable = true, global = true },
                },
                on_attach = function(bufnr)
                    local function opts(desc) return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true } end

                    -- НАВИГАЦИЯ И ОТКРЫТИЕ
                    vim.keymap.set("n", "<CR>", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "o", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "<2-LeftMouse>", api.node.open.edit, opts("Open"))
                    vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
                    vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))

                    -- ФАЙЛОВЫЕ ОПЕРАЦИИ
                    vim.keymap.set("n", "a", api.fs.create, opts("Create File/Dir"))
                    vim.keymap.set("n", "d", api.fs.remove, opts("Delete"))
                    vim.keymap.set("n", "r", api.fs.rename, opts("Rename"))
                    vim.keymap.set("n", "e", api.fs.rename_basename, opts("Rename Basename"))
                    vim.keymap.set("n", "c", api.fs.copy.node, opts("Copy"))
                    vim.keymap.set("n", "p", api.fs.paste, opts("Paste"))
                    vim.keymap.set("n", "x", api.fs.cut, opts("Cut"))
                    vim.keymap.set("n", "y", api.fs.copy.filename, opts("Copy Name"))

                    -- СИНХРОНИЗАЦИЯ С TMUX
                    vim.keymap.set("n", "C", function()
                        local node = api.tree.get_node_under_cursor()
                        if node and node.type == "directory" then
                            api.tree.change_root_to_node(node)
                            send_cd_to_tmux(node.absolute_path)
                        end
                    end, opts("Change Root & Sync Tmux"))
                end,
            })
            vim.keymap.set('n', '<leader>nt', api.tree.toggle, { desc = "Файловый менеджер" })
        end,
    },
}
