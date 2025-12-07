# 🎤 Groq Whisper - Voice-to-Text for Linux

> **A free, open-source alternative to [Wispr Flow](https://www.wispr.flow/) for Linux users**

Wispr Flow is a popular voice-to-text tool, but it only supports macOS and Windows. This project brings the same functionality to Linux using the **Groq API** (free tier available!) with **Whisper Large V3** for high-quality transcription.

**Works on any Linux distro** – Wayland or X11, any desktop environment!

![Demo](https://img.shields.io/badge/Press-Super%2BR-blue?style=for-the-badge) → 🎤 Speak → Press again → 📋 Text copied!

## ✨ Features

- 🚀 **Fast transcription** using Groq's Whisper Large V3
- 🔄 **Toggle behavior** – Press once to start, press again to stop & transcribe
- 📋 **Auto-copy to clipboard** – Works on both Wayland and X11
- 🔁 **Retry logic** – Handles API cold-start issues automatically
- 🎯 **Lightweight** – Just a bash script, no bloat
- 💰 **Free tier** – Groq offers generous free API usage

## 📦 Installation

### 1. Install Dependencies

<details>
<summary><b>Arch Linux / Manjaro</b></summary>

```bash
sudo pacman -S sox libnotify curl
# For Wayland:
sudo pacman -S wl-clipboard
# For X11:
sudo pacman -S xclip
```
</details>

<details>
<summary><b>Ubuntu / Debian / Pop!_OS</b></summary>

```bash
sudo apt install sox libnotify-bin curl
# For Wayland:
sudo apt install wl-clipboard
# For X11:
sudo apt install xclip
```
</details>

<details>
<summary><b>Fedora</b></summary>

```bash
sudo dnf install sox libnotify curl
# For Wayland:
sudo dnf install wl-clipboard
# For X11:
sudo dnf install xclip
```
</details>

<details>
<summary><b>openSUSE</b></summary>

```bash
sudo zypper install sox libnotify-tools curl
# For Wayland:
sudo zypper install wl-clipboard
# For X11:
sudo zypper install xclip
```
</details>

<details>
<summary><b>NixOS</b></summary>

```nix
# In your configuration.nix or home.nix
environment.systemPackages = with pkgs; [
  sox
  libnotify
  curl
  wl-clipboard  # For Wayland
  # xclip       # For X11
];
```
</details>

### 2. Get Your Groq API Key (Free!)

1. Go to [console.groq.com](https://console.groq.com/)
2. Create a free account
3. Navigate to **API Keys** → **Create API Key**
4. Copy your key

### 3. Set Up the Script

```bash
# Clone or download the script
git clone https://github.com/EmbeddedMhawar/groq-whisper.git
cd groq-whisper

# Make it executable
chmod +x groq_whisper.sh

# Set your API key (choose one method):

# Option A: Environment variable (recommended)
echo 'export GROQ_API_KEY="your_key_here"' >> ~/.bashrc
source ~/.bashrc

# Option B: Edit the script directly
# Open groq_whisper.sh and replace YOUR_API_KEY_HERE with your key
```

### 4. Set Up Keybind

<details>
<summary><b>Hyprland</b></summary>

Add to `~/.config/hypr/hyprland.conf`:
```conf
bind = SUPER, R, exec, /path/to/groq_whisper.sh
```

For auto-paste, uncomment this line in the script:
```bash
hyprctl dispatch sendshortcut CTRL, V, activewindow
```
</details>

<details>
<summary><b>Sway</b></summary>

Add to `~/.config/sway/config`:
```conf
bindsym $mod+r exec /path/to/groq_whisper.sh
```

For auto-paste, uncomment this line in the script:
```bash
swaymsg exec 'wtype -M ctrl v -m ctrl'
```
</details>

<details>
<summary><b>GNOME</b></summary>

1. Open **Settings** → **Keyboard** → **Keyboard Shortcuts**
2. Scroll to bottom → **Custom Shortcuts** → **+**
3. Name: `Groq Whisper`
4. Command: `/path/to/groq_whisper.sh`
5. Shortcut: `Super+R`
</details>

<details>
<summary><b>KDE Plasma</b></summary>

1. Open **System Settings** → **Shortcuts** → **Custom Shortcuts**
2. **Edit** → **New** → **Global Shortcut** → **Command/URL**
3. Set trigger to `Super+R`
4. Action: `/path/to/groq_whisper.sh`
</details>

<details>
<summary><b>i3</b></summary>

Add to `~/.config/i3/config`:
```conf
bindsym $mod+r exec /path/to/groq_whisper.sh
```

For auto-paste, uncomment this line in the script:
```bash
xdotool key ctrl+v
```

Also install `xdotool`:
```bash
sudo pacman -S xdotool  # Arch
sudo apt install xdotool  # Ubuntu/Debian
```
</details>

<details>
<summary><b>XFCE</b></summary>

1. Open **Settings** → **Keyboard** → **Application Shortcuts**
2. Click **Add**
3. Command: `/path/to/groq_whisper.sh`
4. Press `Super+R` when prompted
</details>

## 🎯 Usage

1. **Press `Super+R`** – Recording starts (you'll see a notification)
2. **Speak your text**
3. **Press `Super+R` again** – Recording stops, transcription begins
4. **Text is copied to clipboard!** – Paste with `Ctrl+V`

## 🔧 Troubleshooting

### "No such file or directory" error
Make sure `rec` (from SoX) is installed:
```bash
which rec  # Should show /usr/bin/rec
```

### HTTP 400 errors
The script includes retry logic for this. If it persists, check your API key.

### Clipboard not working on Wayland
Make sure `wl-copy` is installed:
```bash
sudo pacman -S wl-clipboard  # Arch
sudo apt install wl-clipboard  # Ubuntu/Debian
```

### No audio being recorded
Check your default audio input:
```bash
pactl info | grep "Default Source"
```

## 🤝 Contributing

PRs welcome! If you add support for another desktop environment or distro, please submit a pull request.

## 📜 License

MIT License - Use it however you want!

## 🙏 Acknowledgments

- [Groq](https://groq.com/) for their blazing-fast API
- OpenAI for the Whisper model
- Inspired by [Wispr Flow](https://www.wispr.flow/) (now Linux users can join the party!)

---

**Made with ❤️ for the Linux community**
