# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
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

# Автоматическая отправка текущей директории в Neovim через OSC 7
precmd() { printf "\033]7;file://%s%s\033\\" "${HOSTNAME}" "$(pwd)" }

# Функция для активации venv
activate_project_venv() {
    local project_path="$1"
    local venv_candidates=(
        "$project_path/venv"
        "$project_path/.venv"
        "$project_path/env"
    )

    for venv_path in "${venv_candidates[@]}"; do
        local activate_script="$venv_path/bin/activate"
        if [ -f "$activate_script" ]; then
            source "$activate_script"
            echo "✅ Активирован venv: $(basename "$venv_path")"
            return 0
        fi
    done

    echo "ℹ️  Виртуальное окружение не найдено"
    return 1
}

# Функция 1: Автоматический запуск tmux с проектом (ИСПРАВЛЕННАЯ)
nvim-project() {
    # Если передан аргумент - переходим в папку
    if [ -n "$1" ]; then
        if [ -d "$1" ]; then
            cd "$1" || return 1
        else
            echo "❌ Ошибка: Директория '$1' не существует"
            return 1
        fi
    fi

    # Запускаем tmux сессию с именем проекта
    local session_name=$(basename "$(pwd)")
    local project_path="$(pwd)"

    echo "🔄 Настраиваю проект: $session_name"
    echo "📁 Путь: $project_path"

    # Проверяем, есть ли уже сессия
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "🆕 Создаю новую tmux сессию: $session_name"

        # КЛЮЧЕВОЕ ИЗМЕНЕНИЕ 1: Создаём сессию БЕЗ запуска nvim внутри
        tmux new-session -d -s "$session_name" -c "$project_path" -n "main"

        # КЛЮЧЕВОЕ ИЗМЕНЕНИЕ 2: Даём сессии время на полную инициализацию
        sleep 0.5

        # КЛЮЧЕВОЕ ИЗМЕНЕНИЕ 3: Создаём панели через скрипт, передав ему ID сессии
        # Скрипт теперь сам запустит nvim после создания всех панелей
        ~/.config/tmux/create_panes.sh "$session_name" "main" "1"

        # Активируем venv для Neovim если есть (теперь через скрипт)
        if activate_project_venv "$project_path"; then
            echo "✅ Виртуальное окружение будет активировано в Neovim"
        fi

    else
        echo "ℹ️  Сессия '$session_name' уже существует"
    fi

    # Подключаемся к сессии
    echo "📌 Присоединяюсь к сессии: $session_name"
    echo "💡 Используйте Ctrl+A P для пересоздания панелей если нужно"
    tmux attach-session -t "$session_name"
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

# Справка
alias np-help="echo '📚 КОМАНДЫ NEOVIM+TMUX:' && \
               echo '  np [папка]    - Создать/присоединиться к проекту' && \
               echo '  npp           - Добавить панели в текущую сессию' && \
               echo '  Ctrl+A P      - Создать панели (изнутри tmux)' && \
               echo '  Ctrl+A |      - Разделить панель вертикально' && \
               echo '  Ctrl+A -      - Разделить панель горизонтально' && \
               echo '  Ctrl+A h/j/k/l - Навигация между панелями' && \
               echo '  tls           - Список сессий tmux'"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export TERMINAL=footclient
export CC=clang
export CXX=clang++
export CLIENT_PATH="/home/gennady/Hellgarve_Legion_Full_Client"
export CLIENT_PATH="/home/gennady/PortProton/prefixes/DOTNET/drive_c/Games/CircleLeg"
export CLIENT_PATH="/home/gennady/Hellgarve_Legion_Full_Client"
export CLIENT_PATH="/home/gennady/PortProton/prefixes/DOTNET/drive_c/Games/WOW"
