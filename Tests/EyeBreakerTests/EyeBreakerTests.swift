import Foundation
import Testing
@testable import EyeBreaker

@Test func sessionTransitionsFromWorkToBreakAndBack() {
    var session = EyeBreakSession(settings: .init(workMinutes: 20, breakMinutes: 1))

    #expect(session.phase == .idle)
    #expect(session.remainingSeconds == 20 * 60)

    session.start()
    #expect(session.phase == .work)
    #expect(session.remainingSeconds == 20 * 60)

    _ = session.tick(seconds: 20 * 60)
    #expect(session.phase == .rest)
    #expect(session.remainingSeconds == 60)

    _ = session.tick(seconds: 60)
    #expect(session.phase == .work)
    #expect(session.remainingSeconds == 20 * 60)
}

@Test func pausePreservesRemainingTime() {
    var session = EyeBreakSession(settings: .init(workMinutes: 15, breakMinutes: 1))

    session.start()
    _ = session.tick(seconds: 90)
    session.pause()

    let remaining = session.remainingSeconds
    _ = session.tick(seconds: 30)
    #expect(session.remainingSeconds == remaining)

    session.resume()
    _ = session.tick(seconds: 1)
    #expect(session.remainingSeconds == remaining - 1)
}

@Test func preferencesRoundTripThroughDefaults() throws {
    let suiteName = "EyeBreakerTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Failed to create isolated UserDefaults suite.")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)

    let store = EyeBreakPreferencesStore(userDefaults: defaults)
    let expected = EyeBreakSettings(workMinutes: 25, breakMinutes: 2)

    store.save(expected)

    let loaded = store.load()
    #expect(loaded == expected)
}

@Test func snoozeRestExtendsRemainingTime() {
    var session = EyeBreakSession(settings: .init(workMinutes: 20, breakMinutes: 1))

    session.start()
    _ = session.tick(seconds: 20 * 60)
    #expect(session.phase == .rest)
    #expect(session.remainingSeconds == 60)

    session.snoozeRest(bySeconds: 5 * 60)
    #expect(session.phase == .rest)
    #expect(session.remainingSeconds == 60 + 5 * 60)
}

@Test func endRestNowReturnsToWorkImmediately() {
    var session = EyeBreakSession(settings: .init(workMinutes: 20, breakMinutes: 1))

    session.start()
    _ = session.tick(seconds: 20 * 60)
    #expect(session.phase == .rest)

    session.endRestNow()
    #expect(session.phase == .work)
    #expect(session.remainingSeconds == 20 * 60)
}
