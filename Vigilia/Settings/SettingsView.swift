import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let token: TelegramTokenStore
    let loginItem: LoginItem

    var body: some View {
        Form {
            Section("Telegram") {
                TokenRow(token: token)
                AccountRow(settings: settings)
                Toggle("Activar bot", isOn: $settings.botEnabled)
                Toggle("Avisos automáticos", isOn: $settings.notificationsEnabled)
                    .disabled(!settings.botEnabled)
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

    @State private var draft = ""
    @State private var error: String?

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
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                } else if token.hasToken {
                    HStack(spacing: 8) {
                        Label("Guardado en el Llavero", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Button("Borrar", role: .destructive, action: delete)
                            .buttonStyle(.link)
                    }
                } else {
                    Text("Créalo con @BotFather en Telegram.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
        .onChange(of: draft) { error = nil }
    }

    private func save() {
        do {
            try token.save(draft)
            draft = ""
            error = nil
        } catch TelegramTokenStore.TokenError.invalidFormat {
            error = "No parece un token de BotFather."
        } catch {
            self.error = "No se pudo guardar en el Llavero."
        }
    }

    private func delete() {
        do {
            try token.delete()
        } catch {
            self.error = "No se pudo borrar del Llavero."
        }
    }
}

// MARK: - Cuenta

private struct AccountRow: View {
    let settings: AppSettings

    var body: some View {
        LabeledContent("Cuenta autorizada") {
            if let id = settings.authorizedUserID {
                HStack {
                    Text(settings.authorizedUserName.map { "@\($0) (\(id))" } ?? "\(id)")
                    Button("Desvincular", role: .destructive) {
                        settings.unlinkAccount()
                    }
                    .buttonStyle(.link)
                }
            } else {
                // El botón Vincular llega con el bot, en la fase 3.
                Text("No vinculada")
                    .foregroundStyle(.secondary)
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
                    Button("Abrir Ajustes del Sistema") { loginItem.openSystemSettings() }
                        .buttonStyle(.link)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }
}
