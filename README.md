# Phone Screen Mirror

Portable Windows package for automatically mirroring Android phone screens with
scrcpy.

## What This Does

- Watches for connected Android phones every 2 seconds.
- Starts a separate scrcpy mirror window for each new phone.
- Lets you choose video quality: Max, Mid, or Min.
- Saves the chosen quality in `quality.cfg` for next time.
- Keeps the phone screen awake while mirroring.
- Shows a warning if USB debugging is unauthorized.
- Creates `scrcpy-server` automatically from `scrcpy-server.zip` if missing.
- Writes scrcpy output/error logs into `logs/` for troubleshooting.

## Main Files

| File | Purpose |
| --- | --- |
| `auto-mirror-watch.bat` | Double-click launcher for the auto mirror watcher. |
| `auto-mirror-watch.ps1` | Main watcher script. |
| `update-from-git.bat` | Pull latest files from GitHub into this local folder. |
| `update-to-git.bat` | Commit and push local changes to GitHub. |
| `quality.cfg` | Saves the selected mirror quality. |
| `scrcpy.exe`, `adb.exe`, DLL files | Required scrcpy/ADB runtime files. |
| `scrcpy-server.zip` | Android-side scrcpy server package. |

## Requirements

- Windows PC.
- Android phone with USB debugging enabled.
- USB cable or a working ADB connection.
- Phone must accept the "Allow USB debugging" prompt.
- For Git update scripts: Git must be installed and the folder must be a real
  git clone, not just a GitHub "Download ZIP" folder.

## How To Mirror A Phone

1. Connect the Android phone to the PC.
2. Enable USB debugging on the phone.
3. Double-click `auto-mirror-watch.bat`.
4. Pick quality:
   - `1` = Max quality
   - `2` = Mid quality
   - `3` = Min quality
   - Press Enter to keep the saved quality
5. Allow USB debugging on the phone if prompted.
6. The scrcpy window should open automatically.

Keep the watcher window open. It will keep watching for newly connected phones.
Close the watcher window or press Ctrl+C to stop it.

## Quality Presets

| Preset | Size | Bitrate | FPS |
| --- | --- | --- | --- |
| Max | Native resolution | 16 Mbps | 60 |
| Mid | 1280 px max size | 8 Mbps | 60 |
| Min | 800 px max size | 4 Mbps | 30 |

## Git Sync Helpers

### Download latest changes from GitHub

Double-click:

```bat
update-from-git.bat
```

This runs:

```bat
git pull --rebase --autostash origin main
```

Use this when you changed files on GitHub or another PC and want this local
folder updated.

### Upload local changes to GitHub

Double-click:

```bat
update-to-git.bat
```

This will:

1. Pull latest changes from GitHub first.
2. Stage local changes.
3. Create a timestamped commit.
4. Push to the current Git branch.

Use this after editing local files and wanting those changes uploaded to GitHub.

## Moving To Another Folder Or PC

This package is portable. It should keep working if:

- You rename the folder.
- You move the folder to another drive.
- You copy the full folder to another Windows PC.

Important notes:

- Keep all files together in the same folder.
- Extract the folder before running it; do not run it from inside a ZIP file.
- On a new PC, Android ADB drivers may need to be installed.
- Git helper files work only if the folder includes the `.git` directory from a
  proper `git clone`.

## Troubleshooting

### Phone does not mirror

- Run `adb.exe devices` from this folder.
- If the phone says `unauthorized`, check the phone screen and tap Allow.
- Try unplugging and reconnecting the USB cable.
- Make sure USB debugging is enabled.

### scrcpy opens then closes

- Check the newest files inside the `logs/` folder.
- Make sure `scrcpy-server` or `scrcpy-server.zip` exists.
- Run `auto-mirror-watch.bat` again and read the message in the watcher window.

### Git update files do not work

- Make sure Git is installed.
- Make sure this folder was cloned with Git.
- If you downloaded a ZIP from GitHub, clone the repo instead:

```bat
git clone https://github.com/MDAlmasAli/PhoneScreenMirror.git
```

## Repository

```text
https://github.com/MDAlmasAli/PhoneScreenMirror.git
```
