import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let token: TelegramTokenStore
    let loginItem: LoginItem
    let linker: AccountLinker
    let bot: TelegramBot
    let screenshots: ScreenshotService
    let icon: MenuBarIcon

    var body: some View {
        Form {
            Section("Telegram") {
                TokenRow(token: token, bot: bot)
                AccountRow(settings: settings, token: token, linker: linker, bot: bot)
                Toggle("Activar bot", isOn: $settings.botEnabled)
                Toggle("Avisos automáticos", isOn: $settings.notificationsEnabled)
                    .disabled(!settings.botEnabled)
            }

            Section("Capturas de pantalla") {
                ScreenRecordingRow(screenshots: screenshots)
            }

            Section("Apariencia") {
                IconStylePicker(selection: $settings.iconStyle) {
                    // Muestra la animación en la barra para ver cómo queda.
                    icon.playAnimation()
                }
            }

            Section("General") {
                LoginItemRow(loginItem: loginItem)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { loginItem.refresh() }
    }
}

// MARK: - Token

private struct TokenRow: View {
    let token: TelegramTokenStore
    let bot: TelegramBot

    @State private var draft = ""
    @State private var message: Message?
    @State private var isTesting = false

    private enum Message {
        case error(String)
        case success(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Token del bot")

            HStack {
                SecureField(
                    "Token del bot",
                    text: $draft,
                    prompt: Text(token.hasToken ? "Pega uno nuevo para reemplazarlo" : "123456789:AAH…")
                )
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .onSubmit(save)

                Button("Guardar", action: save)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Group {
                switch message {
                case .error(let text):
                    Text(text).foregroundStyle(.red)
                case .success(let text):
                    Label(text, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case nil:
                    if token.hasToken {
                        HStack(spacing: 12) {
                            Label("Guardado en el Llavero", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Button(isTesting ? "Probando…" : "Probar", action: test)
                                .buttonStyle(.link)
                                .disabled(isTesting)
                            Button("Borrar", role: .destructive, action: delete)
                                .buttonStyle(.link)
                        }
                    } else {
                        Text("Créalo con @BotFather en Telegram.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout)
        }
        .onChange(of: draft) { message = nil }
    }

    private func save() {
        do {
            try token.save(draft)
            draft = ""
            message = nil
            test()
        } catch TelegramTokenStore.TokenError.invalidFormat {
            message = .error("No parece un token de BotFather.")
        } catch {
            message = .error("No se pudo guardar en el Llavero.")
        }
    }

    private func test() {
        isTesting = true
        Task {
            defer { isTesting = false }
            do {
                let me = try await bot.testToken()
                message = .success("Conectado con \(me.displayName)")
            } catch TelegramError.invalidToken {
                message = .error("Telegram rechazó el token.")
            } catch TelegramError.network {
                message = .error("Sin conexión con Telegram.")
            } catch {
                message = .error("No se pudo comprobar el token.")
            }
            try? await Task.sleep(for: .seconds(4))
            message = nil
        }
    }

    private func delete() {
        do {
            try token.delete()
        } catch {
            message = .error("No se pudo borrar del Llavero.")
        }
    }
}

// MARK: - Cuenta

private struct AccountRow: View {
    let settings: AppSettings
    let token: TelegramTokenStore
    let linker: AccountLinker
    let bot: TelegramBot

    /// Usuario del bot (sin @), para el enlace que abre Telegram con el código.
    @State private var botUsername: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Cuenta autorizada") {
                if let id = settings.authorizedUserID, !linker.isLinking {
                    HStack {
                        // `verbatim`: si no, SwiftUI formatea el ID con separador de miles.
                        Text(verbatim: settings.authorizedUserName.map { "@\($0)" } ?? String(id))
                            .help(Text(verbatim: "ID de Telegram: \(id)"))
                        Button("Desvincular", role: .destructive) {
                            settings.unlinkAccount()
                        }
                        .buttonStyle(.link)
                    }
                } else if !linker.isLinking {
                    HStack {
                        Text("No vinculada").foregroundStyle(.secondary)
                        Button("Vincular…", action: startLinking)
                            .disabled(!token.hasToken)
                    }
                }
            }

            switch linker.state {
            case .waiting(let code, _):
                LinkingInstructions(code: code, botUsername: botUsername, cancel: linker.cancel)
            case .finished(let outcome):
                outcomeText(outcome)
                    .font(.callout)
                    .task {
                        try? await Task.sleep(for: .seconds(6))
                        linker.reset()
                    }
            case .idle:
                if !token.hasToken, !settings.isAccountLinked {
                    Text("Guarda primero el token del bot.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func outcomeText(_ outcome: AccountLinker.Outcome) -> some View {
        switch outcome {
        case .linked(let name):
            Label("Vinculada con \(name)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .expired:
            Text("El código caducó. Vuelve a intentarlo.").foregroundStyle(.secondary)
        case .tooManyAttempts:
            Text("Demasiados códigos incorrectos. Vuelve a intentarlo.").foregroundStyle(.red)
        case .cancelled:
            EmptyView()
        }
    }

    private func startLinking() {
        linker.start()
        Task {
            botUsername = try? await bot.testToken().username
        }
    }
}

private struct LinkingInstructions: View {
    let code: String
    let botUsername: String?
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Envía este mensaje a tu bot en Telegram:")
                .foregroundStyle(.secondary)

            HStack {
                Text("/vincular \(code)")
                    .font(.title3.monospaced())
                    .textSelection(.enabled)
                Button("Copiar", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("/vincular \(code)", forType: .string)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }

            HStack {
                if let botUsername, let url = URL(string: "https://t.me/\(botUsername)?start=\(code)") {
                    Link("Abrir en Telegram", destination: url)
                }
                Spacer()
                Button("Cancelar", action: cancel)
            }

            Text("El código caduca en 5 minutos.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

// MARK: - Grabación de pantalla

private struct ScreenRecordingRow: View {
    let screenshots: ScreenshotService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Grabación de pantalla") {
                if screenshots.hasPermission {
                    Label("Concedido", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        Text("No concedido").foregroundStyle(.secondary)
                        Button("Conceder…") { screenshots.requestPermission() }
                    }
                }
            }

            if !screenshots.hasPermission {
                HStack(spacing: 4) {
                    Text("Solo hace falta para /captura.")
                        .foregroundStyle(.secondary)
                    Button("Abrir Ajustes del Sistema") { screenshots.openSystemSettings() }
                        .buttonStyle(.link)
                }
                .font(.callout)
            }
        }
        // Al volver de Ajustes del Sistema, la app se activa: es el momento de volver a mirar.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            screenshots.refreshPermission()
        }
        .onAppear { screenshots.refreshPermission() }
    }
}

// MARK: - Ícono

private struct IconStylePicker: View {
    @Binding var selection: IconStyle
    let onSelect: () -> Void

    var body: some View {
        LabeledContent("Ícono de la barra") {
            HStack(spacing: 8) {
                ForEach(IconStyle.allCases) { style in
                    let isSelected = style == selection
                    Button {
                        selection = style
                        onSelect()
                    } label: {
                        VStack(spacing: 4) {
                            Image(nsImage: MenuBarIconRenderer.image(style: style, active: true, frame: nil))
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 26)
                                .foregroundStyle(.primary)
                            Text(style.title)
                                .font(.caption)
                        }
                        .frame(width: 60, height: 58)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                            in: .rect(cornerRadius: 8)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Inicio con la Mac

private struct LoginItemRow: View {
    let loginItem: LoginItem

    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Iniciar Vigilia al encender la Mac", isOn: Binding(
                get: { loginItem.isEnabled || loginItem.requiresApproval },
                set: { enabled in
                    do {
                        try loginItem.setEnabled(enabled)
                        error = nil
                    } catch {
                        self.error = "macOS no lo permitió: \(error.localizedDescription)"
                    }
                }
            ))

            if loginItem.requiresApproval {
                HStack(spacing: 4) {
                    Text("Falta aprobarlo en Ítems de inicio.")
                        .foregroundStyle(.secondary)
                    Button("Abrir Ajustes del Sistema") { loginItem.openSystemSettings() }
                        .buttonStyle(.link)
                }
                .font(.callout)
            }

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }
}
