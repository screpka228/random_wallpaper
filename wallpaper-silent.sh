#!/usr/bin/env bash
# wallpaper-silent.sh — тихая установка обоев. Без root.

exec >/dev/null 2>&1
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$SCRIPT_DIR/wallpapers"

[[ -d "$WALLPAPER_DIR" ]] || exit 1

mapfile -d '' WALLPAPERS < <(
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.webp' -o -iname '*.bmp' \) \
        -print0 2>/dev/null
)

(( ${#WALLPAPERS[@]} > 0 )) || exit 1

SELECTED="${WALLPAPERS[RANDOM % ${#WALLPAPERS[@]}]}"

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

declare -a CANDIDATES=("$HOME/.cache/random-wallpaper")

for mnt in "${LOCAL_MOUNTS[@]}"; do
    [[ -w "$mnt" ]] && CANDIDATES+=("$mnt/.random-wallpaper-$USER")
done

TARGET_DIR="${CANDIDATES[RANDOM % ${#CANDIDATES[@]}]}"

if ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
    TARGET_DIR="$HOME/.cache/random-wallpaper"
    mkdir -p "$TARGET_DIR" 2>/dev/null || exit 1
fi

EXT="${SELECTED##*.}"
EXT="${EXT,,}"

# Уникальное имя — чтобы gsettings/qdbus увидели изменение
TARGET_FILE="$TARGET_DIR/random-wallpaper-$RANDOM-$RANDOM.$EXT"

cp -- "$SELECTED" "$TARGET_FILE" || exit 1

TARGET_FILE="$(readlink -f "$TARGET_FILE" 2>/dev/null || \
               realpath "$TARGET_FILE" 2>/dev/null || echo "$TARGET_FILE")"
FILE_URI="file://$TARGET_FILE"

DE="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
DE_LC="${DE,,}"

# --- Cinnamon ---
case "$DE_LC" in
    *cinnamon*)
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.cinnamon.desktop.background picture-uri "$FILE_URI" 2>/dev/null && exit 0
        fi
        ;;
    *mate*)
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.mate.background picture-filename "$TARGET_FILE" 2>/dev/null && exit 0
        fi
        ;;
    *xfce*)
        if command -v xfconf-query >/dev/null 2>&1; then
            while IFS= read -r prop; do
                xfconf-query -c xfce4-desktop -p "$prop" -s "$TARGET_FILE" 2>/dev/null || true
            done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image')
            exit 0
        fi
        ;;
esac

# --- GNOME / Unity / Budgie / Pantheon ---
if command -v gsettings >/dev/null 2>&1 &&
   gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.desktop.background'; then
    gsettings set org.gnome.desktop.background picture-uri "$FILE_URI" || exit 1
    if gsettings list-keys org.gnome.desktop.background 2>/dev/null | grep -qx 'picture-uri-dark'; then
        gsettings set org.gnome.desktop.background picture-uri-dark "$FILE_URI"
    fi
    exit 0
fi

# --- KDE Plasma ---
if [[ "${XDG_CURRENT_DESKTOP:-}" =~ KDE|Plasma ]] ||
   [[ "${DESKTOP_SESSION:-}" =~ KDE|Plasma ]]; then
    if command -v qdbus6 >/dev/null 2>&1; then QDBUS="qdbus6"
    elif command -v qdbus >/dev/null 2>&1; then QDBUS="qdbus"
    else QDBUS=""; fi

    if [[ -n "$QDBUS" ]]; then
        SCRIPT="var ds=desktops(); for (var i=0;i<ds.length;i++) { ds[i].wallpaperPlugin='org.kde.image'; ds[i].currentConfigGroup=['Wallpaper','org.kde.image','General']; ds[i].writeConfig('Image','file://$TARGET_FILE'); }"
        "$QDBUS" org.kde.plasmashell /PlasmaShell \
            org.kde.PlasmaShell.evaluateScript "$SCRIPT" >/dev/null 2>&1 && exit 0
    fi
fi

# --- Hyprland ---
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] ||
   [[ "${XDG_CURRENT_DESKTOP:-}" =~ Hyprland ]]; then
    if command -v hyprctl >/dev/null 2>&1; then
        if command -v hyprpaper >/dev/null 2>&1; then
            hyprctl hyprpaper preload "$TARGET_FILE" >/dev/null 2>&1 || true
            hyprctl hyprpaper wallpaper ",$TARGET_FILE" >/dev/null 2>&1 || true
            exit 0
        fi
        if command -v swww >/dev/null 2>&1; then
            swww img "$TARGET_FILE" >/dev/null 2>&1 && exit 0
        fi
    fi
fi

# --- Sway ---
if [[ -n "${SWAYSOCK:-}" ]] ||
   [[ "${XDG_CURRENT_DESKTOP:-}" =~ Sway ]]; then
    if command -v swaymsg >/dev/null 2>&1; then
        swaymsg "output * bg \"$TARGET_FILE\" fill" >/dev/null 2>&1 && exit 0
    fi
fi

# --- Fallback ---
if command -v feh >/dev/null 2>&1; then
    feh --bg-fill "$TARGET_FILE" && exit 0
fi

if command -v nitrogen >/dev/null 2>&1; then
    nitrogen --set-zoom-fill "$TARGET_FILE" && exit 0
fi

if command -v swaybg >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    pkill -x swaybg 2>/dev/null || true
    setsid swaybg -i "$TARGET_FILE" -m fill >/dev/null 2>&1 &
    exit 0
fi

exit 1