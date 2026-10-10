import Foundation
import Observation
import ServiceManagement

/// Iniciar Vigilia al encender la Mac. El estado se lee del sistema, no se guarda en la app.
@Observable
final class LoginItem {
    private(set) var status: SMAppService.Status

    @ObservationIgnored private let service = SMAppService.mainApp

    init() {
        status = service.status
    }

    var isEnabled: Bool { status == .enabled }

    /// macOS pide aprobarlo en Ajustes del Sistema → General → Ítems de inicio.
    var requiresApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) throws {
        defer { refresh() }
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    func refresh() {
        status = service.status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
