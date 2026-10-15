#!/usr/bin/env bash
# wallpaper-visible.sh — установка обоев с выводом. Без root.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$SCRIPT_DIR/wallpapers"

echo "=========================================="
echo "        RANDOM WALLPAPER"
echo "=========================================="
echo
echo "Папка со скриптом: $SCRIPT_DIR"
echo "Папка с обоями:    $WALLPAPER_DIR"
echo

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    echo "ОШИБКА: папка wallpapers не найдена."
    read -rp "Нажми Enter для выхода..." _
    exit 1
fi

mapfile -d '' WALLPAPERS < <(
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.webp' -o -iname '*.bmp' \) \
        -print0 2>/dev/null
)

if (( ${#WALLPAPERS[@]} == 0 )); then
    echo "ОШИБКА: в wallpapers нет изображений."
    read -rp "Нажми Enter для выхода..." _
    exit 1
fi

SELECTED="${WALLPAPERS[RANDOM % ${#WALLPAPERS[@]}]}"

echo "Найдено изображений: ${#WALLPAPERS[@]}"
echo "Выбрано: $(basename "$SELECTED")"
echo

echo "Сканирую локальные диски..."
declare -a LOCAL_MOUNTS=()

if command -v findmnt >/dev/null 2>&1; then
    while read -r mnt dev fstype; do
        [[ -z "$mnt" || -z "$dev" ]] && continue
        [[ "$dev" != /dev/* ]] && continue

        case "$fstype" in
            tmpfs|devtmpfs|squashfs|iso9660|overlay|proc|sysfs|cgroup|cgroup2|\
            nfs|nfs4|cifs|smb3|autofs|fuse*|ramfs|efivarfs) continue ;;
        esac

        pkname="$(lsblk -no PKNAME "$dev" 2>/dev/null | head -n1)"
        [[ -z "$pkname" ]] && pkname="$(basename "$dev" | sed 's/[0-9]*$//')"

        if [[ -r "/sys/block/$pkname/removable" ]]; then
            [[ "$(cat "/sys/block/$pkname/removable" 2>/dev/null)" == "1" ]] && continue
        fi

        LOCAL_MOUNTS+=("$mnt")
    done < <(findmnt -rn -o TARGET,SOURCE,FSTYPE 2>/dev/null)
fi

(( ${#LOCAL_MOUNTS[@]} > 0 )) || LOCAL_MOUNTS=("/")

echo "Найдено локальных точек монтирования: ${#LOCAL_MOUNTS[@]}"
for m in "${LOCAL_MOUNTS[@]}"; do echo "  - $m"; done
echo

declare -a CANDIDATES=("$HOME/.cache/random-wallpaper")
for mnt in "${LOCAL_MOUNTS[@]}"; do
    [[ -w "$mnt" ]] && CANDIDATES+=("$mnt/.random-wallpaper-$USER")
done

TARGET_DIR="${CANDIDATES[RANDOM % ${#CANDIDATES[@]}]}"

echo "Кандидатов: ${#CANDIDATES[@]}"
for c in "${CANDIDATES[@]}"; do echo "  - $c"; done
echo "Выбрано: $TARGET_DIR"
echo

if ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
    TARGET_DIR="$HOME/.cache/random-wallpaper"
    mkdir -p "$TARGET_DIR" 2>/dev/null || {
        echo "ОШИБКА: не удалось создать папку."
        read -rp "Нажми Enter..." _
        exit 1
    }
fi

EXT="${SELECTED##*.}"
EXT="${EXT,,}"

TARGET_FILE="$TARGET_DIR/random-wallpaper-$RANDOM-$RANDOM.$EXT"

if ! cp -- "$SELECTED" "$TARGET_FILE"; then
    echo "ОШИБКА: не удалось скопировать."
    read -rp "Нажми Enter..." _
    exit 1
fi

TARGET_FILE="$(readlink -f "$TARGET_FILE" 2>/dev/null || \
               realpath "$TARGET_FILE" 2>/dev/null || echo "$TARGET_FILE")"
FILE_URI="file://$TARGET_FILE"

echo "Файл установлен: $TARGET_FILE"
echo

DE="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
DE_LC="${DE,,}"
echo "DE: ${DE:-неизвестно}"
echo

DONE=0

if (( ! DONE )) && [[ "$DE_LC" == *cinnamon* ]]; then
    if command -v gsettings >/dev/null 2>&1 &&
       gsettings set org.cinnamon.desktop.background picture-uri "$FILE_URI" 2>/dev/null; then
        echo "OK: Cinnamon"; DONE=1
    fi
fi

if (( ! DONE )) && [[ "$DE_LC" == *mate* ]]; then
    if command -v gsettings >/dev/null 2>&1 &&
       gsettings set org.mate.background picture-filename "$TARGET_FILE" 2>/dev/null; then
        echo "OK: MATE"; DONE=1
    fi
fi

if (( ! DONE )) && [[ "$DE_LC" == *xfce* ]]; then
    if command -v xfconf-query >/dev/null 2>&1; then
        while IFS= read -r prop; do
            xfconf-query -c xfce4-desktop -p "$prop" -s "$TARGET_FILE" 2>/dev/null || true
        done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image')
        echo "OK: XFCE"; DONE=1
    fi
fi

if (( ! DONE )) && command -v gsettings >/dev/null 2>&1 &&
   gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.desktop.background'; then
    if gsettings set org.gnome.desktop.background picture-uri "$FILE_URI"; then
        if gsettings list-keys org.gnome.desktop.background 2>/dev/null | grep -qx 'picture-uri-dark'; then
            gsettings set org.gnome.desktop.background picture-uri-dark "$FILE_URI"
        fi
        echo "OK: GNOME-совместимое"; DONE=1
    fi
fi

if (( ! DONE )); then
    if [[ "${XDG_CURRENT_DESKTOP:-}" =~ KDE|Plasma ]] ||
       [[ "${DESKTOP_SESSION:-}" =~ KDE|Plasma ]]; then
        if command -v qdbus6 >/dev/null 2>&1; then QDBUS="qdbus6"
        elif command -v qdbus >/dev/null 2>&1; then QDBUS="qdbus"
        else QDBUS=""; fi

        if [[ -n "$QDBUS" ]]; then
            SCRIPT="var ds=desktops(); for (var i=0;i<ds.length;i++) { ds[i].wallpaperPlugin='org.kde.image'; ds[i].currentConfigGroup=['Wallpaper','org.kde.image','General']; ds[i].writeConfig('Image','file://$TARGET_FILE'); }"
            if "$QDBUS" org.kde.plasmashell /PlasmaShell \
                org.kde.PlasmaShell.evaluateScript "$SCRIPT" >/dev/null 2>&1; then
                echo "OK: KDE Plasma"; DONE=1
            fi
        fi
    fi
fi

if (( ! DONE )) && { [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] ||
                     [[ "${XDG_CURRENT_DESKTOP:-}" =~ Hyprland ]]; }; then
    if command -v hyprctl >/dev/null 2>&1; then
        if command -v hyprpaper >/dev/null 2>&1; then
            hyprctl hyprpaper preload "$TARGET_FILE" >/dev/null 2>&1 || true
            hyprctl hyprpaper wallpaper ",$TARGET_FILE" >/dev/null 2>&1 || true
            echo "OK: Hyprland/hyprpaper"; DONE=1
        elif command -v swww >/dev/null 2>&1; then
            if swww img "$TARGET_FILE" >/dev/null 2>&1; then
                echo "OK: Hyprland/swww"; DONE=1
            fi
        fi
    fi
fi

if (( ! DONE )) && { [[ -n "${SWAYSOCK:-}" ]] ||
                     [[ "${XDG_CURRENT_DESKTOP:-}" =~ Sway ]]; }; then
    if command -v swaymsg >/dev/null 2>&1; then
        if swaymsg "output * bg \"$TARGET_FILE\" fill" >/dev/null 2>&1; then
            echo "OK: Sway"; DONE=1
        fi
    fi
fi

if (( ! DONE )) && command -v feh >/dev/null 2>&1; then
    if feh --bg-fill "$TARGET_FILE"; then echo "OK: feh"; DONE=1; fi
fi

if (( ! DONE )) && command -v nitrogen >/dev/null 2>&1; then
    if nitrogen --set-zoom-fill "$TARGET_FILE"; then echo "OK: nitrogen"; DONE=1; fi
fi

if (( ! DONE )) && command -v swaybg >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    pkill -x swaybg 2>/dev/null || true
    setsid swaybg -i "$TARGET_FILE" -m fill >/dev/null 2>&1 &
    echo "OK: swaybg (Wayland)"; DONE=1
fi

echo
if (( DONE )); then
    echo "=========================================="
    echo "              ГОТОВО!"
    echo "=========================================="
    echo "Файл: $TARGET_FILE"
else
    echo "Не удалось автоматически установить обои."
    echo "Файл всё равно здесь: $TARGET_FILE"
    echo
    echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-неизвестно}"
    echo "DESKTOP_SESSION=${DESKTOP_SESSION:-неизвестно}"
fi
echo
read -rp "Нажми Enter для выхода..." _
(( DONE )) && exit 0 || exit 1