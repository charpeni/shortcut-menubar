# Shortcut Menu Bar

A native macOS menu bar app for [Shortcut](https://shortcut.com) that gives you quick access to your stories.

![macOS](https://img.shields.io/badge/macOS-15.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

<p align="center">
  <img height="400"  alt="Shortcut Menu Bar App" src="https://github.com/user-attachments/assets/1412263e-b4f2-41d2-812c-26c83b6ed64d" />
</p>

## Features

- View all stories assigned to you, sorted by workflow state (Started → Unstarted → Backlog)
- See story details: team, workflow, epic, and current state
- Quick actions via right-click or three-dot menu:
  - Copy branch name (`username/sc-123/story-slug`)
  - Copy git checkout command
  - Copy story link
  - Open in browser
- Auto-refresh when opening the menu
- Launch at login support
- Native macOS design with light/dark mode support

## Installation

### Requirements

- macOS 15.0 (Sequoia) or later

### Build from Source

1. Clone the repository:

   ```bash
   git clone https://github.com/charpeni/shortcut-menubar.git
   cd shortcut-menubar
   ```

2. Build and run:

   ```bash
   ./build.sh
   ```

   This builds a Release version and opens the app automatically.

   Other options:

   ```bash
   ./build.sh --debug     # Debug build
   ./build.sh --clean     # Clean build folder first
   ./build.sh --no-open   # Don't open the app after building
   ```

   Or open in Xcode (`open shortcut-menubar.xcodeproj`) and build with ⌘R.

### Getting an API Token

1. Go to [Shortcut API Tokens](https://app.shortcut.com/settings/account/api-tokens)
2. Generate a new token
3. Paste it in the app when prompted

## Usage

1. Click the Shortcut icon in your menu bar
2. Enter your API token on first launch
3. Browse your stories
4. Click a story to open it in your browser
5. Right-click for quick actions (copy branch name, etc.)

### Settings

Click the gear icon in the footer to:

- Toggle "Launch at Login"
- Quit the app

## Development

### Project Structure

```
shortcut-menubar/
├── Models.swift          # Data models (Story, Team, Epic, etc.)
├── ShortcutAPI.swift     # API client
├── AppState.swift        # Observable app state
├── MenuBarView.swift     # SwiftUI views
├── AppDelegate.swift     # App lifecycle & menu bar setup
├── TokenStorage.swift    # Token storage
└── Assets.xcassets/      # App icons
```

### Debugging

Network requests are logged using `os.Logger`. View logs in Console.app by filtering for `com.charpeni.shortcut-menubar`.

## Acknowledgments

- Built with SwiftUI
- Uses the [Shortcut REST API](https://developer.shortcut.com/api/rest/v3)

## License

MIT License - see [LICENSE](LICENSE) for details.
