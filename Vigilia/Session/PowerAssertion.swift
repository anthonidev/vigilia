import Foundation
import IOKit.pwr_mgt
import os

protocol PowerAsserting: AnyObject {
    var isHeld: Bool { get }
    func acquire()
    func release()
}

/// Aserción de energía de IOKit que impide que la pantalla y el sistema se duerman por inactividad.
/// Si la app termina, el sistema libera la aserción automáticamente.
final class PowerAssertion: PowerAsserting {
    private static let logger = Logger(subsystem: "com.tonis.vigilia", category: "session")

    private var assertionID = IOPMAssertionID(0)
    private(set) var isHeld = false

    func acquire() {
        guard !isHeld else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Vigilia mantiene la Mac despierta" as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isHeld = true
        } else {
            Self.logger.error("No se pudo crear la aserción de energía: \(result)")
        }
    }

    func release() {
        guard isHeld else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isHeld = false
    }
}
