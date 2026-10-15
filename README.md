<div align="center">

# 🖼️ Random Wallpaper

**Рандомные обои для Windows и Linux без прав администратора.**
Кидает случайную картинку из `wallpapers/` в случайную папку на **локальном** диске
и ставит её как обои. Ведёт лог с HWID, временем и железом.

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue?style=flat-square)](#-поддерживаемые-системы)
[![Root](https://img.shields.io/badge/root-не%20требуется-success?style=flat-square)](#-почему-безопасно)
[![Shell](https://img.shields.io/badge/shell-batch%20%7C%20bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](#-файлы)
[![License](https://img.shields.io/badge/license-MIT-yellow?style=flat-square)](#-лицензия)

</div>

---

## 📖 Что это

Четыре скрипта — два под Windows (`.bat`), два под Linux (`.sh`).
Каждый запуск:

1. Берёт случайную картинку из `./wallpapers/`
2. Выбирает случайный **локальный** диск (USB, флешки и сетевые шары отсеиваются)
3. Копирует туда картинку под уникальным именем
4. Ставит её как обои через нативные API системы
5. Пишет строку в `wallpaper-log.txt` — время, HWID, имя ПК, железо, путь

Никакого `sudo`, никакого UAC, никаких драйверов.

---

## ✨ Возможности

- 🎲 **Случайный выбор** картинки и диска
- 🚫 **Без root/admin** — пишет только туда, куда юзер и так имеет доступ
- 💾 **Только локальные диски** — съёмники отсеиваются через `DriveType=3` (Win) и `/sys/block/*/removable` (Linux)
- 🔄 **Работает повторно** — уникальные имена файлов, чтобы ОС видела изменение
- 🪟 **Тихий режим** — silent-версии прячутся в фон (Windows) / молчат (Linux)
- 🧾 **Лог с HWID** — стабильный отпечаток железа (CPU, MB, BIOS, диски, RAM, MAC, GPU)
- 🖥️ **Универсальность Linux** — GNOME, KDE, Cinnamon, MATE, XFCE, Hyprland, Sway, feh, nitrogen, swaybg
- 🗑️ **Автоочистка** — старые копии удаляются, не копится мусор
- 🕵️ **Скрытая папка** — `attrib +h` на Windows, `.random-wallpaper-<user>` на Linux

---

## 📁 Файлы

| Файл | ОС | Режим |
|------|----|----|
| `wallpaper-visible.bat` | Windows | Показывает окно и лог |
| `wallpaper-silent.bat`  | Windows | Тихий, для автозапуска |
| `wallpaper-visible.sh`  | Linux   | Показывает окно и лог |
| `wallpaper-silent.sh`   | Linux   | Тихий, для cron/systemd |

---

## 🚀 Установка

### Структура папки

```
random-wallpaper/
├── wallpaper-visible.bat
├── wallpaper-silent.bat
├── wallpaper-visible.sh
├── wallpaper-silent.sh
├── wallpapers/
│   ├── 1.jpg
│   ├── 2.png
│   └── ...
└── wallpaper-log.txt   ← создастся автоматически
```

### Windows

1. Скачай `.bat` файлы
2. Положи рядом папку `wallpapers/` с картинками (`jpg`, `jpeg`, `png`, `webp`, `bmp`)
3. Дважды кликни `wallpaper-visible.bat` — увидишь, что происходит
4. Для автозапуска — добавь `wallpaper-silent.bat` в:
   - `Win+R` → `shell:startup` (автозагрузка при входе), или
   - Планировщик задач (Task Scheduler) — триггер «при входе в систему»

### Linux

```bash
chmod +x wallpaper-silent.sh wallpaper-visible.sh

# для теста
./wallpaper-visible.sh

# для автозапуска — cron (каждые 30 минут)
crontab -e
# добавить строку:
# */30 * * * * /home/user/random-wallpaper/wallpaper-silent.sh
```

Или через `systemd --user`:

```ini
# ~/.config/systemd/user/random-wallpaper.service
[Unit]
Description=Random Wallpaper

[Service]
Type=oneshot
ExecStart=%h/random-wallpaper/wallpaper-silent.sh
```

```bash
# ~/.config/systemd/user/random-wallpaper.timer
[Unit]
Description=Random Wallpaper Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target
```

```bash
systemctl --user enable --now random-wallpaper.timer
```

---

## 🖥️ Поддерживаемые системы

### Windows

- Windows 10 / 11
- Любой пользовательский аккаунт (без администратора)

### Linux (DE / WM)

| Окружение | Способ установки |
|-----------|------------------|
| GNOME / Unity / Budgie / Pantheon | `gsettings` |
| KDE Plasma | `qdbus` / `qdbus6` |
| Cinnamon | `gsettings` |
| MATE | `gsettings` |
| XFCE | `xfconf-query` |
| Hyprland | `hyprpaper` / `swww` |
| Sway | `swaymsg` |
| Любой X11 | `feh` / `nitrogen` |
| Любой Wayland | `swaybg` |

Дистрибутивы: **любые** — Debian, Ubuntu, Arch, Fedora, openSUSE, Mint, Manjaro, Gentoo, Alpine…

---

## 📋 Лог (`wallpaper-log.txt`)

Каждый запуск добавляет одну строку:

```
[2026-10-15 14:32:01] HWID=A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0 PC=DESKTOP-XYZ CPU=Intel(R) Core(TM) i7-9700K MB=ASUS PRIME Z390-A | C:\Users\user\.random-wallpaper-user\random-wallpaper-12345-67890.jpg
```

### Что такое HWID

**HWID** — стабильный отпечаток железа, SHA256-хеш от:

**Windows:**
- CPU (name + ProcessorId)
- Материнка (vendor + product + serial)
- BIOS (serial + version)
- Все диски (model + serial + size)
- GPU (name + DeviceID)
- Все модули RAM (part + serial + capacity)
- Все MAC-адреса активных адаптеров
- `MachineGuid`
- Windows `ProductId`

**Linux:**
- `/etc/machine-id`
- `product_uuid`, `board_serial`, `product_serial`
- `sys_vendor`, `product_name`
- BIOS version
- Серийники всех дисков (SD / NVMe / virtio / mmcblk)
- Все MAC-адреса (кроме нулевых)
- CPU model name

**HWID не меняется** между запусками на одном железе. Меняется при:
- переустановке ОС (сбрасывается `machine-id` / `MachineGuid`)
- замене материнки
- замене первого диска (Windows)

> ⚠️ **Это не античит-стиль HWID.** Настоящие античиты используют kernel-mode драйверы, TPM attestation и server-side валидацию. Здесь — user-mode, локальный хеш. Для идентификации машины в логе — более чем.

---

## 🔒 Почему безопасно

- **Без root/sudo/admin** — скрипты работают в правах обычного пользователя
- **Пишут только в свои папки** — `~/.cache/` или `<disk>/.random-wallpaper-<user>/`
- **Не трогают систему** — не меняют конфиги за пределами «обоев», не ставят службы
- **Не качают ничего из интернета** — работают полностью локально
- **Открытый код** — читай, форкай, меняй

---

## ⚙️ Как это работает

### Windows

1. `Get-CimInstance Win32_LogicalDisk` → список дисков с `DriveType=3` (fixed)
2. Случайный выбор → `<drive>:\.random-wallpaper-<user>\`
3. Копирование под именем `random-wallpaper-<rand>-<rand>.<ext>`
4. `reg add HKCU\Control Panel\Desktop /v Wallpaper` — путь в реестр
5. `SystemParametersInfo(SPI_SETDESKWALLPAPER, ...)` через P/Invoke из PowerShell — мгновенное обновление без перелогина

### Linux

1. `findmnt` + `/sys/block/*/removable` → список локальных точек монтирования
2. Случайный выбор → `~/.cache/random-wallpaper/` или `<mount>/.random-wallpaper-$USER/`
3. Копирование под уникальным именем
4. Определение DE через `XDG_CURRENT_DESKTOP` / `DESKTOP_SESSION`
5. Установка через нативный API DE + fallback (feh → nitrogen → swaybg)

---

## 🐛 Известные проблемы

**Обои не меняются после первого раза**
→ Раньше была такая бага — имя файла всегда было одинаковым, ОС думала "то же самое". Сейчас имя уникальное (`-<rand>-<rand>`), работает каждый раз.

**Windows: обои не появляются до перелогина**
→ Замени `RUNDLL32` на `SystemParametersInfo` (уже сделано в актуальной версии).

**Linux: не находит локальный диск**
→ Если у тебя один диск и `/` — это нормально, будет использован `~/.cache/random-wallpaper/`. Если у тебя LVM/btrfs subvol — `/sys/block/*/removable` может не сработать, добавь точку монтирования вручную в `CANDIDATES`.

**Хочу, чтобы одна и та же картинка не повторялась**
→ Пока не реализовано. Скажи в Issues — добавлю state-файл с последним выбором.

---

## 🤝 Вклад

PR-ы приветствуются. Что можно добавить:

- [ ] State-файл — не повторять последние N картинок
- [ ] Периодическое переключение по таймеру (внутри скрипта)
- [ ] Поддержка macOS (`osascript` + `sqlite3` для `desktoppicture.db`)
- [ ] Опциональный режим «только указанные папки»
- [ ] GUI-обёртка (Tkinter / Electron)

Форкай, добавляй, шли Pull Request.

---

## 📜 Лицензия

MIT — делай что хочешь, только не удивляйся, если что-то сломается. См. `LICENSE`.

---

<div align="center">

**Сделано с ❤️ и без единого `sudo`**

</div>
