# Groq Whisper for Linux

**Blazing fast voice-to-text for your desktop.**

A lightweight, open-source alternative to Wispr Flow for Linux, powered by Groq's Whisper Large V3 API.

## Core Philosophy
Voice dictation should be **instant and ubiquitous**. This tool brings the power of cloud-grade transcription to your Linux desktop, allowing you to capture thoughts as fast as you can speak them, anywhere in your OS.

## Features

### 1. Speed
Leverages Groq's LPU inference engine for near-instant transcription.

### 2. Simplicity
One keybind to rule them all.
- **Press**: Start recording.
- **Press Again**: Stop & Transcribe.
- **Result**: Text is auto-copied to your clipboard.

### 3. Reliability
Includes smart retry logic to handle API cold-starts, ensuring you never lose a thought.

## Setup

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

### 2. Install Script

```bash
git clone https://github.com/EmbeddedMhawar/groq-whisper.git
cd groq-whisper
chmod +x groq_whisper.sh
```

### 3. Configuration
Set your API key (get one for free at console.groq.com):
```bash
export GROQ_API_KEY="your_key_here"
```

### 4. Keybindings

<details>
<summary><b>Hyprland</b></summary>

Add to `~/.config/hypr/hyprland.conf`:
```conf
bind = SUPER, R, exec, /path/to/groq_whisper.sh
```
</details>

<details>
<summary><b>Sway</b></summary>

Add to `~/.config/sway/config`:
```conf
bindsym $mod+r exec /path/to/groq_whisper.sh
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
</details>

<details>
<summary><b>XFCE</b></summary>

1. Open **Settings** → **Keyboard** → **Application Shortcuts**
2. Click **Add**
3. Command: `/path/to/groq_whisper.sh`
4. Press `Super+R` when prompted
</details>

## License
MIT
