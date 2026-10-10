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
- [ ] Firma: *Automatically manage signing* ya está configurado. **Falta elegir el Team (Personal Team)** en Xcode → target Vigilia → Signing & Capabilities, después de añadir tu Apple ID en Xcode → Ajustes → Cuentas. Mientras tanto se firma localmente (ad-hoc).
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
- Nota: `MenuBarExtra` no permite poner un tooltip al ícono, así que el tiempo restante se ve en la cabecera del menú y en la etiqueta de accesibilidad del ícono.
- [x] Al salir con una sesión activa, se libera la aserción.

### Tests (`VigiliaTests/SessionManagerTests.swift`)
- Activar 30 m → activa, con fin = ahora + 30 m.
- Activar con una sesión activa → se reemplaza el tiempo.
- `extend` suma bien y no tiene efecto si la sesión es indefinida.
- `set` reemplaza el tiempo.
- Al pasar la hora de fin (reloj falso) → inactiva, y se emite el evento `.ended`.
- `deactivate` libera la aserción (con un `PowerAssertion` falso detrás de un protocolo).

### Criterios de aceptación
- [x] Test de integración `PowerAssertionTests`: con la aserción real, el sistema registra la de Vigilia y la quita al liberarla.
- [ ] Con una sesión activa, `pmset -g assertions` muestra la aserción de Vigilia `PreventUserIdleDisplaySleep`.
- [ ] Al desactivar o al acabarse el tiempo, la aserción desaparece.
- [ ] Con una sesión de 10 min, la pantalla no se apaga aunque el apagado de pantalla esté configurado en 2 min.
- [x] Todos los tests pasan (22).

### Pruebas manuales
1. Activar 10 min y comprobar la aserción con `pmset -g assertions | grep -i vigilia`.
2. Esperar a que termine y confirmar que la aserción se fue.
3. Activar 1 h y luego elegir 30 min: el tiempo restante pasa a ~30 min.

---

## Fase 2: Configuración

**Objetivo:** una ventana de ajustes funcional, con el token guardado de forma segura.

### Tareas
- [ ] `KeychainStore`: `save(token:)`, `loadToken()`, `deleteToken()` (`kSecClassGenericPassword`, servicio `com.tonis.vigilia`, cuenta `telegram-bot-token`).
- [ ] `AppSettings` (`@Observable`, sobre `UserDefaults`):
  - `botEnabled: Bool` (por defecto `false`)
  - `notificationsEnabled: Bool` (por defecto `true`)
  - `authorizedUserID: Int64?`
  - `authorizedUserName: String?` (solo para mostrarlo)
- [ ] `LoginItem`: un envoltorio de `SMAppService.mainApp` con `isEnabled` y `setEnabled(_:)`. El estado se lee del sistema, no se guarda en `UserDefaults`.
- [ ] `SettingsView` (escena `Settings`, un `Form` agrupado):
  - **Telegram**
    - Token en un `SecureField`, con los botones **Guardar** y **Probar** (este último se habilita en la fase 3).
    - Cuenta autorizada: "No vinculada" o "@usuario (id)", con **Vincular…** y **Desvincular** (el flujo llega en la fase 3).
    - Interruptor **Activar bot**.
    - Interruptor **Avisos automáticos**.
  - **General**
    - Interruptor **Iniciar Vigilia al encender la Mac**.
- [ ] Abrir Ajustes desde el menú con `SettingsLink` o `openSettings`, y además `NSApp.activate()`. Una app sin Dock no trae la ventana al frente por sí sola.

### Tests
- `KeychainStore`: guardar, leer y borrar en un servicio de pruebas.
- `AppSettings`: valores por defecto y persistencia (con un `UserDefaults(suiteName:)` aislado).

### Criterios de aceptación
- El token aparece en **Acceso a Llaveros** bajo `com.tonis.vigilia` y no está en `UserDefaults`.
- Los interruptores se mantienen tras reiniciar la app.
- **Iniciar con la Mac** aparece en Ajustes del Sistema → General → Ítems de inicio, y funciona al reiniciar sesión.
- La ventana de ajustes se abre al frente desde el menú.

---

## Fase 3: Bot de Telegram (núcleo)

**Objetivo:** controlar la sesión desde Telegram, de forma segura.

### Tareas

**Modelos y cliente (`Telegram/TelegramModels.swift`, `TelegramAPI.swift`)**
- [ ] Modelos `Codable` con `convertFromSnakeCase`: `Update`, `Message`, `User`, `Chat`, `CallbackQuery`, `InlineKeyboardMarkup`, `InlineKeyboardButton`, y un `Response<T>` con `ok`, `result` y `description`.
- [ ] `TelegramAPI`: un `actor` que recibe el token, con `URLSession` y `async/await`:
  - `getMe()`
  - `getUpdates(offset:timeout:)`, con un timeout de petición > 50 s
  - `sendMessage(chatID:text:keyboard:)`
  - `editMessageReplyMarkup(...)`, para quitar los botones de avisos antiguos
  - `answerCallbackQuery(id:text:)`
  - `setMyCommands(_:)`
  - Errores tipados: `.invalidToken` (401), `.conflict` (409, otro proceso usa el bot), `.network`, `.api(description)`.

**Lógica pura (testeable)**
- [ ] `DurationParser`: `"30m"`, `"2h"`, `"1h30m"`, `"90"` (minutos), `"1.5h"` → minutos. Rechaza 0, negativos y más de 24 h.
- [ ] `BotCommand`: un `enum` que se obtiene del texto (`/estado`, `/mas <d>`, `/set <d>`, `/indefinido`, `/off`, `/captura [hd]`, `/ayuda`, `/vincular <código>`). Acepta `/comando@NombreBot` y mayúsculas.
- [ ] `CommandRouter`: recibe un `BotCommand` y devuelve una respuesta (texto + teclado), actuando sobre un protocolo `SessionControlling` que implementa `SessionManager`.
- [ ] Textos de respuesta en español, centralizados en un archivo (`BotStrings`).

**Bot (`TelegramBot.swift`)**
- [ ] `start()` y `stop()`. El bucle es un `Task` que se cancela al parar.
- [ ] Al arrancar:
  1. Descartar los mensajes pendientes con `getUpdates(offset: -1)` y guardar el siguiente `offset`.
  2. Registrar los comandos con `setMyCommands`.
- [ ] Bucle: `getUpdates` → por cada update, **autorizar** → enrutar → responder.
- [ ] **Autorización:** solo se procesan updates de chats `private` cuyo `from.id == authorizedUserID`. El resto se ignora sin responder.
- [ ] Errores: si falla la red, se reintenta con espera creciente (1, 2, 4… hasta 60 s). Con 401, el bot se para y se marca el error en el menú. Con 409, también se para y se muestra un aviso.
- [ ] Botones en línea `[+30 min] [+1 h] [+2 h]` / `[Apagar] [Captura]`, con `callback_data` del tipo `ext:30`, `off`, `shot`.

**Vinculación (`AccountLinker.swift`)**
- [ ] **Vincular…** en Ajustes:
  1. Genera un código aleatorio de 6 dígitos, válido 5 minutos.
  2. Arranca el bot en modo vinculación (aunque no haya sesión).
  3. Muestra: "Envía `/vincular 482913` a @TuBot".
- [ ] En modo vinculación, el **único** comando aceptado de usuarios desconocidos es `/vincular <código>`.
- [ ] Si el código es correcto, guarda `from.id` y `@username`, responde "Cuenta vinculada" y sale del modo vinculación. Después, el bot se para si no hay sesión activa.
- [ ] Tras 5 intentos fallidos o al caducar el código, se cancela la vinculación.

**Integración**
- [ ] `SessionManager` arranca el bot al empezar una sesión y lo para al terminarla, si `botEnabled`, hay token y hay cuenta vinculada.
- [ ] El menú muestra el estado del bot: "Bot conectado", "Bot: token inválido", etc.
- [ ] El botón **Probar** de Ajustes llama a `getMe` y muestra "@NombreBot ✓" o el error.

### Tests
- `DurationParser`: todos los formatos válidos e inválidos.
- `BotCommand`: análisis de texto, incluido `@NombreBot` y argumentos que faltan.
- `CommandRouter` con un `SessionControlling` falso: cada comando produce la acción y la respuesta correctas, incluido `/mas` con sesión indefinida.
- Autorización: un update de otro `from.id` no produce ninguna respuesta; uno de un grupo con tu ID tampoco.
- `AccountLinker`: código correcto, incorrecto, caducado y demasiados intentos.

### Criterios de aceptación
- Vincular la cuenta desde Ajustes funciona de principio a fin.
- Con una sesión activa, todos los comandos de `IDEA.md` funcionan (excepto `/captura`).
- Los botones `+30 min` y `Apagar` funcionan, y el botón deja de mostrar el reloj de carga.
- Un mensaje desde otra cuenta no recibe respuesta.
- Al desactivar la sesión, el bot deja de responder.
- Un `/off` enviado con el bot apagado **no** afecta a la siguiente sesión.

---

## Fase 4: Avisos automáticos

**Objetivo:** el bot te informa sin que preguntes.

### Tareas
- [ ] `SessionNotifier` escucha el `AsyncStream<SessionEvent>`:
  - `.started` → "☕ Vigilia activa por 2 h", con botones de control (o "…de forma indefinida").
  - `.tenMinutesLeft` → "⏳ Quedan 10 min. ¿Ampliar?", con `[+30 min] [+1 h] [+2 h] [Dejar terminar]`.
  - `.ended` → "😴 Sesión terminada. Tu Mac ya puede dormir."
- [ ] `SessionManager` emite `.tenMinutesLeft` una sola vez por sesión, y solo si quedaban más de 10 min. Si se amplía por encima de 10 min, el aviso se rearma.
- [ ] Orden al terminar: **enviar el aviso → esperar a que se envíe (máx. 5 s) → parar el bot**.
- [ ] Al pulsar un botón de un aviso, se quitan los botones de ese mensaje con `editMessageReplyMarkup`, para no pulsarlos dos veces.
- [ ] Se respeta `notificationsEnabled`.
- [ ] Si la sesión termina mientras la Mac duerme, se envía el aviso de fin al despertar (con una nota de que terminó a las HH:MM).

### Tests
- Activar 30 m y avanzar el reloj 20 m → `.tenMinutesLeft` se emite una vez.
- Activar 10 m → no se emite.
- Ampliar después del aviso → se rearma.
- Con los avisos desactivados → no se envía nada.

### Criterios de aceptación
- Los tres avisos llegan con sesiones reales cortas (por ejemplo, de 12 minutos con `/set 12m`).
- El aviso de fin siempre llega antes de que el bot se apague.

---

## Fase 5: Capturas remotas

**Objetivo:** ver tu pantalla desde el celular.

### Tareas
- [ ] `ScreenshotService` (`actor` o `@concurrent` para trabajar fuera del hilo principal):
  - `hasPermission()`: `CGPreflightScreenCaptureAccess()`
  - `requestPermission()`: `CGRequestScreenCaptureAccess()`
  - `displays() -> [DisplayInfo]`: `SCShareableContent.current.displays`, con el nombre tomado de `NSScreen.localizedName` (emparejando por `CGDirectDisplayID`).
  - `capture(display:) -> CGImage`: `SCScreenshotManager.captureImage` con un `SCContentFilter(display:excludingWindows: [])` y la resolución nativa (escala Retina).
  - `encodeNormal(_:) -> Data`: escala el lado mayor a 2560 px y lo guarda como JPEG con calidad 0.75 (ImageIO). Debe ocupar menos de 10 MB y cumplir ancho + alto ≤ 10 000.
  - `encodeHD(_:) -> Data`: PNG a resolución completa.
- [ ] `TelegramAPI`:
  - `sendPhoto(chatID:data:caption:)` (multipart)
  - `sendDocument(chatID:data:filename:caption:)` (multipart)
  - `sendMediaGroup(chatID:items:)` (multipart con `attach://`)
  - `sendChatAction(.uploadPhoto)`, para mostrar "enviando foto…"
- [ ] Flujo `/captura` o el botón **Captura**:
  - Una pantalla → la captura y la envía.
  - Varias pantallas → botones `[DELL U2723QE] [Pantalla integrada] [Todas]` con `callback_data` `shot:<id>:<n|hd>` / `shot:all:<n|hd>`.
  - **Todas** → un álbum con `sendMediaGroup` (máximo 10).
  - El pie de foto indica la pantalla y la hora: "Pantalla integrada · 14:32".
- [ ] `/captura hd` → el mismo flujo, pero enviado como documento PNG con el nombre `vigilia-2026-10-09-1432.png`.
- [ ] Sin permiso: el bot responde "Falta el permiso de Grabación de pantalla. Dalo en la Mac: Ajustes del Sistema → Privacidad → Grabación de pantalla." y la Mac muestra la solicitud del sistema.
- [ ] Ajustes: una fila **Grabación de pantalla: concedido / no concedido**, con un botón para abrir el panel del sistema.

### Tests
- `encodeNormal`: una imagen de 6016×3384 queda con el lado mayor ≤ 2560 y < 10 MB.
- El cuerpo multipart se construye correctamente (cabeceras, separadores y `attach://`).
- El análisis de `callback_data` de capturas.

### Criterios de aceptación
- `/captura` con una pantalla → llega una foto legible al celular en pocos segundos.
- `/captura hd` → llega un PNG con la resolución nativa.
- Con monitor externo → aparecen botones con los nombres reales, y **Todas** envía un álbum.
- Sin permiso → mensaje claro, sin errores ni cierres.
- Recompilar no hace perder el permiso (gracias a la firma estable).

---

## Fase 6: Robustez y pulido

**Objetivo:** que funcione bien en el día a día, sin sorpresas.

### Tareas
- [ ] **Sueño y despertar:** escuchar `NSWorkspace.willSleepNotification` y `didWakeNotification`.
  - Al despertar: si la sesión caducó, se cierra (y se avisa, como en la fase 4); si no, el polling se reanuda de inmediato.
- [ ] **Red:** usar `NWPathMonitor` para reanudar el polling en cuanto vuelva la conexión, en lugar de esperar al siguiente reintento.
- [ ] **Indicadores en el menú:** el estado del bot (conectado / reconectando / error) y un aviso si falta el token o la cuenta y el bot está activado.
- [ ] **Accesibilidad:** etiquetas de VoiceOver en el ícono ("Vigilia, activa, quedan 1 h 20 min").
- [ ] **Ícono de la app:** un ícono simple de taza para Ajustes y el Finder.
- [ ] **Registro:** `Logger` (`os`) con el subsistema `com.tonis.vigilia` y categorías `session`, `telegram`, `screenshot`. **El token nunca se registra.**
- [ ] **Instalación:** un script `scripts/install.sh` que compila en Release y copia `Vigilia.app` a `/Applications`.
- [ ] Revisar todos los textos (español, tono consistente).
- [ ] Un `README.md` con la configuración inicial (BotFather → token → vincular → permisos).

### Criterios de aceptación
- Prueba de un día real: sesiones largas, la Mac dormida y despertada, el Wi-Fi apagado y encendido. El bot siempre se recupera sin reiniciar la app.
- En Consola.app se ven los registros por categoría y en ninguno aparece el token.
- `scripts/install.sh` deja la app instalada y funcionando desde `/Applications`.

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
