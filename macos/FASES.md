# Vigilia: fases de implementación

Detalle de cada fase. La visión general y las decisiones técnicas están en `PLAN.md`.

**Base:** macOS 27, Xcode 27, Swift 6.4, SwiftUI, sin dependencias externas.

**Cómo usar este documento:**
- Cada fase tiene un objetivo, tareas, archivos, criterios de aceptación y pruebas manuales.
- Una fase está terminada cuando se cumplen todos sus criterios de aceptación. Entonces se hace un commit y se pasa a la siguiente.
- Las fases van en orden: cada una depende de las anteriores.

---

## Fase 0: Proyecto base ✅

**Objetivo:** un proyecto que compila, se ejecuta solo en la barra de menú y tiene tests.

### Tareas
- [x] Iniciar git con un `.gitignore` para Xcode (`xcuserdata/`, `DerivedData/`, `.DS_Store`, `build/`).
- [x] Crear el proyecto `Vigilia.xcodeproj` (macOS App, SwiftUI, Swift Testing), con carpetas sincronizadas: los archivos nuevos dentro de `Vigilia/` y `VigiliaTests/` se añaden solos al target.
  - Bundle ID: `com.tonis.vigilia`
  - Deployment target: macOS 27.0
  - Swift 6 con *strict concurrency* `complete`, *default actor isolation* = `MainActor` y *approachable concurrency*
- [x] Firma: *Automatically manage signing* con el Personal Team (`RS79YL6DLM`) en la app y en los tests. La app se firma con el certificado *Apple Development* y el hardened runtime.
- [x] Info.plist generado por Xcode (`INFOPLIST_KEY_*` en los build settings): `LSUIElement = YES` y `CFBundleDisplayName = Vigilia`.
- [x] Entitlements (`Vigilia/Vigilia.entitlements`): App Sandbox y `com.apple.security.network.client`.
- [x] Target `VigiliaTests` con Swift Testing y un test de humo.
- [x] Esquema compartido `Vigilia` (compilar, ejecutar y tests).
- [x] `VigiliaApp.swift` con un `MenuBarExtra` mínimo (ícono `cup.and.saucer`) y un botón **Salir** (⌘Q).
- Las carpetas `Session/`, `Telegram/`, `Screenshot/` y `Settings/` se crean en la fase en que se usan, porque git no guarda carpetas vacías.

### Archivos
`Vigilia.xcodeproj` (con su esquema compartido), `Vigilia/App/VigiliaApp.swift`, `Vigilia/Vigilia.entitlements`, `VigiliaTests/VigiliaTests.swift`, `.gitignore`

### Criterios de aceptación
- [x] `xcodebuild build` y `xcodebuild test` pasan sin warnings de nuestro código.
- [x] Al ejecutar, aparece la taza en la barra de menú y **no** hay ícono en el Dock (el proceso es de tipo `UIElement`).
- [x] **Salir** cierra la app.

### Comandos útiles
```sh
xcodebuild -project Vigilia.xcodeproj -scheme Vigilia -derivedDataPath build/DerivedData build
xcodebuild -project Vigilia.xcodeproj -scheme Vigilia -derivedDataPath build/DerivedData test
open build/DerivedData/Build/Products/Debug/Vigilia.app
```

---

## Fase 1: Mantener despierta ✅

**Objetivo:** la app ya es útil sin bot. Elige un tiempo y la Mac no se duerme.

### Tareas

**Modelo (`Session/`)**
- [x] `SessionDuration`: `enum { case indefinite; case minutes(Int) }`, con la lista de opciones del menú (10 m, 30 m, 1 h, 2 h, 4 h, 8 h, 12 h, indefinido) y un texto para mostrar ("2 h", "Indefinido").
- [x] `SessionState`: `.inactive` o `.active(endDate: Date?)`, donde `nil` significa indefinida.
- [x] Protocolo `Clock` (`now: Date`) con una implementación real y otra falsa para tests.
- [x] `PowerAssertion`:
  - `acquire()`: `IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep, …, "Vigilia mantiene la Mac despierta")`
  - `release()`: `IOPMAssertionRelease`
  - Es idempotente (llamarla dos veces no duplica la aserción) y se libera también en `deinit`.
- [x] `SessionManager` (`@Observable`, `@MainActor`):
  - `state`, `remaining: Duration?`, `isActive`
  - `activate(_ duration:)`: reemplaza cualquier sesión activa
  - `extend(by minutes:)`: suma tiempo; si es indefinida, no hace nada y devuelve `.alreadyIndefinite`
  - `set(_ minutes:)`: reemplaza el tiempo restante
  - `makeIndefinite()`, `deactivate()`
  - Un temporizador interno (un `Task` con `Task.sleep`) que comprueba la hora de fin y termina la sesión al llegar.
  - Un `AsyncStream<SessionEvent>` de eventos (`.started`, `.changed`, `.ended(reason)`) que usarán el bot y los avisos; admite varios oyentes. `.tenMinutesLeft` se añade en la fase 4.
  - **La sesión guarda la hora de fin, no un contador.**

**Interfaz (`App/`)**
- [x] `MenuContent`:
  - Si hay sesión activa: "Activa · quedan 1 h 23 min" (o "Activa · indefinida"), deshabilitado y como cabecera.
  - Las duraciones, con una marca en la elegida.
  - **Desactivar**, visible solo si hay sesión.
  - **Configuración…** (por ahora vacío).
  - **Salir**.
- [x] El ícono cambia: `cup.and.saucer` cuando está inactiva y `cup.and.saucer.fill` cuando está activa.
- [x] El tiempo restante se actualiza cada segundo mientras hay sesión (`tick()`), y el menú lo refleja.
- [x] Tooltip con el tiempo restante al pasar el cursor. Para eso, el ícono y el menú usan AppKit (`StatusItemController`: `NSStatusItem` + `NSMenu`) en vez de `MenuBarExtra`, que no lo permite. Los ajustes son una ventana propia con SwiftUI (`SettingsWindowController`). El menú abierto se actualiza en vivo cada segundo.
- [x] Al salir con una sesión activa, se libera la aserción.
- [x] **Animación del vapor** (`CupIcon`, `MenuBarIcon`): al iniciar o cambiar una sesión, el vapor sube unos 3 s desde la taza y se desvanece. Se dibuja cuadro a cuadro (~20 fps), porque el ícono de la barra no admite animaciones de SwiftUI. No se anima si está activado "Reducir movimiento".
- [x] Solo en Debug: `open Vigilia.app --args -activate 10` (o `indefinite`) inicia una sesión al arrancar, para probar sin hacer clic.

### Tests (`VigiliaTests/SessionManagerTests.swift`)
- Activar 30 m → activa, con fin = ahora + 30 m.
- Activar con una sesión activa → se reemplaza el tiempo.
- `extend` suma bien y no tiene efecto si la sesión es indefinida.
- `set` reemplaza el tiempo.
- Al pasar la hora de fin (reloj falso) → inactiva, y se emite el evento `.ended`.
- `deactivate` libera la aserción (con un `PowerAssertion` falso detrás de un protocolo).

### Criterios de aceptación
- [x] Test de integración `PowerAssertionTests`: con la aserción real, el sistema registra la de Vigilia y la quita al liberarla.
- [x] Con una sesión activa, `pmset -g assertions` muestra la aserción de Vigilia `PreventUserIdleDisplaySleep`.
- [ ] Al desactivar o al acabarse el tiempo, la aserción desaparece.
- [ ] Con una sesión de 10 min, la pantalla no se apaga aunque el apagado de pantalla esté configurado en 2 min.
- [x] Todos los tests pasan (22).

### Pruebas manuales
1. Activar 10 min y comprobar la aserción con `pmset -g assertions | grep -i vigilia`.
2. Esperar a que termine y confirmar que la aserción se fue.
3. Activar 1 h y luego elegir 30 min: el tiempo restante pasa a ~30 min.

---

## Fase 2: Configuración ✅

**Objetivo:** una ventana de ajustes funcional, con el token guardado de forma segura.

### Tareas
- [x] `KeychainStore`: `save(token:)`, `loadToken()`, `deleteToken()` (`kSecClassGenericPassword`, servicio `com.tonis.vigilia`, cuenta `telegram-bot-token`).
- [x] `AppSettings` (`@Observable`, sobre `UserDefaults`):
  - `botEnabled: Bool` (por defecto `false`)
  - `notificationsEnabled: Bool` (por defecto `true`)
  - `authorizedUserID: Int64?`
  - `authorizedUserName: String?` (solo para mostrarlo)
- [x] `TelegramTokenStore`: el token en el Keychain, con `hasToken` observable.
- [x] `LoginItem`: un envoltorio de `SMAppService.mainApp` con `isEnabled` y `setEnabled(_:)`. El estado se lee del sistema, no se guarda en `UserDefaults`.
- [x] `SettingsView` (escena `Settings`, un `Form` agrupado):
  - **Telegram**
    - Token en un `SecureField` con **Guardar**; se valida el formato de BotFather y se puede **Borrar**. El botón **Probar** (`getMe`) llega en la fase 3.
    - Cuenta autorizada: "No vinculada" o "@usuario (id)", con **Desvincular**. El botón **Vincular…** llega en la fase 3.
    - Interruptor **Activar bot**.
    - Interruptor **Avisos automáticos**.
  - **General**
    - Interruptor **Iniciar Vigilia al encender la Mac**.
- [x] Abrir Ajustes desde el menú con `SettingsLink` o `openSettings`, y además `NSApp.activate()`. Una app sin Dock no trae la ventana al frente por sí sola.

### Tests
- `KeychainStore`: guardar, leer y borrar en un servicio de pruebas.
- `AppSettings`: valores por defecto y persistencia (con un `UserDefaults(suiteName:)` aislado).

### Criterios de aceptación
- [x] El token aparece en **Acceso a Llaveros** bajo `com.tonis.vigilia` y no está en `UserDefaults`.
- [x] Los interruptores se mantienen tras reiniciar la app.
- [ ] **Iniciar con la Mac** aparece en Ajustes del Sistema → General → Ítems de inicio, y funciona al reiniciar sesión.
- [x] La ventana de ajustes se abre al frente (comprobado con `-openSettings YES`, que usa el mismo `openSettings`).
- Nota: hasta elegir el Team de firma, la firma cambia en cada compilación y macOS puede preguntar si Vigilia puede acceder a su ítem del Llavero. Con el Personal Team deja de pasar.

---

## Fase 3: Bot de Telegram (núcleo) ✅

**Objetivo:** controlar la sesión desde Telegram, de forma segura.

### Tareas

**Modelos y cliente (`Telegram/TelegramModels.swift`, `TelegramAPI.swift`)**
- [x] Modelos `Codable` con `convertFromSnakeCase`: `Update`, `Message`, `User`, `Chat`, `CallbackQuery`, `InlineKeyboardMarkup`, `InlineKeyboardButton`, y un `Response<T>` con `ok`, `result` y `description`.
- [x] `TelegramAPI`: un `actor` que recibe el token, con `URLSession` y `async/await`:
  - `getMe()`
  - `getUpdates(offset:timeout:)`, con un timeout de petición > 50 s
  - `sendMessage(chatID:text:keyboard:)`
  - `editMessageReplyMarkup(...)`, para quitar los botones de avisos antiguos (se usa en la fase 4)
  - `answerCallbackQuery(id:text:)`
  - `setMyCommands(_:)`
  - Errores tipados: `.invalidToken` (401), `.conflict` (409, otro proceso usa el bot), `.network`, `.api(description)`.

**Lógica pura (testeable)**
- [x] `DurationParser`: `"30m"`, `"2h"`, `"1h30m"`, `"90"` (minutos), `"1.5h"` → minutos. Rechaza 0, negativos y más de 24 h.
- [x] `BotCommand`: un `enum` que se obtiene del texto (`/estado`, `/mas <d>`, `/set <d>`, `/indefinido`, `/off`, `/captura [hd]`, `/ayuda`, `/vincular <código>`). Acepta `/comando@NombreBot` y mayúsculas.
- [x] `CommandRouter` (`/captura` responde "llegarán pronto" hasta la fase 5): recibe un `BotCommand` y devuelve una respuesta (texto + teclado), actuando sobre un protocolo `SessionControlling` que implementa `SessionManager`.
- [x] Textos de respuesta en español, centralizados en un archivo (`BotStrings`).

**Bot (`TelegramBot.swift`)**
- [x] `start()` y `stop()`. El bucle es un `Task` que se cancela al parar.
- [x] Al arrancar:
  1. Descartar los mensajes pendientes con `getUpdates(offset: -1)` y guardar el siguiente `offset`.
  2. Registrar los comandos con `setMyCommands`.
- [x] Bucle: `getUpdates` → por cada update, **autorizar** → enrutar → responder.
- [x] **Autorización:** solo se procesan updates de chats `private` cuyo `from.id == authorizedUserID`. El resto se ignora sin responder.
- [x] Errores: si falla la red, se reintenta con espera creciente (1, 2, 4… hasta 60 s). Con 401, el bot se para y se marca el error en el menú. Con 409 se reintenta 3 veces (suele ser la conexión anterior que aún no se cerró) y después se para con un aviso.
- [x] Si el bot se va a apagar mientras responde (por ejemplo, tras `/off` o al terminar la vinculación), primero termina de responder.
- [x] Botones en línea `[+30 min] [+1 h] [+2 h]` / `[Apagar] [Captura]`, con `callback_data` del tipo `ext:30`, `off`, `shot`.

**Vinculación (`AccountLinker.swift`)**
- [x] **Vincular…** en Ajustes (además del comando, hay un botón **Abrir en Telegram** con el enlace `t.me/<bot>?start=<código>`, que envía `/start <código>` con un toque):
  1. Genera un código aleatorio de 6 dígitos, válido 5 minutos.
  2. Arranca el bot en modo vinculación (aunque no haya sesión).
  3. Muestra: "Envía `/vincular 482913` a @TuBot".
- [x] En modo vinculación, el **único** comando aceptado de usuarios desconocidos es `/vincular <código>`.
- [x] Si el código es correcto, guarda `from.id` y `@username`, responde "Cuenta vinculada" y sale del modo vinculación. Después, el bot se para si no hay sesión activa.
- [x] Tras 5 intentos fallidos o al caducar el código, se cancela la vinculación.

**Integración**
- [x] `SessionManager` arranca el bot al empezar una sesión y lo para al terminarla, si `botEnabled`, hay token y hay cuenta vinculada.
- [x] El menú muestra el estado del bot: "Bot conectado", "Bot: token inválido", etc.
- [x] El botón **Probar** de Ajustes llama a `getMe` y muestra "@NombreBot ✓" o el error.

### Tests (64 en total en el proyecto)
- `DurationParser`: todos los formatos válidos e inválidos.
- `BotCommand`: análisis de texto, incluido `@NombreBot` y argumentos que faltan.
- `CommandRouter` con un `SessionControlling` falso: cada comando produce la acción y la respuesta correctas, incluido `/mas` con sesión indefinida.
- Autorización: un update de otro `from.id` no produce ninguna respuesta; uno de un grupo con tu ID tampoco.
- `AccountLinker`: código correcto, incorrecto, caducado y demasiados intentos.

### Criterios de aceptación
Probado con el bot real el 2026-10-10. Los marcados con *(tests)* están cubiertos además con el Telegram falso.
- [x] Con un token falso, la API real de Telegram responde 401 y la app lo trata como token inválido (la red funciona desde el sandbox).
- [x] Vincular la cuenta desde Ajustes funciona de principio a fin.
- [x] Con una sesión activa, todos los comandos de `docs/IDEA.md` funcionan (excepto `/captura`).
- [x] Los botones `+30 min` y `Apagar` funcionan, y el botón deja de mostrar el reloj de carga.
- [x] (tests) Un mensaje desde otra cuenta no recibe respuesta.
- [x] (tests) Al desactivar la sesión, el bot deja de responder.
- [x] (tests) Un `/off` enviado con el bot apagado **no** afecta a la siguiente sesión.

---

## Fase 4: Avisos automáticos ✅

**Objetivo:** el bot te informa sin que preguntes.

### Tareas
- [x] `SessionNotifier` escucha la sesión (de forma síncrona, con `SessionManager.observe`):
  - `.started` → "☕ Vigilia activa por 2 h", con botones de control (o "…de forma indefinida").
  - `.tenMinutesLeft` → "⏳ Quedan 10 min. ¿Ampliar?", con `[+30 min] [+1 h] [+2 h] [Dejar terminar]`.
  - `.ended` → "😴 Sesión terminada. Tu Mac ya puede dormir." (o "desactivada desde la Mac").
- [x] `SessionManager` emite `.tenMinutesLeft` una sola vez por sesión, y solo si quedaban más de 10 min. Si se amplía por encima de 10 min, el aviso se rearma.
- [x] Los avisos se envían con un cliente propio, sin depender del polling. Así el aviso de fin sale aunque el bot ya se haya apagado y no importa el orden. Al pulsar **Salir**, la app espera hasta 5 s a que salga el aviso.
- [x] Un `/off` desde Telegram no genera aviso de fin: el bot ya respondió (`SessionEndReason.deactivatedRemotely`).
- [x] Al pulsar cualquier botón, se quitan los botones de ese mensaje con `editMessageReplyMarkup`. La respuesta trae botones nuevos.
- [x] Se respeta `notificationsEnabled`, además de que el bot esté activado y la cuenta vinculada.
- [x] Si la sesión termina mientras la Mac duerme, el aviso sale al despertar e indica a qué hora terminó. Si la red aún no está lista, se reintenta a los 5 y 15 s.

### Tests
- [x] Activar 30 m y avanzar el reloj 20 m → `.tenMinutesLeft` se emite una vez.
- [x] Activar 10 m → no se emite.
- [x] Ampliar después del aviso → se rearma.
- [x] Dormir más allá del final → no hay aviso de 10 min; el de fin lleva la hora real.
- [x] Con los avisos o el bot desactivados, o sin cuenta, no se envía nada.
- [x] El aviso de fin ya está en marcha cuando `deactivate()` vuelve (lo que usa **Salir**).

### Criterios de aceptación
- [x] Los tres avisos llegan con sesiones reales cortas (por ejemplo, de 12 minutos con `/set 12m`).
- [x] El aviso de fin sale aunque el bot se apague, porque no depende del polling.

---

## Fase 5: Capturas remotas ✅

**Objetivo:** ver tu pantalla desde el celular.

### Tareas
- [x] `ScreenshotService` (`@MainActor`, `ScreenCapturing`):
  - `hasPermission` / `requestPermission()`: `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()`
  - `displays()`: las pantallas de `SCShareableContent`, con el nombre de `NSScreen.localizedName` (emparejando por `CGDirectDisplayID`), la principal primero.
  - `capture(_:)`: `SCScreenshotManager.captureImage` a resolución nativa (`contentRect × pointPixelScale`), con el cursor.
- [x] `ScreenshotEncoder` (`@concurrent`, fuera del hilo principal):
  - `normal`: lado mayor ≤ 2560 px, JPEG con calidad 0.75.
  - `hd`: PNG a resolución completa.
- [x] `TelegramAPI`: `send(_:)` (`sendPhoto`/`sendDocument`), `sendMediaGroup` y `sendChatAction`, con `MultipartFormData`.
- [x] `ScreenshotSender`, para `/captura` o el botón **Captura**:
  - Una pantalla → la captura y la envía.
  - Varias pantallas → un botón por pantalla con su nombre, más **Todas** (`callback_data` `shot:<id>:<n|hd>` / `shot:all:<n|hd>`).
  - **Todas** → un álbum con `sendMediaGroup` (máximo 10).
  - El pie de foto indica la pantalla y la hora: "Pantalla integrada · 14:32".
- [x] `/captura hd` → el mismo flujo, enviado como documento PNG `vigilia-2026-10-09-1432.png` (con `-1`, `-2`… si son varias).
- [x] Sin permiso: el bot explica dónde darlo y la Mac muestra la solicitud del sistema.
- [x] Pantalla desconectada entre la pregunta y el botón: el bot lo dice.
- [x] Ajustes: sección **Capturas de pantalla** con *Concedido / No concedido*, **Conceder…** y un enlace a Ajustes del Sistema. Se vuelve a comprobar al volver a la app.

### Tests
- [x] `ScreenshotEncoder`: una imagen 6016×3384 queda en 2560 px de lado mayor, < 10 MB, en JPEG. HD mantiene el tamaño y es PNG.
- [x] `MultipartFormData`: cuerpo exacto.
- [x] `callback_data` de capturas: ida y vuelta, y ≤ 64 bytes.
- [x] `ScreenshotSender` con un capturador falso: sin permiso, una pantalla, HD, varias pantallas, elegida, todas y desconectada.
- [x] Bot: el botón Captura envía una foto; otra cuenta no puede pedir capturas.

### Criterios de aceptación
- [x] `/captura` con una pantalla → llega una foto legible al celular en pocos segundos.
- [x] `/captura hd` → llega un PNG con la resolución nativa.
- [ ] Con monitor externo → aparecen botones con los nombres reales, y **Todas** envía un álbum. *(Cubierto por tests; falta probarlo con un monitor externo real.)*
- [x] Sin permiso → mensaje claro, sin errores ni cierres (tests).
- [x] Recompilar no hace perder el permiso (gracias a la firma estable): una compilación de desarrollo nueva capturó la pantalla integrada a 3024×1964 (normal 609 KB, HD 1 MB, 0,13 s).

---

## Fase 6: Robustez y pulido 🟡 código listo, falta la prueba de un día real

**Objetivo:** que funcione bien en el día a día, sin sorpresas.

### Tareas
- [x] **Sueño y despertar:** `SystemEventsMonitor` escucha `didWakeNotification`.
  - [x] Al despertar: si la sesión caducó, se cierra (y se avisa, como en la fase 4); si no, el polling se reanuda de inmediato.
- [x] **Red:** `NWPathMonitor` reanuda el polling en cuanto vuelve la conexión, en lugar de esperar al siguiente reintento. `reconnectNow()` no descarta los mensajes pendientes.
- [x] **Indicadores en el menú:** el estado del bot (conectado / reconectando / error) y un aviso si falta el token o la cuenta y el bot está activado.
- [x] **Accesibilidad:** etiquetas de VoiceOver en el ícono ("Vigilia, activa, quedan 1 h 20 min").
- [x] **Ícono de la app:** taza con vapor sobre un cielo nocturno, generado con `scripts/generate-icon.swift`.
- [x] **Registro:** `Logger` (`os`) con el subsistema `com.tonis.vigilia` y categorías `session`, `telegram`, `screenshot`. **El token nunca se registra.**
- [x] **Instalación:** `scripts/install.sh` compila en Release, cierra cualquier copia abierta y copia `Vigilia.app` a `/Applications` (adelantado antes de la fase 5).
- [x] Revisar todos los textos (español, tono consistente).
- [x] Un `README.md` con la instalación, la configuración inicial, el uso, la seguridad y el desarrollo.

### Criterios de aceptación
- [ ] Prueba de un día real: sesiones largas, la Mac dormida y despertada, el Wi-Fi apagado y encendido. El bot siempre se recupera sin reiniciar la app.
- [x] En ninguno de los registros de Vigilia de las últimas 6 horas aparece nada con forma de token. Los registros informativos se ven en directo en Consola.app (subsistema `com.tonis.vigilia`).
- [x] `scripts/install.sh` deja la app instalada y funcionando desde `/Applications`.

---

## Resumen

| Fase | Entrega | Depende de |
|---|---|---|
| 0 | Proyecto base en la barra de menú | — |
| 1 | Mantener despierta (usable) | 0 |
| 2 | Configuración, Keychain e inicio con la Mac | 1 |
| 3 | Bot: comandos, botones y vinculación | 2 |
| 4 | Avisos automáticos | 3 |
| 5 | Capturas remotas | 3 |
| 6 | Robustez, pulido e instalación | 4, 5 |
