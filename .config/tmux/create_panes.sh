#!/bin/bash
# ИСПРАВЛЕННЫЙ скрипт для добавления панелей
# Принимает аргументы: [сессия] [окно] [панель] (опционально)

# Если переданы аргументы, используем их. Иначе берем из текущего контекста.
if [ $# -eq 3 ]; then
    SESSION="$1"
    WINDOW="$2"
    CURRENT_PANE="$3"
    PROJECT_PATH=$(tmux display-message -t "$SESSION:$WINDOW.$CURRENT_PANE" -p '#{pane_current_path}')
else
    SESSION=$(tmux display-message -p '#S')
    WINDOW=$(tmux display-message -p '#I')
    CURRENT_PANE=$(tmux display-message -p '#P')
    PROJECT_PATH=$(tmux display-message -p '#{pane_current_path}')
fi

echo "Использую сессию: $SESSION, окно: $WINDOW, панель: $CURRENT_PANE"

# Функция для поиска и активации venv
activate_venv() {
    local path="$1"
    local venv_candidates=(
        "$path/venv"
        "$path/.venv"
        "$path/env"
    )

    for venv_path in "${venv_candidates[@]}"; do
        local activate_script="$venv_path/bin/activate"
        if [ -f "$activate_script" ]; then
            echo "source \"$activate_script\""
            return 0
        fi
    done
    return 1
}

# 1. ПЕРВЫМ ДЕЛОМ: создаём терминальную панель (20% высоты)
tmux split-window -t "$SESSION:$WINDOW.$CURRENT_PANE" -v -p 20 -c "$PROJECT_PATH"
TERMINAL_PANE=$(tmux display-message -t "$SESSION:$WINDOW" -p '#P')

# 2. Настраиваем терминальную панель
tmux send-keys -t "$SESSION:$WINDOW.$TERMINAL_PANE" "clear && echo '=== ТЕРМИНАЛ ==='" C-m
tmux send-keys -t "$SESSION:$WINDOW.$TERMINAL_PANE" "cd \"$PROJECT_PATH\"" C-m

# Активируем venv в терминале если есть
VENV_CMD=$(activate_venv "$PROJECT_PATH")
if [ $? -eq 0 ]; then
    tmux send-keys -t "$SESSION:$WINDOW.$TERMINAL_PANE" "$VENV_CMD" C-m
    tmux send-keys -t "$SESSION:$WINDOW.$TERMINAL_PANE" "echo '✅ Venv активирован'" C-m
fi
tmux send-keys -t "$SESSION:$WINDOW.$TERMINAL_PANE" "echo 'Путь: $PROJECT_PATH'" C-m
tmux send-keys -t "$SESSION:$WINDOW.$TERMINAL_PANE" "echo ''" C-m

# 3. Возвращаем фокус на исходную панель (для Neovim)
tmux select-pane -t "$SESSION:$WINDOW.$CURRENT_PANE"

# 4. Даём системе успокоиться после изменения размеров
sleep 0.3

# 5. ТОЛЬКО ТЕПЕРЬ проверяем и запускаем Neovim в панели финального размера
if ! tmux list-panes -t "$SESSION:$WINDOW" -F '#{pane_current_command}' | grep -q nvim; then
    tmux send-keys -t "$SESSION:$WINDOW.$CURRENT_PANE" "cd \"$PROJECT_PATH\" && nvim" C-m
    sleep 0.5

    # Активируем venv для Neovim если есть
    VENV_CMD=$(activate_venv "$PROJECT_PATH")
    if [ $? -eq 0 ]; then
        # Ждём, пока Neovim полностью загрузится
        sleep 1
        tmux send-keys -t "$SESSION:$WINDOW.$CURRENT_PANE" ":lua Tmux.activate_venv('$PROJECT_PATH')" C-m
    fi
fi

echo "✅ Панели настроены, Neovim запущен."
