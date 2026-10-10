import AppKit
import Observation

/// Ícono y menú de la barra de menú, con AppKit: `MenuBarExtra` no permite un tooltip en el ícono.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let openSettings: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    /// Cabeceras del menú abierto, para actualizarlas en vivo cada segundo.
    private weak var sessionHeader: NSMenuItem?
    private weak var botHeader: NSMenuItem?

    init(model: AppModel, openSettings: @escaping () -> Void) {
        self.model = model
        self.openSettings = openSettings
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        trackButton()
    }

    // MARK: - Ícono y tooltip

    /// Redibuja el ícono y el tooltip cada vez que cambia algo que muestran.
    private func trackButton() {
        withObservationTracking {
            updateButton()
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackButton() }
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let session = model.session
        let status = session.statusText

        button.image = model.icon.image(active: session.isActive)
        button.toolTip = status
        button.setAccessibilityLabel("Vigilia, \(status)")

        // Si el menú está abierto, actualiza también las cabeceras.
        sessionHeader?.title = status
        botHeader?.title = botStatus ?? ""
    }

    private var botStatus: String? {
        BotStatusText.text(
            botEnabled: model.settings.botEnabled,
            hasToken: model.token.hasToken,
            isAccountLinked: model.settings.isAccountLinked,
            status: model.bot.status
        )
    }

    // MARK: - Menú

    /// El menú se rehace cada vez que se abre.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let session = model.session

        if session.isActive {
            let header = disabledItem(session.statusText)
            sessionHeader = header
            menu.addItem(header)
            if let botStatus {
                let bot = disabledItem(botStatus)
                botHeader = bot
                menu.addItem(bot)
            }
            menu.addItem(.separator())
        }

        for (index, option) in SessionDuration.menuOptions.enumerated() {
            let item = NSMenuItem(title: option.label, action: #selector(activate(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            // Elegir otra vez la opción marcada reinicia su tiempo.
            item.state = session.selectedOption == option ? .on : .off
            menu.addItem(item)
        }

        if session.isActive {
            menu.addItem(.separator())
            menu.addItem(actionItem("Desactivar", action: #selector(deactivate)))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("Configuración…", action: #selector(showSettings), key: ","))
        menu.addItem(actionItem("Salir", action: #selector(quit), key: "q"))
    }

    func menuDidClose(_ menu: NSMenu) {
        sessionHeader = nil
        botHeader = nil
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Acciones

    @objc private func activate(_ sender: NSMenuItem) {
        model.session.activate(SessionDuration.menuOptions[sender.tag])
    }

    @objc private func deactivate() {
        model.session.deactivate()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func quit() {
        model.session.deactivate()
        // Da tiempo a que salga el aviso de fin por Telegram.
        Task {
            await model.notifier.flush(timeout: .seconds(5))
            NSApplication.shared.terminate(nil)
        }
    }
}
