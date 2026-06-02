#!/usr/bin/env bash
# install.sh — установка конфигов через симлинки
# Использование: ./install.sh [--force] [--dry-run]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Флаги
FORCE=false
DRY_RUN=false

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo "Использование: $0 [--force] [--dry-run]"
            echo "  --force   : Перезаписать существующие файлы"
            echo "  --dry-run : Показать, что будет сделано, без изменений"
            exit 0
            ;;
        *) echo "Неизвестный аргумент: $1"; exit 1 ;;
    esac
done

# Пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"
BACKUP_DIR="${HOME}/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Функция для создания симлинка
create_symlink() {
    local source="$1"
    local target="$2"
    local target_dir="$(dirname "$target")"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BLUE}[DRY-RUN]${NC} Создать симлинк: $source → $target"
        return 0
    fi

    # Создаём директорию назначения если нужно
    mkdir -p "$target_dir"

    # Если файл уже существует
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ "$FORCE" == true ]]; then
            echo -e "${YELLOW}⚠️  Бэкап:${NC} $target → $BACKUP_DIR"
            mkdir -p "$(dirname "$BACKUP_DIR${target#$HOME}")"
            cp -rf "$target" "$BACKUP_DIR${target#$HOME}" 2>/dev/null || true
            rm -rf "$target"
        else
            echo -e "${RED}✗ Пропущено:${NC} $target уже существует (используйте --force)"
            return 1
        fi
    fi

    # Создаём симлинк
    ln -sf "$source" "$target"
    echo -e "${GREEN}✓ Установлено:${NC} $target → $source"
}

# Основная логика
echo -e "${BLUE}🔧 Установка dotfiles из $SCRIPT_DIR${NC}"
echo "========================================"

# Проверяем, что мы в корне репозитория
if [[ ! -f "$SCRIPT_DIR/install.sh" ]]; then
    echo -e "${RED}❌ Запустите скрипт из корня репозитория dotfiles${NC}"
    exit 1
fi

# Создаём директорию для бэкапов если нужно
if [[ "$FORCE" == true && "$DRY_RUN" == false ]]; then
    mkdir -p "$BACKUP_DIR"
    echo -e "${YELLOW}📦 Бэкапы будут сохранены в: $BACKUP_DIR${NC}"
fi

# === Устанавливаем конфиги ===

# Tmux
create_symlink "$SCRIPT_DIR/.config/tmux/tmux.conf" "$HOME_DIR/.config/tmux/tmux.conf"
create_symlink "$SCRIPT_DIR/.config/tmux/create_panes.sh" "$HOME_DIR/.config/tmux/create_panes.sh"
chmod +x "$HOME_DIR/.config/tmux/create_panes.sh" 2>/dev/null || true

# Neovim
ln -sf ~/.dotfiles/.config/nvim/init.lua ~/.config/nvim/init.lua
ln -sf ~/.dotfiles/.config/nvim/lua ~/.config/nvim/lua
ln -sf ~/.dotfiles/.config/nvim/lazy-lock.json ~/.config/nvim/lazy-lock.json

# Zsh
create_symlink "$SCRIPT_DIR/.zshrc" "$HOME_DIR/.zshrc"

# === Завершение ===
echo ""
echo "========================================"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${BLUE}🔍 Dry-run завершён. Никакие файлы не изменены.${NC}"
    echo "Запустите без --dry-run для реальной установки."
else
    echo -e "${GREEN}✅ Установка завершена!${NC}"
    echo ""
    echo "📋 Следующие шаги:"
    echo "  1. Перезапустите терминал или: source ~/.zshrc"
    echo "  2. Запустите: nvim (плагины установятся автоматически)"
    echo "  3. Для tmux: tmux kill-server && tmux"
    echo ""
    echo "🔧 Полезные команды:"
    echo "  • Обновить конфиги:  ./install.sh --force"
    echo "  • Проверить без изменений: ./install.sh --dry-run"
    echo "  • Восстановить бэкап:  cp -r ~/.dotfiles_backup_*/* ~/.config/"
fi
