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

Python-инструменты:

bash
pip install --user \
    black isort flake8 \
    djlint ruff \
    pytest memory_profiler \
    django

🚀 Установка
Вариант 1: Клонирование + скрипт

bash
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

Вариант 2: Ручная установка (без скрипта)

bash
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

🔄 Обновление конфигурации

bash
# 1. Pull новых изменений
cd ~/.dotfiles && git pull

# 2. Применить изменения (перезаписать текущие конфиги)
./install.sh --force

# 3. Перезагрузить окружение
source ~/.zshrc

📜 Откат к предыдущей версии

bash
# Посмотреть историю коммитов
cd ~/.dotfiles && git log --oneline

# Откатиться к конкретному коммиту
cd ~/.dotfiles && git checkout abc1234

# Применить старую версию
./install.sh --force

# Вернуться на main
cd ~/.dotfiles && git checkout main

🎮 Основные команды
Neovim (leader = пробел)
Комбинация
	
Описание
<Space>nt
	
Файловый менеджер
<Space>ff
	
Поиск файлов
<Space>rr
	
Запустить текущий файл в tmux
<Space>pp
	
Профилирование Python (cProfile)
<Space>dr
	
Django runserver
<Space>dm
	
Django migrate
Tmux (prefix = Ctrl+A)
Комбинация
	
Описание
Ctrl+A P
	
Создать панели для Neovim
Ctrl+A h/j/k/l
	
Навигация между панелями
Ctrl+A | / -
	
Разделить панель
Ctrl+A r
	
Перезагрузить конфиг tmux
Zsh алиасы
Команда
	
Описание
np [папка]
	
Создать/присоединиться к проекту
npp
	
Добавить панели в текущую сессию
tls / ta / tk
	
Управление tmux-сессиями
nreload / treload
	
Перезагрузить конфиги
🐛 Устранение проблем
Плагины не устанавливаются

bash
# Удалить кэш lazy и переустановить
rm -rf ~/.local/share/nvim/lazy
nvim --headless "+Lazy! sync" +qa

Ошибки LSP в Python

bash
# Переустановить LSP-серверы
:Lazy
# → Mason → Pyright → Reinstall

Tmux не видит плагины

bash
# Переустановить tmux plugins manager
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# В tmux: Ctrl+A + I (установка плагинов)

📁 Структура репозитория

~/.dotfiles/
├── .config/
│   ├── tmux/          # tmux.conf + create_panes.sh
│   └── nvim/          # init.lua + lazy-lock.json
├── .zshrc             # Shell конфигурация
├── install.sh         # Скрипт установки (symlinks)
├── uninstall.sh       # Скрипт удаления (опционально)
├── .gitignore         # Исключения для Git
└── README.md          # Этот файл

🔐 Безопасность

    Никогда не коммитьте файлы с паролями, API-ключами, .env
    Используйте git update-index --skip-worktree <файл> для локальных изменений
    Для секретов: git-crypt или git-secret

🤝 Вклад в проект

    Fork репозиторий
    Создайте ветку: git checkout -b feature/my-feature
    Внесите изменения + протестируйте
    Закоммитьте: git commit -am 'feat: описание'
    Пушните: git push origin feature/my-feature
    Откройте Pull Request

    💡 Совет: Регулярно делайте коммиты с понятными сообщениями:

    bash
    git commit -m "feat: добавить профилирование памяти"
    git commit -m "fix: исправить парсинг flake8 в nvim-lint"
    git commit -m "docs: обновить README с командами tmux"

📄 Лицензия
MIT — используйте как угодно.


---

## 🗂️ Итоговая структура файлов для коммита


~/.dotfiles/
├── README.md          ← создать
├── .gitignore         ← создать
├── install.sh         ← создать (код выше)
├── uninstall.sh       ← создать (опционально)
├── .config/
│   ├── tmux/
│   │   ├── tmux.conf           ← скопировать из ~/.config/tmux/
│   │   └── create_panes.sh     ← скопировать
│   └── nvim/
│       ├── init.lua            ← скопировать
│       └── lazy-lock.json      ← скопировать
└── .zshrc                      ← скопировать из ~/
