# Запускаем fastfetch сразу, до инициализации Powerlevel10k
fastfetch

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Если вы перешли с bash, возможно, потребуется изменить $PATH.
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export PATH="$HOME/.npm-global/bin:$PATH"

# Путь к установке Oh My Zsh.
export ZSH="$HOME/.oh-my-zsh"

# Установите имя темы для загрузки.
ZSH_THEME="powerlevel10k/powerlevel10k"

# Плагины
plugins=(
    git
    zsh-syntax-highlighting
    zsh-autosuggestions
    foot
    zoxide
    )

source $ZSH/oh-my-zsh.sh

# Предпочтительный редактор для локальных и удаленных сессий
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# =============================================
# TMUX + NEOVIM ПРОЕКТНЫЕ ФУНКЦИИ (ИСПРАВЛЕННЫЕ)
# =============================================

# Функция 1: Автоматический запуск tmux с проектом (ИСПРАВЛЕННАЯ)
nvim-project() {
    # Если передан аргумент - переходим в папку
    if [ -n "$1" ]; then
        if [ -d "$1" ]; then
            builtin cd "$1" || return 1
        else
            echo "❌ Ошибка: Директория '$1' не существует"
            return 1
        fi
    fi

    # Запускаем tmux сессию с именем проекта
    local session_name=$(basename "$(pwd)")
    local project_path="$(pwd)"

    # ФИКС: Tmux не позволяет начинать имя сессии с точки, он заменяет её на _
    # Делаем это заранее, чтобы все команды обращались к правильному имени
    session_name="${session_name/#./_}"

    echo "🔄 Настраиваю проект: $session_name"
    echo "📁 Путь: $project_path"

    # Проверяем, есть ли уже сессия
    if ! tmux has-session -t "=$session_name" 2>/dev/null; then
        echo "🆕 Создаю новую tmux сессию: $session_name"

        # Создаём сессию БЕЗ запуска nvim внутри
        tmux new-session -d -s "$session_name" -c "$project_path" -n "main"

        # Даём сессии время на полную инициализацию
        sleep 0.5

        # Создаём панели через скрипт, передав ему правильное имя сессии
        ~/.config/tmux/create_panes.sh "$session_name" "main" "1"

    else
        echo "ℹ️  Сессия '$session_name' уже существует"
    fi

    # Подключаемся к сессии
    echo "📌 Присоединяюсь к сессии: $session_name"
    echo "💡 Используйте Ctrl+A P для пересоздания панелей если нужно"
    tmux attach-session -t "=$session_name"
}

# Функция 2: Быстрое создание панелей в существующей сессии
create-neovim-panes() {
    # Просто запускаем скрипт создания панелей
    ~/.config/tmux/create_panes.sh
    echo "✅ Панели созданы"
}

# Функция 3: Безопасная команда для tmux
tmux-safe() {
    if tmux list-sessions &>/dev/null; then
        tmux "$@"
    else
        echo "❌ tmux не запущен. Используйте 'np' для создания сессии"
        return 1
    fi
}

# Функция 4: Закрыть все tmux сессии
tmux-kill-all() {
    echo "⚠️  Закрываю все tmux сессии..."
    tmux list-sessions | cut -d: -f1 | while read session; do
        echo "  Убиваю сессию: $session"
        tmux kill-session -t "$session"
    done
    echo "✅ Все сессии закрыты"
}

export ZOXIDE_CMD_OVERRIDE="cd"


# =============================================
# АЛИАСЫ
# =============================================

# Основные алиасы
alias np="nvim-project"                          # Создать проектную сессию
alias npp="create-neovim-panes"                  # Добавить панели в текущую сессию
alias t="tmux-safe"                              # Безопасный вызов tmux

# Управление сессиями
alias tls="tmux-safe list-sessions"              # Список сессий
alias ta="tmux-safe attach -t"                   # Присоединиться к сессии
alias tk="tmux-safe kill-session -t"             # Убить сессию
alias tka="tmux-kill-all"                        # Убить все сессии
alias tks="tmux-safe kill-server"                # Остановить tmux сервер

# Окна и панели
alias tn="tmux-safe new-window"                  # Новое окно
alias tw="tmux-safe list-windows"                # Список окон
alias tp="tmux-safe list-panes"                  # Список панелей

# Перезагрузка конфигурации
alias treload="tmux-safe source-file ~/.tmux.conf && echo '✅ tmux config reloaded'"
alias nreload="nvim +'source $MYVIMRC' +echo '✅ Neovim config reloaded'"

# Быстрое создание панелей (альтернатива Ctrl+A P)
alias tpanes="~/.config/tmux/create_panes.sh"

# Проверка зависимостей
alias check-deps="echo '🔍 Проверка зависимостей...' && \
                  command -v tmux >/dev/null && echo '✅ tmux: установлен' || echo '❌ tmux: не установлен' && \
                  command -v nvim >/dev/null && echo '✅ nvim: установлен' || echo '❌ nvim: не установлен' && \
                  command -v git >/dev/null && echo '✅ git: установлен' || echo '❌ git: не установлен'"

alias ls='lsd'
alias cat='bat'
# Умная обёртка для cd + zoxide
cd() {
    # Если нет аргументов или это спец-случаи — используем builtin cd
    if [[ $# -eq 0 || "$1" == '-' || "$1" == '/' || "$1" == '~' || "$1" == '..' || "$1" == '../'* || "$1" == '.' || "$1" == '.'* ]]; then
        builtin cd "$@"
    else
        # Для всего остального — zoxide
        __zoxide_z "$@"
    fi
}

# Справка
alias np-help="echo '📚 КОМАНДЫ NEOVIM+TMUX:' && \
               echo '  np [папка]    - Создать/присоединиться к проекту' && \
               echo '  npp           - Добавить панели в текущую сессию' && \
               echo '  Ctrl+A P      - Создать панели (изнутри tmux)' && \
               echo '  Ctrl+A |      - Разделить панель вертикально' && \
               echo '  Ctrl+A -      - Разделить панель горизонтально' && \
               echo '  Ctrl+A h/j/k/l - Навигация между панелями' && \
               echo '  tls           - Список сессий tmux'"
# =============================================
# HOOK для Powerlevel10k: вывод после инициализации
# =============================================

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export TERMINAL=footclient
export CC=clang
export CXX=clang++
export PATH="$HOME/go/bin:$PATH"
