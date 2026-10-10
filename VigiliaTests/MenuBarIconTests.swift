import Testing
@testable import Vigilia

struct MenuBarIconTests {
    @Test func steamFadesInAndOut() {
        #expect(MenuBarIcon.intensity(at: 0) == 0)
        #expect(MenuBarIcon.intensity(at: 0.15) == 0.5)
        #expect(MenuBarIcon.intensity(at: 1.5) == 1)
        #expect(MenuBarIcon.intensity(at: 3) == 0)
    }

    @Test func activeAndInactiveIconsAreTemplates() {
        #expect(CupIcon.image(active: true, steam: nil).isTemplate)
        #expect(CupIcon.image(active: false, steam: SteamFrame(phase: 0.5, intensity: 1)).isTemplate)
    }
}
