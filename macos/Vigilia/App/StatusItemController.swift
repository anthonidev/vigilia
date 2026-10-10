import AppKit
import Observation

/// Ícono y menú de la barra de menú, con AppKit: `MenuBarExtra` no permite un tooltip en el ícono.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let openSettings: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    /// Cabeceras del menú abierto, para actualizarlas en vivo.
    private weak var sessionHeader: NSMenuItem?
    private weak var botHeader: NSMenuItem?
    /// Último texto mostrado: el tiempo restante cambia cada segundo, pero el texto solo cada minuto.
    private var shownStatus: String?
    private var shownBotStatus: String?

    init(model: AppModel, openSettings: @escaping () -> Void) {
        self.model = model
        self.openSettings = openSettings
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        track { [weak self] in self?.updateIcon() }
        track { [weak self] in self?.updateStatus() }
    }

    // MARK: - Ícono y tooltip

    /// Ejecuta `update` ahora y cada vez que cambie algo de lo que lee.
    private func track(_ update: @escaping @MainActor () -> Void) {
        withObservationTracking {
            update()
        } onChange: { [weak self] in
            Task { @MainActor in self?.track(update) }
        }
    }

    /// Solo cuando cambia el estado, la animación o el estilo; no con cada segundo de la sesión.
    private func updateIcon() {
        statusItem.button?.image = model.icon.image(active: model.session.isActive)
    }

    private func updateStatus() {
        let status = model.session.statusText
        let botStatus = botStatus
        guard status != shownStatus || botStatus != shownBotStatus else { return }
        shownStatus = status
        shownBotStatus = botStatus

        statusItem.button?.toolTip = status
        statusItem.button?.setAccessibilityLabel("Vigilia, \(status)")
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
        // AppDelegate desactiva la sesión y espera al aviso de fin antes de cerrar.
        NSApplication.shared.terminate(nil)
    }
}
