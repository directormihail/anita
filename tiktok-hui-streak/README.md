# TikTok HUI Streak Bot

Sends **HUI** to a friend on TikTok every day at the same time so your DM streak keeps going.

Works on **macOS** and **Windows**. Uses Playwright to control TikTok in Chrome, saves your login locally, and runs on a daily schedule.

---

## How it works (quick)

1. **Login once** — Playwright opens TikTok in a real Chrome window. You log in manually. Cookies are saved to `.session/tiktok_storage.json`.
2. **Send flow** — At the scheduled time, the bot:
   - Opens `tiktok.com/messages` with your saved session
   - Finds your friend's chat in the DM list
   - Types **HUI** into TikTok's chat box (Draft.js editor workaround)
   - Clicks Send (or presses Enter)
3. **Schedule** — Either a small Python loop (`schedule`) or the OS scheduler (macOS launchd / Windows Task Scheduler) runs `python main.py send-now` every day at `send_time`.

No TikTok API — it's browser automation, so it can break if TikTok changes their site.

---

## Windows setup

**Requirements:** Python 3.10+ from [python.org](https://www.python.org/downloads/) (check **Add python.exe to PATH**).

```bat
cd path\to\tiktok-hui-streak
setup-windows.bat
```

Edit `config.yaml`:
- `friend_name` — friend's name or @username in your DM list
- `send_time` — e.g. `09:00` (24h, local time)

```bat
.venv\Scripts\activate
python main.py login
python main.py test
```

**Daily automation (recommended on Windows):**

```powershell
powershell -ExecutionPolicy Bypass -File install-windows-task.ps1
```

Test the task:

```powershell
Start-ScheduledTask -TaskName TikTokHuiStreak
```

Remove it:

```powershell
powershell -ExecutionPolicy Bypass -File uninstall-windows-task.ps1
```

**Or** keep a Command Prompt open:

```bat
python main.py schedule
```

---

## macOS setup

```bash
cd path/to/tiktok-hui-streak

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
playwright install chromium

cp config.example.yaml config.yaml
# edit config.yaml
```

```bash
python main.py login
python main.py test
```

**Daily automation (recommended on Mac):**

```bash
# Edit Hour/Minute in the template to match config.yaml send_time
sed "s|__PROJECT_DIR__|$(pwd)|g" com.tiktok.huistreak.plist.template > ~/Library/LaunchAgents/com.tiktok.huistreak.plist
launchctl load ~/Library/LaunchAgents/com.tiktok.huistreak.plist
```

Or: `python main.py schedule`

---

## Config (`config.yaml`)

| Key | Example | Description |
|-----|---------|-------------|
| `friend_name` | `johndoe` | Friend's name or @username in your DM list |
| `message` | `HUI` | Text sent every day |
| `send_time` | `09:00` | 24h local time |
| `headless` | `true` | Hide browser after login works |

## Commands

| Command | What it does |
|---------|----------------|
| `python main.py login` | Save TikTok session |
| `python main.py test` | Send once (visible browser) |
| `python main.py send-now` | Send once (headless) |
| `python main.py schedule` | Run daily scheduler in terminal |

## Notes

- TikTok has no official API for sending DMs. Automation can risk account restrictions — one message/day is low risk but not zero.
- If login expires, run `python main.py login` again.
- PC must be on and logged in at the scheduled time (or use "Start when available" on Windows, which the installer enables).
