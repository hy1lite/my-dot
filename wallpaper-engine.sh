#!/bin/bash

# Конфигурация
WALLPAPER_ENGINE_BIN="linux-wallpaperengine"
WORKSHOP_DIRS=(
    "$HOME/.steam/steam/steamapps/workshop/content/431960"
    "$HOME/.local/share/Steam/steamapps/workshop/content/431960"
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/workshop/content/431960"
    "$HOME/snap/steam/common/.local/share/Steam/steamapps/workshop/content/431960"
)

# Файлы состояния
STATE_DIR="$HOME/.config/hypr/wallpaper-engine"
CURRENT_WALLPAPER_FILE="$STATE_DIR/current_wallpaper.txt"
WALLPAPERS_LIST_FILE="$STATE_DIR/wallpapers.txt"

# Создать директорию состояния если не существует
mkdir -p "$STATE_DIR"

# Проверить установку linux-wallpaperengine
check_installation() {
    if ! command -v "$WALLPAPER_ENGINE_BIN" &> /dev/null; then
        if command -v notify-send &> /dev/null; then
            notify-send "Wallpaper Engine" "linux-wallpaperengine not found! Install via: yay -S linux-wallpaperengine-git" -t 5000
        fi
        echo "Error: linux-wallpaperengine not found!"
        exit 1
    fi
}

# Найти Workshop директорию
find_workshop_dir() {
    for dir in "${WORKSHOP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# Получить список всех wallpaper'ов (Workshop ID)
get_wallpapers() {
    local workshop_dir
    workshop_dir=$(find_workshop_dir)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Steam Workshop directory not found!"
        if command -v notify-send &> /dev/null; then
            notify-send "Wallpaper Engine" "Steam Workshop directory not found! Make sure Wallpaper Engine is installed via Steam." -t 5000
        fi
        exit 1
    fi
    
    # Найти все директории с project.json (валидные wallpaper'ы)
    find "$workshop_dir" -mindepth 1 -maxdepth 1 -type d | while read -r wallpaper_dir; do
        if [[ -f "$wallpaper_dir/project.json" ]]; then
            wallpaper_id=$(basename "$wallpaper_dir")
            echo "$wallpaper_id"
        fi
    done | sort -n
}

# Получить текущий wallpaper
get_current_wallpaper() {
    if [[ -f "$CURRENT_WALLPAPER_FILE" ]]; then
        cat "$CURRENT_WALLPAPER_FILE"
    else
        echo ""
    fi
}

# Остановить текущий wallpaper
stop_current_wallpaper() {
    # Убить все процессы linux-wallpaperengine
    pkill -f "$WALLPAPER_ENGINE_BIN" 2>/dev/null
    sleep 0.5
}

# Установить wallpaper
set_wallpaper() {
    local wallpaper_id="$1"
    local silent_mode="$2"
    
    stop_current_wallpaper
    
    # Определить основной монитор (замените на ваш монитор)
    local monitor="HDMI-A-1"  # Замените на ваш монитор из hyprctl monitors
    
    # Построить команду
    local cmd="$WALLPAPER_ENGINE_BIN --screen-root $monitor"
    
    # Добавить silent режим если нужно
    if [[ "$silent_mode" == "silent" ]]; then
        cmd="$cmd --silent"
    fi
    
    # Добавить ID wallpaper'а
    cmd="$cmd $wallpaper_id"
    
    # Запустить новый wallpaper в фоне
    nohup $cmd > /dev/null 2>&1 &
    
    # Сохранить текущий wallpaper
    echo "$wallpaper_id" > "$CURRENT_WALLPAPER_FILE"
    
    # Уведомление
    if command -v notify-send &> /dev/null; then
        notify-send "Wallpaper Engine" "Switched to wallpaper: $wallpaper_id" -t 2000 -i applications-multimedia
    fi
    
    echo "Wallpaper set to: $wallpaper_id"
}

# Обновить список wallpaper'ов
update_wallpapers_list() {
    echo "Scanning for wallpapers..."
    get_wallpapers > "$WALLPAPERS_LIST_FILE"
    local count=$(wc -l < "$WALLPAPERS_LIST_FILE")
    echo "Found $count wallpapers"
}

# Главная функция
main() {
    local mode="$1"
    
    check_installation
    
    case "$mode" in
        "--random"|"-r")
            # Случайный wallpaper
            update_wallpapers_list
            if [[ ! -s "$WALLPAPERS_LIST_FILE" ]]; then
                echo "No wallpapers found!"
                exit 1
            fi
            
            local random_wallpaper
            random_wallpaper=$(shuf -n 1 "$WALLPAPERS_LIST_FILE")
            set_wallpaper "$random_wallpaper" "silent"
            ;;
            
        "--next"|"-n"|"")
            # Следующий wallpaper (по умолчанию)
            update_wallpapers_list
            if [[ ! -s "$WALLPAPERS_LIST_FILE" ]]; then
                echo "No wallpapers found!"
                exit 1
            fi
            
            local current_wallpaper
            current_wallpaper=$(get_current_wallpaper)
            
            local wallpapers
            mapfile -t wallpapers < "$WALLPAPERS_LIST_FILE"
            
            if [[ ${#wallpapers[@]} -eq 0 ]]; then
                echo "No wallpapers available!"
                exit 1
            fi
            
            # Найти индекс текущего wallpaper'а
            local current_index=-1
            for i in "${!wallpapers[@]}"; do
                if [[ "${wallpapers[$i]}" == "$current_wallpaper" ]]; then
                    current_index=$i
                    break
                fi
            done
            
            # Выбрать следующий
            local next_index
            if [[ $current_index -eq -1 ]] || [[ $current_index -eq $((${#wallpapers[@]} - 1)) ]]; then
                next_index=0
            else
                next_index=$((current_index + 1))
            fi
            
            set_wallpaper "${wallpapers[$next_index]}" "silent"
            ;;
            
        "--stop"|"-s")
            # Остановить wallpaper
            stop_current_wallpaper
            echo "" > "$CURRENT_WALLPAPER_FILE"
            if command -v notify-send &> /dev/null; then
                notify-send "Wallpaper Engine" "Wallpaper stopped" -t 2000
            fi
            echo "Wallpaper stopped"
            ;;
            
        "--list"|"-l")
            # Показать список wallpaper'ов
            update_wallpapers_list
            echo "Available wallpapers:"
            cat "$WALLPAPERS_LIST_FILE"
            ;;
            
        "--current"|"-c")
            # Показать текущий wallpaper
            local current
            current=$(get_current_wallpaper)
            if [[ -n "$current" ]]; then
                echo "Current wallpaper: $current"
            else
                echo "No wallpaper is currently set"
            fi
            ;;
            
        --id=*)
            # Установить конкретный wallpaper по ID
            local wallpaper_id="${mode#--id=}"
            set_wallpaper "$wallpaper_id" "silent"
            ;;
            
        "--help"|"-h")
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --next, -n      Switch to next wallpaper (default)"
            echo "  --random, -r    Switch to random wallpaper"
            echo "  --stop, -s      Stop current wallpaper"
            echo "  --list, -l      List all available wallpapers"
            echo "  --current, -c   Show current wallpaper"
            echo "  --id=ID         Set specific wallpaper by Workshop ID"
            echo "  --help, -h      Show this help"
            echo ""
            echo "Examples:"
            echo "  $0              # Next wallpaper"
            echo "  $0 --random     # Random wallpaper"
            echo "  $0 --id=1845706469  # Specific wallpaper"
            ;;
            
        *)
            echo "Unknown option: $mode"
            echo "Use --help for available options"
            exit 1
            ;;
    esac
}

# Запуск скрипта
main "$@"
