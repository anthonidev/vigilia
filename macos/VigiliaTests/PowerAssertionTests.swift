import Foundation
import IOKit.pwr_mgt
import Testing
@testable import Vigilia

/// Usa la aserción real de IOKit y consulta al sistema, igual que `pmset -g assertions`.
@MainActor
struct PowerAssertionTests {
    @Test func acquireRegistersAssertionAndReleaseRemovesIt() {
        let assertion = PowerAssertion()

        assertion.acquire()
        assertion.acquire() // idempotente
        #expect(assertion.isHeld)
        #expect(vigiliaAssertionCount() == 1)

        assertion.release()
        #expect(!assertion.isHeld)
        #expect(vigiliaAssertionCount() == 0)
    }

    /// Aserciones de este proceso con el nombre de Vigilia y tipo PreventUserIdleDisplaySleep.
    private func vigiliaAssertionCount() -> Int {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byProcess = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return -1 }

        let mine = byProcess[NSNumber(value: getpid())] ?? []
        return mine.filter {
            $0[kIOPMAssertionTypeKey] as? String == kIOPMAssertionTypePreventUserIdleDisplaySleep
                && $0[kIOPMAssertionNameKey] as? String == "Vigilia mantiene la Mac despierta"
        }.count
    }
}
