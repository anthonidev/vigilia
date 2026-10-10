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

    @Test func tickAfterEndExpiresSession() async {
        var events = session.events().makeAsyncIterator()
        session.activate(.minutes(10))
        clock.advance(minutes: 10)
        session.tick()

        #expect(session.state == .inactive)
        #expect(session.remaining == nil)
        #expect(!power.isHeld)
        #expect(await events.next() == .started(.minutes(10)))
        #expect(await events.next() == .ended(.expired))
    }

    @Test func indefiniteSessionNeverExpires() {
        session.activate(.indefinite)
        clock.advance(minutes: 60 * 24 * 7)
        session.tick()

        #expect(session.isActive)
    }

    @Test func deactivateReleasesAssertionAndEmitsEvent() async {
        var events = session.events().makeAsyncIterator()
        session.activate(.minutes(30))
        session.deactivate()

        #expect(session.state == .inactive)
        #expect(!power.isHeld)
        #expect(await events.next() == .started(.minutes(30)))
        #expect(await events.next() == .ended(.deactivated))
    }

    @Test func deactivateWhenInactiveEmitsNothing() async {
        let stream = session.events()
        session.deactivate()
        session.activate(.minutes(10))

        var events = stream.makeAsyncIterator()
        #expect(await events.next() == .started(.minutes(10)))
    }

    @Test func changesEmitChangedEvent() async {
        var events = session.events().makeAsyncIterator()
        session.activate(.minutes(30))
        session.extend(byMinutes: 30)
        session.set(minutes: 5)
        session.makeIndefinite()

        #expect(await events.next() == .started(.minutes(30)))
        #expect(await events.next() == .changed)
        #expect(await events.next() == .changed)
        #expect(await events.next() == .changed)
    }

    @Test func multipleListenersReceiveEvents() async {
        var first = session.events().makeAsyncIterator()
        var second = session.events().makeAsyncIterator()
        session.activate(.indefinite)

        #expect(await first.next() == .started(.indefinite))
        #expect(await second.next() == .started(.indefinite))
    }
}
