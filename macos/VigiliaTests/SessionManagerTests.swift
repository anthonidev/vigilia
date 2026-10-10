import Foundation
import Testing
@testable import Vigilia

@MainActor
struct SessionManagerTests {
    let clock = FakeTimeSource()
    let power = FakePowerAssertion()
    let session: SessionManager

    init() {
        session = SessionManager(timeSource: clock, power: power)
    }

    @Test func startsInactive() {
        #expect(session.state == .inactive)
        #expect(!power.isHeld)
    }

    @Test func activateSetsEndDateAndHoldsAssertion() {
        session.activate(.minutes(30))

        #expect(session.state == .active(endDate: clock.now.addingTimeInterval(minutes(30))))
        #expect(session.remaining == minutes(30))
        #expect(session.selectedOption == .minutes(30))
        #expect(power.isHeld)
    }

    @Test func activateIndefinite() {
        session.activate(.indefinite)

        #expect(session.state == .active(endDate: nil))
        #expect(session.remaining == nil)
        #expect(session.isIndefinite)
    }

    @Test func activatingAgainReplacesTimeWithoutDuplicatingAssertion() {
        session.activate(.minutes(60))
        clock.advance(minutes: 10)
        session.activate(.minutes(30))

        #expect(session.remaining == minutes(30))
        #expect(session.selectedOption == .minutes(30))
        #expect(power.acquireCount == 1)
    }

    @Test func extendAddsTime() {
        session.activate(.minutes(30))
        clock.advance(minutes: 10)

        #expect(session.extend(byMinutes: 60) == .extended)
        #expect(session.remaining == minutes(80))
        #expect(session.selectedOption == nil)
    }

    @Test func extendDoesNothingWhenIndefiniteOrInactive() {
        #expect(session.extend(byMinutes: 30) == .inactive)

        session.activate(.indefinite)
        #expect(session.extend(byMinutes: 30) == .alreadyIndefinite)
        #expect(session.isIndefinite)
    }

    @Test func setReplacesRemainingTime() {
        session.activate(.minutes(240))
        session.set(minutes: 15)

        #expect(session.remaining == minutes(15))
    }

    @Test func setStartsSessionWhenInactive() {
        session.set(minutes: 15)

        #expect(session.isActive)
        #expect(session.remaining == minutes(15))
    }

    @Test func makeIndefiniteRemovesEndDate() {
        session.activate(.minutes(30))
        session.makeIndefinite()

        #expect(session.isIndefinite)
        #expect(session.remaining == nil)
        #expect(power.isHeld)
    }

    @Test func tickBeforeEndUpdatesRemaining() {
        session.activate(.minutes(30))
        clock.advance(minutes: 12)
        session.tick()

        #expect(session.isActive)
        #expect(session.remaining == minutes(18))
    }

    @Test func tickAfterEndExpiresSession() {
        let events = record()
        session.activate(.minutes(10))
        clock.advance(minutes: 10)
        session.tick()

        #expect(session.state == .inactive)
        #expect(session.remaining == nil)
        #expect(!power.isHeld)
        #expect(events.all == [.started(.minutes(10)), .ended(.expired(at: clock.now))])
    }

    @Test func indefiniteSessionNeverExpires() {
        session.activate(.indefinite)
        clock.advance(minutes: 60 * 24 * 7)
        session.tick()

        #expect(session.isActive)
    }

    @Test func deactivateReleasesAssertionAndEmitsEvent() {
        let events = record()
        session.activate(.minutes(30))
        session.deactivate()

        #expect(session.state == .inactive)
        #expect(!power.isHeld)
        #expect(events.all == [.started(.minutes(30)), .ended(.deactivated)])
    }

    @Test func deactivateWhenInactiveEmitsNothing() {
        let events = record()
        session.deactivate()

        #expect(events.all.isEmpty)
    }

    @Test func changesEmitChangedEvent() {
        let events = record()
        session.activate(.minutes(30))
        session.extend(byMinutes: 30)
        session.set(minutes: 5)
        session.makeIndefinite()

        #expect(events.all == [.started(.minutes(30)), .changed, .changed, .changed])
    }

    @Test func multipleObserversReceiveEvents() {
        let first = record()
        let second = record()
        session.activate(.indefinite)

        #expect(first.all == [.started(.indefinite)])
        #expect(second.all == [.started(.indefinite)])
    }

    /// Guarda los eventos que emite la sesión, en orden.
    private func record() -> EventRecorder {
        let recorder = EventRecorder()
        session.observe { recorder.all.append($0) }
        return recorder
    }

    // MARK: - Aviso de los 10 minutos

    @Test func warnsOnceWhenTenMinutesLeft() {
        var events: [SessionEvent] = []
        session.observe { events.append($0) }
        session.activate(.minutes(30))

        clock.advance(minutes: 19)
        session.tick()
        #expect(!events.contains(.tenMinutesLeft))

        clock.advance(minutes: 1)
        session.tick()
        clock.advance(minutes: 1)
        session.tick()
        #expect(events.filter { $0 == .tenMinutesLeft }.count == 1)
    }

    @Test func noWarningForShortSessions() {
        var events: [SessionEvent] = []
        session.observe { events.append($0) }
        session.activate(.minutes(10))

        clock.advance(minutes: 5)
        session.tick()
        #expect(!events.contains(.tenMinutesLeft))
    }

    @Test func warningRearmsAfterExtending() {
        var events: [SessionEvent] = []
        session.observe { events.append($0) }
        session.activate(.minutes(20))
        clock.advance(minutes: 11)
        session.tick()

        session.extend(byMinutes: 30)
        clock.advance(minutes: 30)
        session.tick()
        #expect(events.filter { $0 == .tenMinutesLeft }.count == 2)
    }

    @Test func expiryAfterSleepSkipsWarningAndKeepsEndTime() {
        var events: [SessionEvent] = []
        session.observe { events.append($0) }
        session.activate(.minutes(30))
        let endDate = clock.now.addingTimeInterval(minutes(30))

        // La Mac durmió más allá del final: no hay aviso de 10 min, solo el de fin con su hora real.
        clock.advance(minutes: 90)
        session.tick()
        #expect(!events.contains(.tenMinutesLeft))
        #expect(events.last == .ended(.expired(at: endDate)))
    }

    @Test func remoteDeactivationIsDistinguished() {
        var events: [SessionEvent] = []
        session.observe { events.append($0) }
        session.activate(.indefinite)
        session.deactivate(remotely: true)

        #expect(events.last == .ended(.deactivatedRemotely))
    }
}

final class EventRecorder {
    var all: [SessionEvent] = []
}
