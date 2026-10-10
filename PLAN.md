# Vigilia: plan de desarrollo

Basado en `IDEA.md`. App personal para la barra de menú de macOS, en Swift nativo.

---

## 1. Decisiones técnicas

| Tema | Decisión | Motivo |
|---|---|---|
| Lenguaje / UI | Swift 6 + SwiftUI (`MenuBarExtra` + escena `Settings`) | Nativo, poco código, menú y ajustes resueltos por el sistema |
| macOS mínimo | macOS 27 | Es la versión que usas; no hace falta soportar versiones antiguas |
| Proyecto | Proyecto de Xcode, **sin dependencias externas** | Telegram se usa con `URLSession`; no hace falta ninguna librería |
| Sin Dock | `LSUIElement = YES` en Info.plist | Solo vive en la barra de menú |
| Firma | Apple ID gratis ("Personal Team") | Firma estable, así el permiso de Grabación de pantalla no se pierde al recompilar |
| Sandbox | Activado, con permiso de red saliente | Todo lo que usamos funciona dentro del sandbox |
| Mantener despierta | `IOPMAssertionCreateWithName` con `PreventUserIdleDisplaySleep` | Evita que se apaguen la pantalla y el sistema; se libera al terminar |
| Telegram | Long polling con `getUpdates` (timeout 50 s) | No hay que abrir puertos; se para solo con cancelar la tarea |
| Token | Keychain | Guardado seguro, como pide la idea |
| Otros ajustes | `UserDefaults` / `@AppStorage` | Simple |
| Capturas | ScreenCaptureKit (`SCScreenshotManager`) | API actual de Apple; la anterior (`CGWindowListCreateImage`) está obsoleta |
| Inicio con la Mac | `SMAppService.mainApp` | API actual, sin helper aparte |
| Tests | Swift Testing | Para la lógica pura: parser, sesión y comandos |

## 2. Arquitectura

```
Vigilia/
├── App/
│   ├── VigiliaApp.swift          // @main: MenuBarExtra + Settings
│   └── MenuContent.swift         // Opciones del menú desplegable
├── Session/
│   ├── SessionManager.swift      // @Observable @MainActor: estado, fin, activar/ampliar/fijar/desactivar
│   ├── SessionDuration.swift     // enum: .indefinite / .minutes(n)
│   └── PowerAssertion.swift      // Envuelve IOKit (crear/liberar aserción)
├── Telegram/
│   ├── TelegramAPI.swift         // Cliente HTTP: getUpdates, sendMessage, sendPhoto, sendDocument, sendMediaGroup…
│   ├── TelegramModels.swift      // Codable: Update, Message, CallbackQuery, InlineKeyboard…
│   ├── TelegramBot.swift         // Bucle de polling, filtra por usuario autorizado, enruta comandos
│   ├── CommandRouter.swift       // Comando → acción sobre SessionManager / capturas
│   ├── DurationParser.swift      // "30m", "1h", "1h30m", "90" → minutos
│   └── AccountLinker.swift       // Código de vinculación de la cuenta
├── Screenshot/
│   └── ScreenshotService.swift   // Lista pantallas, captura, codifica JPEG/PNG
├── Settings/
│   ├── SettingsView.swift
│   ├── AppSettings.swift         // @AppStorage: bot activo, avisos, ID autorizado…
│   ├── KeychainStore.swift
│   └── LoginItem.swift           // SMAppService
└── VigiliaTests/
```

**Flujo central:** `SessionManager` es la única fuente de verdad. El menú y el bot solo llaman a sus métodos y observan su estado. Cuando la sesión se activa o termina, `SessionManager` enciende o apaga el bot (si está habilitado) y la aserción de energía.

## 3. Fases

El detalle de cada fase (tareas, archivos, tests y criterios de aceptación) está en **`FASES.md`**.

0. Proyecto base
1. Mantener despierta (primera versión usable)
2. Configuración
3. Bot de Telegram
4. Avisos automáticos
5. Capturas remotas
6. Robustez y pulido

## 4. Casos límite (decididos; dime si prefieres otra cosa)

- **`/mas` con sesión indefinida:** responde "La sesión ya es indefinida".
- **Aviso de 10 min:** solo si la sesión tenía más de 10 min por delante. Si amplías y vuelves a tener más de 10 min, el aviso se rearma.
- **Bot apagado en Ajustes:** la app funciona solo como "mantener despierta".
- **Sesión activa sin cuenta vinculada:** el bot no arranca, porque no tendría a quién obedecer.
- **Formatos de duración:** `30m`, `2h`, `1h30m`, y un número suelto se interpreta como minutos. Máximo 24 h por comando.
- **Pantalla bloqueada:** la captura muestra la pantalla de bloqueo (ya está en las limitaciones).

## 5. Limitaciones a tener en cuenta

- Las de `IDEA.md` (tapa cerrada, pantalla bloqueada, sin cifrado de extremo a extremo).
- Las versiones recientes de macOS vuelven a preguntar cada cierto tiempo si se sigue permitiendo la Grabación de pantalla. Es un comportamiento del sistema y no se puede evitar.
- Con el Apple ID gratis, el certificado dura un año. Xcode lo renueva al recompilar.

## 6. Fuera de alcance por ahora

Todo lo de "Ideas para el futuro" y la versión de Windows. La arquitectura deja espacio para añadirlos: por ejemplo, "mientras una app esté abierta" sería otra forma de terminar una sesión dentro de `SessionManager`.
