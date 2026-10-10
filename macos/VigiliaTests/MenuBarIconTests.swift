import AppKit
import Testing
@testable import Vigilia

struct MenuBarIconTests {
    @Test func steamFadesInAndOut() {
        #expect(MenuBarIcon.intensity(at: 0) == 0)
        #expect(MenuBarIcon.intensity(at: 0.15) == 0.5)
        #expect(MenuBarIcon.intensity(at: 1.5) == 1)
        #expect(MenuBarIcon.intensity(at: 3) == 0)
    }

    @Test(arguments: IconStyle.allCases)
    func everyStyleRendersTemplates(style: IconStyle) {
        let frame = IconAnimationFrame(phase: 0.5, intensity: 1)
        for active in [true, false] {
            for frame in [nil, frame] {
                let image = MenuBarIconRenderer.image(style: style, active: active, frame: frame)
                #expect(image.isTemplate)
                #expect(image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
            }
        }
    }

    @Test(arguments: IconStyle.allCases)
    func everyStyleUsesExistingSymbols(style: IconStyle) {
        for active in [true, false] {
            #expect(NSImage(systemSymbolName: style.symbol(active: active), accessibilityDescription: nil) != nil)
        }
    }
}
