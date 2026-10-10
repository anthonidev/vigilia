import Foundation
import Testing
@testable import Vigilia

// Test de humo: confirma que el target de tests enlaza con la app.
// Los tests reales empiezan en la Fase 1.
struct VigiliaTests {
    @Test func appModuleLoads() {
        #expect(Bundle.main.bundleIdentifier != nil)
    }
}
