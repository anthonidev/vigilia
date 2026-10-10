# Vigilia: plan de desarrollo

Basado en `IDEA.md`. App personal para la barra de menú de macOS, en Swift nativo.

---

## 1. Decisiones técnicas

| Tema | Decisión | Motivo |
|---|---|---|
| Lenguaje / UI | Swift 6; barra de menú con AppKit (`NSStatusItem` + `NSMenu`), ajustes con SwiftUI | `MenuBarExtra` no permite tooltip en el ícono; SwiftUI sigue siendo lo más simple para el formulario |
| macOS mínimo | macOS 27 | Es la versión que usas; no hace falta soportar versiones antiguas |
| Proyecto | Proyecto de Xcode, **sin dependencias externas** | Telegram se usa con `URLSession`; no hace falta ninguna librería |
| Sin Dock | `LSUIElement = YES` en Info.plist | Solo vive en la barra de menú |
| Firma | Apple ID gratis ("Personal Team") | Firma estable, así el permiso de Grabación de pantalla no se pierde al recompilar |
| Sandbox | Activado, con permiso de red saliente | Todo lo que usamos funciona dentro del sandbox |
| Mantener despierta | `IOPMAssertionCreateWithName` con `PreventUserIdleDisplaySleep` | Evita que se apaguen la pantalla y el sistema; se libera al terminar |
| Telegram | Long polling con `getUpdates` (timeout 50 s) | No hay que abrir puertos; se para solo con cancelar la tarea |
| Token | Keychain | Guardado seguro, como pide la idea |
| Otros ajustes | `UserDefaults`, envuelto en `AppSettings` (`@Observable`) | Simple, observable y testeable con un `UserDefaults` aislado |
| Capturas | ScreenCaptureKit (`SCScreenshotManager`) | API actual de Apple; la anterior (`CGWindowListCreateImage`) está obsoleta |
| Inicio con la Mac | `SMAppService.mainApp` | API actual, sin helper aparte |
| Concurrencia | Swift 6 estricto, `MainActor` por defecto; trabajo pesado con `@concurrent` | Sin carreras de datos; la codificación de capturas no bloquea la interfaz |
| Tests | Swift Testing | Lógica pura, más el bot completo con un Telegram y un capturador falsos |

## 2. Arquitectura

```
Vigilia/
├── App/                          // Composición y barra de menú
│   ├── VigiliaApp.swift          // @main y AppDelegate: crea todo y gestiona el cierre
│   ├── AppModel.swift            // Construye y conecta las piezas (raíz de composición)
│   ├── StatusItemController.swift// Ícono, tooltip y menú (AppKit)
│   ├── MenuBarIcon.swift         // Animación del ícono al activar
│   ├── MenuBarIconRenderer.swift // Estilos (taza, llama, foco) y sus dibujos
│   ├── StatusText.swift          // Textos de estado de la sesión y del bot
│   ├── SystemEventsMonitor.swift // Despertar la Mac y vuelta de la red
│   └── DebugLaunch.swift         // Solo Debug: atajos de arranque
├── Session/                      // Dominio: no depende de nada más
│   ├── SessionManager.swift      // Única fuente de verdad: activar, ampliar, fijar, desactivar, eventos
│   ├── SessionDuration.swift     // Duración, estado, eventos y motivos de fin
│   ├── DurationText.swift        // "1 h 30 min"
│   ├── TimeSource.swift          // Reloj inyectable
│   └── PowerAssertion.swift      // Aserción de energía de IOKit
├── Telegram/
│   ├── TelegramAPI.swift         // Cliente HTTP (actor) + protocolo TelegramClient
│   ├── TelegramModels.swift      // Codable de la Bot API
│   ├── MultipartFormData.swift   // Subida de archivos
│   ├── TelegramBot.swift         // Ciclo de vida y polling: cuándo encender, reconectar, apagar
│   ├── BotUpdateHandler.swift    // Cada mensaje: autorizar, vincular, responder, capturar
│   ├── BotCommand.swift          // Texto o botón → comando
│   ├── CommandRouter.swift       // Comando → acción sobre la sesión + respuesta (y textos del bot)
│   ├── DurationParser.swift      // "30m", "1h30m", "90" → minutos
│   ├── AccountLinker.swift       // Código de vinculación
│   └── SessionNotifier.swift     // Avisos automáticos
├── Screenshot/
│   ├── ScreenshotService.swift   // Permiso, pantallas y captura (ScreenCaptureKit)
│   ├── ScreenshotEncoder.swift   // JPEG/PNG fuera del hilo principal
│   ├── ScreenshotRequest.swift   // Qué capturar y con qué calidad
│   └── ScreenshotSender.swift    // Flujo de /captura
└── Settings/
    ├── SettingsWindowController.swift // Ventana propia que aloja la vista SwiftUI
    ├── SettingsView.swift        // Formulario de ajustes
    ├── AppSettings.swift         // UserDefaults observable
    ├── TelegramTokenStore.swift  // Token en el Keychain
    ├── KeychainStore.swift
    └── LoginItem.swift           // SMAppService
```

**Flujo central:**
- `SessionManager` es la única fuente de verdad. El menú y el bot solo llaman a sus métodos.
- Quien necesita reaccionar a la sesión la observa:
  - El **bot** observa (con Observation) si debe estar encendido: hay token, cuenta y sesión, o se está vinculando una cuenta. Se enciende y se apaga solo.
  - El **ícono** y los **avisos** reciben los eventos de la sesión (`observe`) de forma síncrona.
- Las dependencias van hacia dentro: `Session/` no conoce a nadie. `Telegram/` usa la sesión a través del protocolo `SessionControlling` y las capturas a través de `ScreenCapturing`, para poder usar falsos en los tests. `AppModel` es el único sitio que conecta las piezas reales.

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
