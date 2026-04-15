#!/usr/bin/env bash
# uninstall.sh — удаление симлинков и восстановление оригиналов

set -e

echo "⚠️  Это удалит симлинки и восстановит оригинальные файлы (если есть бэкап)"
read -p "Продолжить? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Отменено."
    exit 0
fi

# Удаляем симлинки
for file in \
    "$HOME/.config/tmux/tmux.conf" \
    "$HOME/.config/tmux/create_panes.sh" \
    "$HOME/.config/nvim/init.lua" \
    "$HOME/.config/nvim/lazy-lock.json" \
    "$HOME/.zshrc"
do
    if [[ -L "$file" ]]; then
        rm "$file"
        echo "✓ Удалён симлинк: $file"
    elif [[ -f "$file" ]]; then
        echo "⚠  Не симлинк (пропущено): $file"
    fi
done

echo "✅ Готово. Оригинальные файлы не затронуты."
echo "💡 Чтобы восстановить из бэкапа: cp -r ~/.dotfiles_backup_*/.config/tmux ~/.config/"
