# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build (simulator)
xcodebuild -project EchoOfAges.xcodeproj -scheme EchoOfAges -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -project EchoOfAges.xcodeproj -scheme EchoOfAges -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test (Swift Testing uses --only-testing with the test ID)
xcodebuild -project EchoOfAges.xcodeproj -scheme EchoOfAges -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing EchoOfAgesTests/EchoOfAgesTests/exampleTest
```

Open `EchoOfAges.xcodeproj` in Xcode for day-to-day development. Target: iOS 26.4+, Swift 5.0, bundle ID `com.gringogolf.EchoOfAges`.

**File inclusion**: The project uses `PBXFileSystemSynchronizedRootGroup`, so any `.swift` file added to `EchoOfAges/` is automatically included in the build — no `.pbxproj` edits required.

**Custom fonts**: Cinzel and Crimson Text are referenced but must be manually added. Download from Google Fonts, drag `.ttf` files into Xcode, and list them under "Fonts provided by application" in `Info.plist`. The app silently falls back to the system font if they are absent.

## Architecture

The app is a single-screen SwiftUI puzzle game with no external dependencies. Navigation is driven by `GameState.currentScreen` (a `GameScreen` enum), not SwiftUI's `NavigationStack`. `ContentView` is a `ZStack` that switches between views with animated transitions.

**Data flow**: `GameState` is a `@MainActor ObservableObject` created once in `ContentView` and injected everywhere via `.environmentObject`. All mutation goes through `GameState` methods — views never write to state directly.

**Puzzle model** (`Level.swift`): Each level is a Latin-square puzzle — every `Glyph` appears exactly once per row and column. `Level` holds the solution, the initial (partially-filled) grid, and a set of `fixedPositions` the player cannot modify. The `isSolved(_:)` method compares the player's `[[Glyph?]]` grid against the solution cell-by-cell.

**Interaction model** (`GameState`): The palette (`selectedGlyph`) and the grid interact as follows — tapping a palette button arms a glyph; tapping a cell places or clears it. Without a palette selection, tapping a cell cycles through available glyphs in order. Long-pressing a cell clears it. "Decipher" (`verifyPlacement()`) flashes incorrect cells red for 1.2 s without revealing the answer.

**Screens**:
- `TitleView` — entry point; shows Begin / Continue / Journal
- `GameView` (in `GlyphGridView.swift`) — full puzzle screen: level header, `GlyphGridView`, palette, collapsible inscriptions, action buttons
- `JournalView` — expandable list of 5 lore entries; entries lock until the corresponding level is completed
- `LevelCompleteView` / `GameCompleteView` — inline in `ContentView.swift`

**Theme** (`Theme.swift`): All colors (`stoneDark`, `stoneMid`, `stoneLight`, `stoneSurface`, `goldDark`, `goldMid`, `goldBright`, `papyrus`, `rubyRed`) and fonts (`EgyptFont`) are centralized here. `StoneButton` and `HapticFeedback` helpers also live here.

**Progress persistence**: Completed level IDs are stored in `UserDefaults` under the key `EOA_unlockedEntries` as `[Int]`.
