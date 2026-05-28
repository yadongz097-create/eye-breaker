# Eye Breaker MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal local macOS menu bar app that reminds the user to rest their eyes with adjustable work/break timers, a sound alert, and a full-screen break overlay.

**Architecture:** Keep the timer logic and persistence in small pure-Swift types that are easy to test. Put macOS UI in a thin AppKit layer: one status item, one settings window, one full-screen overlay window, and a periodic timer that drives the session state machine.

**Tech Stack:** Swift 6.3, AppKit, Foundation, Swift Testing, UserDefaults.

---

### Task 1: Timer engine and preferences

**Files:**
- Create: `Sources/EyeBreaker/EyeBreakSettings.swift`
- Create: `Sources/EyeBreaker/EyeBreakSession.swift`
- Create: `Sources/EyeBreaker/EyeBreakPreferences.swift`
- Modify: `Tests/EyeBreakerTests/EyeBreakerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test func sessionTransitionsFromWorkToBreakAndBack() {
    var session = EyeBreakSession(settings: .init(workMinutes: 20, breakMinutes: 1))
    session.start()
    session.tick(seconds: 20 * 60)
    #expect(session.phase == .break)
    #expect(session.remainingSeconds == 60)
    session.tick(seconds: 60)
    #expect(session.phase == .work)
    #expect(session.remainingSeconds == 20 * 60)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter sessionTransitionsFromWorkToBreakAndBack`
Expected: compile failure because `EyeBreakSession` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

Implement the state machine plus `Codable` preferences with `UserDefaults` round-trip support.

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test`
Expected: timer and preferences tests pass.

### Task 2: AppKit menu bar app, settings window, and overlay

**Files:**
- Modify: `Sources/EyeBreaker/EyeBreaker.swift`
- Create: `Sources/EyeBreaker/AppController.swift`
- Create: `Sources/EyeBreaker/OverlayWindowController.swift`
- Create: `Sources/EyeBreaker/SettingsWindowController.swift`

- [ ] **Step 1: Wire the AppKit entrypoint**

Create the app delegate, status item, menu actions, one-second tick, and the overlay toggle that follows session phase changes.

- [ ] **Step 2: Add the settings window**

Expose editable work/break minutes and save them back to `UserDefaults`.

- [ ] **Step 3: Add the full-screen break overlay**

Show a borderless window at screen-saver level with a large countdown and make it disappear automatically when the break phase ends.

- [ ] **Step 4: Build the app**

Run: `swift build`
Expected: executable target compiles on macOS.

### Task 3: Smoke test and polish

**Files:**
- Modify: `README.md` if needed

- [ ] **Step 1: Launch the executable locally**

Run the built binary and confirm the menu bar icon appears, the start/pause/reset actions work, and the overlay shows when the work timer elapses.

- [ ] **Step 2: Fix any UI/runtime issues**

Only adjust what blocks the minimal flow.

- [ ] **Step 3: Final verification**

Run: `swift test && swift build`
Expected: both commands succeed.

