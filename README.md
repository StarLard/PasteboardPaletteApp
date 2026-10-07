# Pasteboard Palette

A tiny macOS app for the text you paste all the time. Save snippets like your
email address, then copy one with a single click, either from the app or from
the menu bar.

Think of it like the Passwords app, but for everyday text that isn't secret.
There are no accounts, no sync, and no encryption.

## Features

- **Click to copy.** Click any snippet in the app to copy it to your pasteboard.
  A "Copied" badge confirms it.
- **Menu bar access.** Click the menu bar icon to copy your pinned snippet or
  one of your three most recently used snippets.
- **Pin a snippet.** Right-click a snippet and choose **Pin**. It gets a pin icon
  and stays at the top of both the app's list and the menu bar menu.
- **Save from the pasteboard.** Paste with ⌘V in the main window, click the
  toolbar's Paste button, or choose **Save Pasteboard as Snippet** from the menu
  bar.
- **Search, edit, reorder, and delete** snippets in the main window.
- **Launch at login**, so your snippets are always one click away.

## Requirements

- macOS 26.6 or later
- To build from source, Xcode 27 or later

## Installation

### Download a release

1. Download the latest `Pasteboard-Palette.zip` from the
   [Releases](../../releases) page, if one has been published.
2. Unzip it and move **Pasteboard Palette.app** to your **Applications** folder.
3. Open the app. Release builds aren't notarized, so macOS may say it can't
   verify the developer. If it does, open **System Settings › Privacy &
   Security**, scroll down, and click **Open Anyway**.

### Build from source

1. Clone the repository:

   ```sh
   git clone https://github.com/StarLard/pasteboard-palette.git
   cd pasteboard-palette
   ```

2. Optionally, set your own bundle ID prefix and Apple Developer team. Copy the
   example config and edit it:

   ```sh
   cp Config/Local.example.xcconfig Config/Local.xcconfig
   ```

   `Config/Local.xcconfig` is git-ignored, so your personal values stay out of
   the repository. Without it, the app builds with the placeholder prefix
   `com.example` and signs locally, with no Apple account needed.

3. Open **Pasteboard Palette.xcodeproj** in Xcode.
4. Choose **Product › Run** (⌘R) to try it out. To install it, choose
   **Product › Archive**, then **Distribute App › Custom › Copy App** and move
   the exported app to **Applications**.

> **Tip:** Set your development team in `Config/Local.xcconfig` instead of the
> Signing & Capabilities tab. Xcode writes the tab's setting into the shared
> project file, which you'd then have to keep out of your commits.

## Usage

### Add a snippet

- **Type it.** Click **+** in the toolbar, or press ⌘N. Enter an optional title,
  such as "Personal Email", and the text, then click **Save**.
- **Paste it.** Copy some text anywhere, then press ⌘V in the Pasteboard Palette
  window or click the toolbar's **Paste** button. The text is saved as a new
  snippet. Inside the editor, the **Paste** button fills in the text field.
- **From the menu bar.** Choose **Save Pasteboard as Snippet**. The first time,
  macOS may ask whether Pasteboard Palette can paste from other apps. Choose
  **Allow** or **Always Allow**.

### Copy a snippet

- **In the app,** click a snippet. It flashes and shows **Copied**, and the menu
  bar icon briefly turns into a checkmark.
- **From the menu bar,** click the clipboard icon, then click a snippet. The
  menu shows your pinned snippet first, then up to three **Recent** snippets,
  most recently used first. While the menu is open, press ⌘C to copy the pinned
  snippet. All other snippets are in the main window.

  "Recent" means most recently copied, from either the app or the menu bar. A
  snippet you've never copied is ordered by when you last edited it, or when you
  created it if you've never edited it. New and freshly edited snippets show up
  right away.

### Pin a snippet

You can pin one snippet at a time, such as your email address. The pinned
snippet shows a pin icon and stays at the top of the app's list and the menu
bar menu, no matter how recently you used it.

- **In the app,** right-click a snippet and choose **Pin**. Pinning another
  snippet replaces the current pin. To unpin, choose **Unpin**.
- **From the menu bar,** open **Pinned Snippet** and pick a snippet, or pick
  **None** to unpin.

When you unpin a snippet, it returns to its earlier place in the list.

### Edit, delete, or reorder

Right-click a snippet and choose **Edit…** or **Delete**. Drag snippets to
reorder them. The pinned snippet always stays on top. Search is in the toolbar.

### Launch at login and other settings

- Turn on **Launch at Login** from the menu bar menu or in **Pasteboard Palette ›
  Settings…** (⌘,). You can also manage it in **System Settings › General ›
  Login Items**.
- Settings also lets you hide or show the menu bar icon.
- Closing the main window keeps the app running in the menu bar. Choose **Open
  Pasteboard Palette** from the menu bar, or click the Dock icon, to bring the
  window back. To quit, choose **Quit Pasteboard Palette** from the menu bar or
  press ⌘Q.

## Privacy and data

Snippets are stored locally in the app's sandboxed preferences, in
`~/Library/Containers/<bundle-id>/Data/Library/Preferences/`. They are stored
as plain, unencrypted text and never leave your Mac. **Don't store passwords or
other secrets.** Use the Passwords app for those.

## Development

The app is written in Swift 6 with SwiftUI and Observation.

| Path | What's there |
| --- | --- |
| `Pasteboard Palette/PasteboardPaletteApp.swift` | App entry point and scenes: the main window, the menu bar extra, and Settings |
| `Pasteboard Palette/Store/SnippetStore.swift` | Snippet storage in `UserDefaults`, copying, and copy feedback |
| `Pasteboard Palette/Views/` | Main window rows and the editor sheet |
| `Pasteboard Palette/MenuBar/` | Menu bar menu and icon |
| `Pasteboard Palette/Settings/` | Settings window and launch at login, which uses `SMAppService` |
| `Config/` | Shared and local `.xcconfig` build settings |

Run the tests with **Product › Test** (⌘U). Unit tests use Swift Testing with
throwaway preferences and a private pasteboard. UI tests launch the app with
`--ui-testing`, which gives them an empty, temporary snippet store.

## Contributing

Issues and pull requests are welcome. Please run the tests before you open a
pull request.

## License

Pasteboard Palette is available under the [MIT License](LICENSE).
