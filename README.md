# 🔧 Dotfiles — Neovim + Tmux + Zsh конфигурация

Персональная среда разработки для Python/Django с профилированием, отладкой и интеграцией tmux.

## 📦 Требования

- **OS**: Linux (Arch Linux протестирован)
- **Neovim**: ≥ 0.10 (рекомендуется 0.12+)
- **Tmux**: ≥ 3.0
- **Zsh** + **Oh My Zsh** + **Powerlevel10k**
- **Python**: 3.10+ с `pip`
- **Git**: ≥ 2.30

### Обязательные системные пакеты (Arch):

```bash
sudo pacman -S \
    neovim tmux zsh git \
    python python-pip \
    ripgrep fd fzf \
    xclip wl-clipboard \
    gcc make cmake
```

### Python-инструменты:

```bash
pip install --user \
    black isort flake8 \
    djlint ruff \
    pytest memory_profiler \
    django
```

## 🚀 Установка

### Вариант 1: Клонирование + скрипт

```bash
# 1. Клонируем репозиторий
git clone https://github.com/ВАШ_ЮЗЕРНЕЙМ/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# 2. Запускаем установку (создаёт симлинки)
./install.sh

# 3. Применяем изменения
source ~/.zshrc

# 4. Запускаем Neovim для установки плагинов
nvim  # плагины установятся автоматически через lazy.nvim

# 5. Перезапускаем tmux (если используется)
tmux kill-server && tmux
```

### Вариант 2: Ручная установка (без скрипта)

```bash
# Tmux
ln -sf ~/.dotfiles/.config/tmux/tmux.conf ~/.config/tmux/tmux.conf
ln -sf ~/.dotfiles/.config/tmux/create_panes.sh ~/.config/tmux/create_panes.sh
chmod +x ~/.config/tmux/create_panes.sh

# Neovim
ln -sf ~/.dotfiles/.config/nvim/init.lua ~/.config/nvim/init.lua
ln -sf ~/.dotfiles/.config/nvim/lazy-lock.json ~/.config/nvim/lazy-lock.json

# Zsh
ln -sf ~/.dotfiles/.zshrc ~/.zshrc

# Применяем
source ~/.zshrc && nvim
```

## 🔄 Обновление конфигурации

```bash
# 1. Pull новых изменений
cd ~/.dotfiles && git pull

# 2. Применить изменения (перезаписать текущие конфиги)
./install.sh --force

# 3. Перезагрузить окружение
source ~/.zshrc
```

## 📜 Откат к предыдущей версии

```bash
# Посмотреть историю коммитов
cd ~/.dotfiles && git log --oneline

# Откатиться к конкретному коммиту
cd ~/.dotfiles && git checkout abc1234

# Применить старую версию
./install.sh --force

# Вернуться на main
cd ~/.dotfiles && git checkout main
```

## 🎮 Основные команды

### Neovim (leader = пробел)

| Комбинация | Описание |
|------------|----------|
| `<Space>nt` | Файловый менеджер |
| `<Space>ff` | Поиск файлов |
| `<Space>rr` | Запустить текущий файл в tmux |
| `<Space>pp` | Профилирование Python (cProfile) |
| `<Space>dr` | Django runserver |
| `<Space>dm` | Django migrate |
| `<Space>oa` | AI: открыть чат |
| `<Space>oo` | AI: спросить о коде |
| `<Space>oe` | AI: объяснить код |
| `<Space>og` | AI: сгенерировать по описанию (inline) |
| `<Space>oc` | AI: меню действий |
| `<Space>gg` / `<Space>gc` | Neogit: статус / коммит |
| `<Space>gd` | Diffview: текущий файл |
| `<Space>hs` / `<Space>hp` | Git: stage блока / превью |
| `<Space>xx` | Trouble: список ошибок |
| `<Space>f` / `<Space>g` | Раскрыть группы which-key |

В statusline постоянно висит шпаргалка по самым частым командам
(`ff`, `fg`, `g`, `nt`, `dr`, `np`, `xx`). На окнах уже 110 колонок она
скрывается, чтобы не вытеснять имя файла.

### Tmux (prefix = Ctrl+A)

| Комбинация | Описание |
|------------|----------|
| `Ctrl+A P` | Создать панели для Neovim |
| `Ctrl+A h/j/k/l` | Навигация между панелями |
| `Ctrl+A \|` / `-` | Разделить панель |
| `Ctrl+A r` | Перезагрузить конфиг tmux |

### Zsh алиасы

| Команда | Описание |
|---------|----------|
| `np [папка]` | Создать/присоединиться к проекту |
| `npp` | Добавить панели в текущую сессию |
| `tls` / `ta` / `tk` | Управление tmux-сессиями |
| `nreload` / `treload` | Перезагрузить конфиги |

## 🤖 AI-ассистент (codecompanion.nvim)

Чат с LLM прямо в редакторе. Клавиши — в таблице выше (`<Space>oa` и далее),
плюс slash-команды `/ask` и `/explain` внутри чата.

### Настройка ключа

Ключ берётся из `~/.hermes/.env`, переменная `OPENCODE_ZEN_API_KEY`.
В самом конфиге секрета нет — он читается в момент запроса:

```bash
echo 'OPENCODE_ZEN_API_KEY=ваш_ключ' >> ~/.hermes/.env
```

При старте nvim покажет уведомление: найден ключ или нет.

### Переключение на локальную модель

Всё настраивается одной функцией `cc_adapter()` в начале `plugins.lua`.
Меняются две строки:

```lua
url = "http://127.0.0.1:8080/v1/chat/completions"
schema = { model = { default = "<имя модели>" } }
```

Запуск сервиса:

```bash
sudo systemctl enable --now llama-server
curl -s http://127.0.0.1:8080/v1/models   # убедиться, что модель поднялась
```

Юнит лежит в `/etc/systemd/system/llama-server.service`, модель тянется
через флаг `-hf` и качивается с HuggingFace при первом старте (это надолго,
на 9B около нескольких ГБ).

Для ollama URL будет `http://127.0.0.1:11434/v1/chat/completions`.

Два обязательных условия, иначе не заработает:

- **URL полный, до `/chat/completions`.** Без пути запрос попадает в корень
  API и приходит HTML вместо JSON.
- **Модель через `schema.model.default`.** Поле `model` на верхнем уровне
  не попадает в schema адаптера, остаётся дефолт `gpt-4.1`.

Для локального сервера api_key любой — llama.cpp его не проверяет.

### Замечания по реализации

Три вещи, которые в codecompanion неочевидны и на которые ушло время:

- Дефолтный адаптер — `copilot`, и он шлёт текст запроса на
  `api.githubcopilot.com`. В конфиге отключено через `background = { enabled = false }`.
- Cloudflare перед opencode.ai отвечает 403 (error code 1010) на запросы
  вообще без `User-Agent`. В адаптере прописан явный заголовок.
- Свой endpoint задаётся функцией в `strategies.chat.adapter`, а не полем
  `strategies.chat.url`: `init_adapter` вызывает `resolve()` без opts, и
  поля url/model там молча игнорируются.

## 🐛 Устранение проблем

### Плагины не устанавливаются

```bash
# Удалить кэш lazy и переустановить
rm -rf ~/.local/share/nvim/lazy
nvim --headless "+Lazy! sync" +qa
```

### Ошибки LSP в Python

```bash
# Переустановить LSP-серверы
:Lazy
# → Mason → Pyright → Reinstall
```

### Tmux не видит плагины

```bash
# Переустановить tmux plugins manager
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# В tmux: Ctrl+A + I (установка плагинов)
```

### AI не отвечает

Смотри лог плагина — в нём видно реальный ответ сервера:

```bash
tail -30 ~/.local/state/nvim/codecompanion.log
```

Что означают ошибки:

| Ошибка | Причина |
|--------|---------|
| `unsupported_country_region_territory` | Запрос ушёл не туда. Смотри `Domain=` в set-cookie: `api.openai.com` — url не применился; другого значения быть не должно |
| `forbidden: access denied` с `x-github-request-id` | Используется дефолтный copilot-адаптер вместо openai |
| `error code: 1010` от Cloudflare | Нет заголовка `User-Agent` в адаптере |
| HTML вместо текста | url без пути `/chat/completions`, попали в корень API |
| `Invalid API key` | Ключ не прочитан. Проверь, что `OPENCODE_ZEN_API_KEY` есть в `~/.hermes/.env` |

Проверить ключ и endpoint вручную:

```bash
grep -c OPENCODE_ZEN_API_KEY ~/.hermes/.env
curl -s -o /dev/null -w '%{http_code}\n' \
  https://opencode.ai/zen/v1/chat/completions \
  -H "Authorization: Bearer *** \
  -H 'Content-Type: application/json' \
  -d '{"model":"space-bunny-free","messages":[{"role":"user","content":"hi"}],"max_tokens":5}'
```

Должно быть 200. Если 403 или 401 — дело в ключе, а не в nvim.

## 📁 Структура репозитория

```
~/.dotfiles/
├── .config/
│   ├── tmux/          # tmux.conf + create_panes.sh
│   └── nvim/          # init.lua, lazy-lock.json, lua/config/*.lua
├── .zshrc             # Shell конфигурация
├── install.sh         # Скрипт установки (symlinks)
├── uninstall.sh       # Скрипт удаления (опционально)
├── .gitignore         # Исключения для Git
└── README.md          # Этот файл
```

## 🔐 Безопасность

- **Никогда не коммитьте** файлы с паролями, API-ключами, `.env`
- Используйте `git update-index --skip-worktree <файл>` для локальных изменений
- Для секретов: `git-crypt` или `git-secret`

## 🤝 Вклад в проект

1. Fork репозиторий
2. Создайте ветку: `git checkout -b feature/my-feature`
3. Внесите изменения + протестируйте
4. Закоммитьте: `git commit -am 'feat: описание'`
5. Пушните: `git push origin feature/my-feature`
6. Откройте Pull Request

> 💡 **Совет**: Регулярно делайте коммиты с понятными сообщениями:

```bash
git commit -m "feat: добавить профилирование памяти"
git commit -m "fix: исправить парсинг flake8 в nvim-lint"
git commit -m "docs: обновить README с командами tmux"
```

## 📄 Лицензия

MIT — используйте как угодно.
