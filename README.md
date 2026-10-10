# 🔧 Dotfiles: Neovim 0.12 + tmux + Zsh

Рабочая среда под Python/Django/Scrapy с упором на Neovim, терминал и AI.

Три части, которые живут вместе:

- **Neovim** как редактор и вся IDE (LSP, отладка, тесты, git, AI).
- **tmux** как терминал и панель запуска: `create_panes.sh` поднимает терминал
  внизу и nvim вверху, активирует venv, если нашла.
- **Zsh** как вход в проект: `np [папка]` создаёт или переиспользует
  tmux-сессию с именем проекта.

Файлы раскладываются симлинками из `~/.dotfiles` в `~/.config` и `~`, так что
правки в репозитории сразу видны в редакторе.

## 📦 Требования

| Что | Версия | Зачем |
|-----|--------|-------|
| Neovim | **0.12+** | конфиг использует нативный `vim.lsp.config` / `vim.lsp.enable`; nvim-treesitter ветки `main` требует ABI 15, то есть 0.12 |
| tmux | 3.0+ | base-index 1, `renumber-windows`, true color |
| Zsh | любой | + Oh My Zsh |
| Powerlevel10k | свежий | тема из `custom/themes/powerlevel10k`, конфиг в `~/.p10k.zsh` |
| Python | 3.11+ | venv, LSP, профилирование |
| Node.js | 20+ | `ts_ls`, `html` LSP, `prettier` |

Проверено на: Neovim 0.12.5, tmux 3.7c, Python 3.14, Arch.

### Системные пакеты

```bash
sudo pacman -S neovim tmux zsh git python python-pip nodejs npm \
    ripgrep fd fzf \
    fastfetch lsd bat zoxide \
    xclip wl-clipboard
```

`fastfetch` запускается первой строкой `.zshrc`, без него будет ошибка при
открытии терминала. `lsd` и `bat` вызваны алиасами `ls` и `cat`.

### Oh My Zsh

Нужны плагины из списка в `.zshrc`: `git`, `zsh-syntax-highlighting`,
`zsh-autosuggestions`, `zoxide`, `foot`.

```bash
git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
git clone https://github.com/romkatv/powerlevel10k.git \
    ~/.oh-my-zsh/custom/themes/powerlevel10k
```

### Форматирование и линтинг

`conform` вызывает инструменты по filetype, `nvim-lint` проверяет код после
сохранения и выхода из режима вставки. Без них сохранение в nvim будет
спотыкаться.

```bash
pip install black isort autopep8 flake8 djlint
cargo install selene          # линтер lua
npm install -g prettier       # js / ts / css
```

### Отладка, тесты, профилирование

```bash
pip install debugpy           # nvim-dap-python
pip install pytest            # pytest.nvim
pip install memory_profiler   # <Space>pm
```

`daddy` (для `:DB` в vim-dadbod) ставится отдельно, apt/aur.

### Языковые серверы

Ставятся сами через `mason-lspconfig` при первом запуске nvim:
`pyright`, `lua_ls`, `bashls`, `ts_ls`, `html`. Каталог `~/.local/share/nvim/mason/bin`
mason добавляет в `PATH` сам, вручную ничего прописывать не нужно.

## 🚀 Установка

```bash
git clone https://github.com/gdudenko/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
source ~/.zshrc
nvim            # плагины и LSP ставятся при первом старте
```

`install.sh` понимает флаги:

```bash
./install.sh --dry-run    # показать, что будет сделано
./install.sh --force      # перезаписать существующие файлы, старые в бэкап
```

С `--force` старые файлы копируются в `~/.dotfiles_backup_<дата>_<время>`.

Что делает скрипт:

| Источник | Куда |
|----------|------|
| `.config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |
| `.config/tmux/create_panes.sh` | `~/.config/tmux/create_panes.sh` (+chmod) |
| `.config/nvim/init.lua` | `~/.config/nvim/init.lua` |
| `.config/nvim/lua` | `~/.config/nvim/lua` |
| `.config/nvim/lazy-lock.json` | `~/.config/nvim/lazy-lock.json` |
| `.zshrc` | `~/.zshrc` |

Ручной вариант, если скрипт не нужен:

```bash
ln -sf ~/.dotfiles/.config/tmux/tmux.conf ~/.config/tmux/tmux.conf
ln -sf ~/.dotfiles/.config/tmux/create_panes.sh ~/.config/tmux/create_panes.sh
chmod +x ~/.config/tmux/create_panes.sh
ln -sf ~/.dotfiles/.config/nvim/init.lua ~/.config/nvim/init.lua
ln -sf ~/.dotfiles/.config/nvim/lua ~/.config/nvim/lua
ln -sf ~/.dotfiles/.config/nvim/lazy-lock.json ~/.config/nvim/lazy-lock.json
ln -sf ~/.dotfiles/.zshrc ~/.zshrc
```

Важно: линкуется **каталог** `lua`, а не файлы внутри. Все модули лежат в
`lua/config` и `lua/plugins`, отдельные файлы не линковать.

## 🔄 Обновление и откат

```bash
cd ~/.dotfiles && git pull
./install.sh --force
source ~/.zshrc
tmux source-file ~/.config/tmux/tmux.conf
```

Откат на конкретный коммит:

```bash
cd ~/.dotfiles
git log --oneline
git checkout <коммит>
./install.sh --force
cd ~/.dotfiles && git checkout main
```

`./uninstall.sh` удаляет симлинки (init.lua, lua не трогает, lazy-lock.json,
tmux.conf, create_panes.sh, .zshrc). Бэкапы не восстанавливаются автоматически:

```bash
cp -r ~/.dotfiles_backup_<дата>_<время>/.config/tmux ~/.config/
```

## 🗂 Структура

```
~/.dotfiles/
├── .config/
│   ├── nvim/
│   │   ├── init.lua                 # 4 require, вся логика ниже
│   │   ├── lazy-lock.json           # 45 записей с зафиксированными коммитами
│   │   └── lua/
│   │       ├── config/
│   │       │   ├── options.lua       # опции, диагностика, русская раскладка
│   │       │   ├── plugins.lua       # lazy.nvim, сборка спецификаций
│   │       │   ├── autocmds.lua      # Django-шаблоны, подсказка про venv
│   │       │   └── tmux_utils.lua    # отправка команд в tmux, venv, профайлер
│   │       └── plugins/              # по одному модулю на тему
│   │           ├── theme.lua         # catppuccin, подсветка Django
│   │           ├── nvim_tree.lua     # дерево + cd в панель tmux
│   │           ├── statusline.lua    # navic, lualine
│   │           ├── editing.lua       # autopairs, closetag, indent-blankline
│   │           ├── treesitter.lua    # парсеры и подсветка
│   │           ├── telescope.lua     # поиск
│   │           ├── aerial.lua        # outline
│   │           ├── lsp.lua           # серверы, cmp, русские подсказки
│   │           ├── formatting.lua    # conform, nvim-lint
│   │           ├── debugging.lua     # dap, pytest, slime
│   │           ├── git.lua           # gitsigns
│   │           ├── utilities.lua     # which-key, neogit, diffview, trouble
│   │           ├── ai.lua            # supermaven, codecompanion
│   │           └── python_project.lua# хелперы (не плагин)
│   └── tmux/
│       ├── tmux.conf
│       └── create_panes.sh
├── .zshrc
├── install.sh
├── uninstall.sh
├── .gitignore
└── README.md
```

`plugins.lua` только собирает список: модули из `lua/plugins` подключаются
поимённо. Новый плагин кладётся в свой тематический модуль, в `plugins.lua`
добавляется одна строка.

Плагины грузятся лениво по событиям (`BufReadPost`, `VeryLazy`,
`InsertEnter`), treesitter и catppuccin eagerly. Версии зафиксированы в
`lazy-lock.json`, обновить: `:Lazy update`.

## ⌨️ Neovim

leader = пробел, localleader = пробел.

### Навигация с русской раскладки

Работает без переключения: `h`/`р` влево, `j`/`о` вниз, `k`/`л` вверх,
`l`/`д` вправо, `ш` = `i`, `ф` = `a`.

### Общие

| Клавиши | Действие |
|---------|----------|
| `<Space>w` | сохранить |
| `<Space>qq` | закрыть |
| `<Space>r` | перезагрузить конфиг (`:source` без аргумента) |
| `<Space>e` | показать диагностику |
| `<Space>da` / `<Space>dd` | показать / скрыть диагностику |
| `<Space>ql` | ошибки в loclist |
| `[d` / `]d` | предыдущая / следующая диагностика |
| `<Space>lf` | форматировать файл |
| `gd` | перейти к определению (после подключения LSP) |
| `K` | документация с переводом подписей на русский |
| `]c` / `[c` | следующий / предыдущий изменённый блок git |

### Файлы и поиск

| Клавиши | Действие |
|---------|----------|
| `<Space>nt` | дерево файлов |
| `<Space>ff` / `<Space>fg` | найти файл / найти текст |
| `<Space>fd` | найти диагностики |
| `<Space>dt` | поиск Django-тегов `{%` в текущем буфере |
| `<Space>cs` / `<Space>cS` | символы файла / символы проекта |
| `<Space>ft` | TODO / FIXME |

В дереве: `Enter` или `o` открыть, `h` свернуть, `a` создать, `d` удалить,
`r` переименовать, `c` копировать, `x` вырезать, `p` вставить,
`C` сделать каталог корнем и отправить `cd` в панель tmux.

### Outline

`<Space>o` открыть/закрыть aerial, `{` и `}` прыгают по символам.

### Git

| Клавиши | Действие |
|---------|----------|
| `<Space>gg` | Neogit, статус |
| `<Space>gc` | коммит |
| `<Space>gd` / `<Space>gD` | Diffview открыть / закрыть |
| `<Space>gh` / `<Space>gH` | история файла / ветки |
| `<Space>hs` / `<Space>hr` | stage / reset блока |
| `<Space>hS` / `<Space>hR` | stage / reset всего файла |
| `<Space>hu` | отменить последний stage |
| `<Space>hp` | превью блока |
| `<Space>hb` | blame строки |
| `<Space>hd` | diff файла |

Клавиши gitsigns появляются в буфере после `BufReadPre`, то есть только
в файлах внутри git-репозитория.

### Ошибки

`<Space>xx` список ошибок, `<Space>xw` по проекту, `<Space>xd` по файлу.
Диагностика видна и сама: `CursorHold` открывает всплывающее окно.

### Python

| Клавиши | Действие |
|---------|----------|
| `<Space>np` / `<Space>pv` / `<Space>tv` | найти или создать venv |
| `<Space>pp` | cProfile текущего файла |
| `<Space>ps` | cProfile + топ-20 по времени (cumulative) |
| `<Space>pm` | профиль памяти (нужен `memory_profiler`) |
| `<Space>f` | LSP-формат (работает после подключения LSP) |
| `<Space>rn` | переименовать символ |
| `<Space>ca` | code action |

`<Space>np` ничего не активирует молча: находит `venv`, `.venv` или `env` и
спрашивает. Если окружения нет, предлагает создать и ждёт готовности
`bin/activate` прямо в терминале, без слепой задержки.

При старте nvim один раз показывает подсказку про venv: если в корне есть
`requirements.txt`, `pyproject.toml`, `setup.py`, `manage.py` или `.py`-файлы.

В корне git-проекта nvim дописывает `.gitignore` (если файла не было или
не хватает строк) и создаёт `pyrightconfig.json`, если нашлась venv и нет
ни конфига, ни секции `[tool.pyright]` в `pyproject.toml`. Оба файла
автоматически добавляются в `.gitignore`.

### Django

| Клавиши | Действие |
|---------|----------|
| `<Space>dr` | runserver |
| `<Space>dm` | migrate |
| `<Space>dmm` | makemigrations |
| `<Space>dtc` | test |
| `<Space>rr` | запустить текущий файл в tmux |

Шаблоны `*/templates/*.html` получают filetype `htmldjango`, отступ 2
пробела и подсветку тегов. Django-шаблоны форматируются через `djlint`,
Python-файлы: `isort` + `black` + `autopep8` (до 79 колонок).

### Отладка и тесты

| Клавиши | Действие |
|---------|----------|
| `F5` / `F9` | продолжить / точка останова |
| `F10` / `F11` / `F12` | шаг через / внутрь / наружу |
| `<Space>du` | показать UI отладки |
| `<Space>dx` / `<Space>dC` | отладить тест под курсором / класс |
| `<Space>ss` | отправить строку или выделение в REPL (vim-slime) |
| `TT` / `Ta` / `Td` | pytest: прогнать файл / привязать / отвязать |

### AI

| Клавиши | Действие |
|---------|----------|
| `<Space>oa` | открыть чат |
| `<Space>oo` | спросить о коде |
| `<Space>oe` | объяснить код (работает и в visual) |
| `<Space>og` | сгенерировать по описанию (работает и в visual) |
| `<Space>oc` | меню действий |
| `<Space>ob` | прицепить текущий файл к чату |
| `<C-g>` / `<C-]>` / `<C-j>` | supermaven: принять подсказку / отклонить / принять слово |

В буфере чата `Enter` отправляет сообщение, `Shift+Enter` переносит строку.
Внутри чата работают `/ask` и `/explain`.

Постоянной шпаргалки лидера от which-key нет: она живёт в lualine и прячется
на окнах уже 110 колонок. Группы which-key объявлены вручную (`<Space>f` =
Поиск, `p` = Python, `x` = Ошибки, `d` = Django, `g` = Git, `h` = Git-блоки,
`o` = Outline, `t` = Tmux), иначе v3 показывает «+4 keymaps».

Оговорка: в группу `d` попадают и Django-команды, и отладка (`du`, `dx`,
`dC`), потому что отладчик вынесен туда же. Это осознанно, переименовывать
groups в `utilities.lua` если понадобится.

## 🖥 tmux

prefix = `Ctrl+A`.

| Клавиши | Действие |
|---------|----------|
| `Ctrl+A P` | создать панели для nvim (терминал 20% + nvim) |
| `Ctrl+A h/j/k/l` | перейти между панелями |
| `Ctrl+A H/J/K/L` | изменить размер панели на 5 |
| `Ctrl+A \|` / `Ctrl+A -` | разделить по вертикали / горизонтали |
| `Ctrl+A x` | закрыть панель |
| `Ctrl+A r` | перезагрузить конфиг |
| `Ctrl+A s` | синхронизация панелей |
| `Ctrl+A C-a` | предыдущее окно |
| `Ctrl+A S-v` | вставить из системного буфера |
| мышь | копирование выделения в системный буфер |

Окна и панели нумеруются с 1. Статусбар показывает сессию, окно, дату, время
и текущую ветку git. Плагинов tmux в конфиге нет, tpm не нужен.

### Zsh

| Команда | Действие |
|---------|----------|
| `np [папка]` | tmux-сессия с именем проекта, venv и nvim уже подняты |
| `npp` | добавить панели в текущую сессию |
| `t` | безопасный вызов tmux (ругается, если сервера нет) |
| `tls` / `ta` / `tk` | список сессий / присоединиться / убить |
| `tka` / `tks` | убить все сессии / сервер |
| `tn` / `tw` / `tp` | новое окно / окна / панели |
| `nreload` | перезагрузить nvim |
| `treload` | перезагрузить tmux |
| `np-help` | список команд в терминале |
| `check-deps` | проверить tmux, nvim, git |

`cd` обёрнут в zoxide: переход в `..`, `~`, `-` и абсолютные пути уходит в
`builtin cd`, всё остальное ищет через `__zoxide_z`.

Известная неточность: `treload` делает `source-file ~/.tmux.conf`, а
конфиг лежит в `~/.config/tmux/tmux.conf`. Рабочий вариант:
`tmux source-file ~/.config/tmux/tmux.conf` или `Ctrl+A r`.

## 🤖 AI-ассистент

### codecompanion (чат)

Endpoint: `https://opencode.ai/zen/v1/chat/completions`, модель
`space-bunny-free`. Ключ лежит в `~/.hermes/.env` и читается в момент запроса,
в конфиге его нет:

```bash
echo 'OPENCODE_ZEN_API_KEY=ваш_ключ' >> ~/.hermes/.env
```

При старте nvim сообщает, найден ключ или нет. Если нет, но есть
`OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `GEMINI_API_KEY` или
`ANTHROPIC_API_KEY` в окружении, подсказка считается положительной.

Три вещи, которые в codecompanion неочевидны:

- **Дефолтный адаптер `copilot`** отправляет текст запроса на
  `api.githubcopilot.com` при каждом открытии чата. Отключено через
  `background = { enabled = false }`.
- **Cloudflare перед opencode.ai отвечает 403 (code 1010)** на запрос вообще
  без `User-Agent`. В адаптере прописан явный заголовок.
- **Endpoint задаётся функцией в `strategies.chat.adapter`**, а не полем
  `strategies.chat.url`: `init_adapter` вызывает `resolve()` без opts, поля
  url и model там молча игнорируются. Модель уходит через
  `schema.model.default`.

Переключение на локальную модель меняет две строки в `M.adapter()`
(`lua/plugins/ai.lua`):

```lua
url = "http://127.0.0.1:8080/v1/chat/completions"
schema = { model = { default = "<имя модели>" } }
```

URL обязан быть полным, до `/chat/completions`: без пути запрос попадает в
корень API и приходит HTML вместо JSON. Для локального сервера api_key любой,
llama.cpp его не проверяет. Локальный ollama: `http://127.0.0.1:11434/v1/chat/completions`.

Контекст файла: `strategies.shared.editor_context.buffer` с
`default_params = "all"`. По умолчанию плагин шлёт только дифф, и на вопрос
«объясни этот код» модель получала пустой фрагмент. Ключ должен быть именно
в `shared`, а не в `interactions`: `config.lua` пересобирает `interactions` из
дефолтов и затирает секцию.

`<Space>ob` цепляет файл напрямую через
`format_buffer_for_llm`: штатный `CodeCompanionChat add` в обычном режиме
возвращает пустые строки, они заполняются только при визуальном выделении.

### supermaven (инлайн-подсказки)

Отдельный бинарник, свой аккаунт, ключ opencode-zen ему не подходит. При
первом запуске предлагает Free Tier (`:SupermavenUseFree`) или Pro по ссылке.
Лог: `:SupermavenShowLog`.

### Логи

```bash
tail -30 ~/.local/state/nvim/codecompanion.log    # уровень WARN, по умолчанию
tail -30 ~/.local/state/nvim/lsp.log
tail -30 ~/.local/state/nvim/mason.log
```

| Ошибка | Причина |
|--------|---------|
| `unsupported_country_region_territory` | запрос ушёл не туда. В `set-cookie` смотреть `Domain=` |
| `forbidden: access denied` с `x-github-request-id` | подхватился дефолтный copilot-адаптер |
| `error code: 1010` от Cloudflare | нет заголовка `User-Agent` |
| HTML вместо текста | url без `/chat/completions` |
| `Invalid API key` | ключ не прочитан из `~/.hermes/.env` |

## 🐛 Устранение проблем

**Плагины не ставятся или падает загрузка**

```bash
rm -rf ~/.local/share/nvim/lazy
nvim --headless "+Lazy! sync" +qa
```

Посмотреть, что lazy считает сломанным: `:Lazy health`.

**nvim-treesitter и парсеры**

Ветка `main` у nvim-treesitter это полностью несовместимый rewrite, установка
парсеров и подсветка включены вручную, стандартные ключи `highlight.enable` и
`indent.enable` больше не работают. Проверить: `:checkhealth nvim-treesitter`.

Подсветка стартует только для filetype с грамматикой: внутри
`vim.treesitter.start()` стоит `assert(get_parser())`, который роняет событие
на NvimTree, help и prompt. Перед стартом конфиг спрашивает
`vim.treesitter.language.add()`.

Если nvim-treesitter обновился и сломал отступы, `indentexpr` ставится тем же
условием: `v:lua.require'nvim-treesitter'.indentexpr()`.

**LSP не стартует**

`:Mason` показывает состояние серверов, `:LspInfo` и `:checkhealth vim.lsp`
дают детали. Pyright ищет корень по маркерам: `pyproject.toml`, `setup.py`,
`setup.cfg`, `requirements.txt`, `Pipfile`, `poetry.lock`, `manage.py`,
`scrapy.cfg`, `.git`, `venv`, `.venv`. `scrapy.cfg` добавлен специально для
Scrapy: без него `startproject` создаёт проект, у которого нет других маркеров,
и pyright стартует с `root_dir = nil`.

**tmux не подхватывает конфиг**

```bash
tmux source-file ~/.config/tmux/tmux.conf
tmux list-sessions
```

`~/.tmux.conf` не используется, symlink на него не создаётся.

**Клавиши не работают**

Часть клавиш буферные (`gd`, `K`, `<leader>rn`, `<Space>ca`, `<Space>f`,
`hs`, `hp`, `]c`): они появляются после `LspAttach` или `BufReadPre`, то есть
в Python-файле внутри git-проекта. Проверить текущие раскладки: `:map`.

**AI не отвечает**

Проверить ключ и endpoint вручную:

```bash
grep -c OPENCODE_ZEN_API_KEY ~/.hermes/.env
curl -s -o /dev/null -w '%{http_code}\n' \
  https://opencode.ai/zen/v1/chat/completions \
  -H "Authorization: Bearer $OPENCODE_ZEN_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: curl/8.22.0" \
  -d '{"model":"space-bunny-free","messages":[{"role":"user","content":"hi"}],"max_tokens":5}'
```

Должен быть 200. 403 или 401 означает проблему с ключом, а не с nvim.

## 🔐 Секреты

Секретов в репозитории нет и быть не должно. Ключ AI лежит в `~/.hermes/.env`
и читается оттуда в момент запроса, поэтому в git он не попадает.

Что уже закрыто в `.gitignore`: `.env`, `*.pem`, `*.key`, `*.secret`,
`credentials*`, `secrets*`, кэши nvim, `.zsh_history`.

## 📄 Лицензия

MIT.