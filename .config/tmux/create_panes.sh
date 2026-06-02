#!/bin/bash
# ИСПРАВЛЕННЫЙ скрипт для добавления панелей

# Если переданы аргументы (от внешнего скрипта), используем их. Иначе берем из текущего контекста.
if [ $# -eq 3 ]; then
    SESSION="$1"
    WINDOW="$2"
    CURRENT_PANE="$3"
    PROJECT_PATH=$(tmux display-message -t "=$SESSION:$WINDOW.$CURRENT_PANE" -p '#{pane_current_path}' 2>/dev/null || echo "$PWD")
else
    SESSION=$(tmux display-message -p '#S')
    WINDOW=$(tmux display-message -p '#I')
    CURRENT_PANE=$(tmux display-message -p '#P')
    PROJECT_PATH=$(tmux display-message -p '#{pane_current_path}')
fi

# Функция для поиска venv
activate_venv() {
    local path="$1"
    local venv_candidates=(
        "$path/venv"
        "$path/.venv"
        "$path/env"
    )
    for venv_path in "${venv_candidates[@]}"; do
        if [ -f "$venv_path/bin/activate" ]; then
            echo "source '$venv_path/bin/activate'"
            return 0
        fi
    done
    return 1
}

# 1. Создаём терминальную панель (20% высоты)
# Используем знак = перед сессией, чтобы Tmux не путал точку в имени с разделителем окна.панели
tmux split-window -t "=$SESSION:$WINDOW.$CURRENT_PANE" -v -p 20 -c "$PROJECT_PATH"
TERMINAL_PANE=$(tmux display-message -t "=$SESSION:$WINDOW" -p '#P')

# 2. Настраиваем терминальную панель
tmux send-keys -t "=$SESSION:$WINDOW.$TERMINAL_PANE" "cd '$PROJECT_PATH'" C-m
VENV_CMD=$(activate_venv "$PROJECT_PATH")
if [ $? -eq 0 ]; then
    tmux send-keys -t "=$SESSION:$WINDOW.$TERMINAL_PANE" "$VENV_CMD" C-m
    tmux send-keys -t "=$SESSION:$WINDOW.$TERMINAL_PANE" "echo '✅ Venv активирован в терминале'" C-m
else
    tmux send-keys -t "=$SESSION:$WINDOW.$TERMINAL_PANE" "echo 'ℹ️  Виртуальное окружение не найдено'" C-m
fi
tmux send-keys -t "=$SESSION:$WINDOW.$TERMINAL_PANE" "clear && echo '=== ТЕРМИНАЛ ==='" C-m

# 3. Возвращаем фокус на исходную панель (для Neovim)
tmux select-pane -t "=$SESSION:$WINDOW.$CURRENT_PANE"
sleep 0.3

# 4. Запускаем Neovim с активированным venv (если есть)
if ! tmux list-panes -t "=$SESSION:$WINDOW" -F '#{pane_current_command}' | grep -q nvim; then
    START_CMD="cd '$PROJECT_PATH'"
    VENV_CMD=$(activate_venv "$PROJECT_PATH")
    if [ $? -eq 0 ]; then
        START_CMD="$START_CMD && $VENV_CMD"
    fi
    START_CMD="$START_CMD && nvim"
    
    tmux send-keys -t "=$SESSION:$WINDOW.$CURRENT_PANE" "$START_CMD" C-m
fi

echo "✅ Панели настроены, Neovim запущен."
