# Vigilia ☕

Mantén tu Mac despierta el tiempo que necesites y contrólala desde Telegram.

Vigilia vive en la barra de menú de macOS. Mientras hay una sesión activa, la Mac no se duerme ni apaga la pantalla, y un bot de Telegram te permite consultar el tiempo, ampliarlo, apagarla o pedir una captura de pantalla.

- La idea original está en [`IDEA.md`](IDEA.md).
- Las decisiones técnicas, en [`PLAN.md`](PLAN.md).
- El avance por fases, en [`FASES.md`](FASES.md).

## Requisitos

- macOS 27 y Xcode 27.
- Un Apple ID añadido en Xcode (Ajustes → Cuentas) para firmar con el *Personal Team*. No hace falta una cuenta de desarrollador de pago.

## Instalar

```sh
scripts/install.sh
```

El script compila en Release, cierra cualquier copia abierta de Vigilia, la instala en `/Applications` y la abre. Ejecútalo de nuevo para actualizar.

## Configuración inicial

1. **Crear el bot.** En Telegram, abre @BotFather y envía `/newbot`. Elige un nombre y un usuario que termine en `bot`.
   - Recomendado: `/setjoingroups` → **Disable**, para que nadie pueda añadirlo a un grupo.
2. **Guardar el token.** Menú de la taza → **Configuración…** → pega el token → **Guardar**. Se guarda en el Llavero y se comprueba con Telegram.
3. **Vincular tu cuenta.** Pulsa **Vincular…** → **Abrir en Telegram** → **Iniciar**. El código caduca en 5 minutos. Desde entonces el bot solo obedece a esa cuenta.
4. **Activar el bot.** Enciende **Activar bot**. Los **Avisos automáticos** vienen activados.
5. **Capturas (opcional).** En **Capturas de pantalla** → **Conceder…**, y activa Vigilia en *Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla y audio del sistema*.
6. **Iniciar con la Mac (opcional).** Enciende **Iniciar Vigilia al encender la Mac**.

Vigilia también se puede usar sin bot: deja **Activar bot** apagado.

## Uso

### Menú

Elige una duración: indefinido, 10 o 30 minutos, o 1, 2, 4, 8 o 12 horas. Elegir otra con una sesión activa reemplaza el tiempo.

- El ícono se rellena y se anima al activarse. En **Configuración… → Apariencia** puedes elegir el estilo:
  - **Taza** (por defecto): suelta vapor.
  - **Llama**: titila y suelta chispas.
  - **Foco**: se enciende con rayos de luz.
- Al pasar el cursor por la taza se ve el tiempo restante.
- **Desactivar** devuelve la Mac a su comportamiento normal.

### Bot de Telegram

El bot solo está encendido mientras hay una sesión activa.

| Comando | Qué hace |
|---|---|
| `/estado` | Si está activa y cuánto tiempo queda |
| `/mas 30m` | Suma tiempo (`30m`, `1h`, `1h30m`, `1.5h`, `90`) |
| `/set 2h` | Reemplaza el tiempo restante |
| `/indefinido` | Pasa la sesión a tiempo indefinido |
| `/off` | Desactiva la sesión y apaga el bot |
| `/captura` | Captura de pantalla comprimida |
| `/captura hd` | Captura PNG a resolución completa, como archivo |
| `/ayuda` | Lista de comandos |

**Botones:** `+30 min`, `+1 h`, `+2 h`, `Apagar` y `Captura`. Con varias pantallas, `/captura` pregunta cuál, con el nombre de cada monitor, o **Todas**.

**Avisos automáticos:**
- al activar la sesión;
- cuando quedan 10 minutos, con botones para ampliar;
- al terminar. Si la sesión terminó con la Mac dormida, el aviso llega al despertar e indica la hora.

## Seguridad

- **Token:** está en el Llavero y nunca aparece en los registros.
- **Quién puede usar el bot:** solo responde a la cuenta vinculada, en su chat privado. Cualquier otro mensaje se ignora en silencio.
- **Mensajes antiguos:** al encenderse, el bot descarta lo que se le envió mientras estaba apagado. Así un `/off` antiguo no afecta a una sesión nueva.
- **Cifrado:** los chats con bots de Telegram no tienen cifrado de extremo a extremo. No uses `/captura` con información sensible en pantalla.

## Limitaciones

- **Tapa cerrada:** si se cierra la tapa sin monitor externo y cargador, la Mac se duerme igual y el bot deja de responder. Al despertar, se reconecta solo.
- **Mac bloqueada:** la captura muestra la pantalla de bloqueo.
- **Permiso de captura:** macOS puede preguntar cada cierto tiempo si sigues permitiendo que Vigilia grabe la pantalla.
- **Un bot por equipo:** un mismo bot no puede funcionar en dos equipos a la vez.

## Desarrollo

```sh
# Compilar y ejecutar los tests
xcodebuild -project Vigilia.xcodeproj -scheme Vigilia -derivedDataPath build/DerivedData test

# Abrir la versión de desarrollo (cierra antes la de /Applications: dos copias se pelean por el bot)
open build/DerivedData/Build/Products/Debug/Vigilia.app

# Solo en Debug: iniciar una sesión o abrir los ajustes al arrancar
open build/DerivedData/Build/Products/Debug/Vigilia.app --args -activate 10
open build/DerivedData/Build/Products/Debug/Vigilia.app --args -openSettings YES

# Regenerar el ícono de la app
swift scripts/generate-icon.swift Vigilia/Assets.xcassets/AppIcon.appiconset
```

### Estructura

| Carpeta | Contenido |
|---|---|
| `Vigilia/App/` | Arranque (`AppDelegate`), menú de la barra (`StatusItemController`), estilos y animaciones del ícono (`MenuBarIconRenderer`), sueño y red |
| `Vigilia/Session/` | `SessionManager`, la única fuente de verdad de la sesión, y la aserción de energía de IOKit |
| `Vigilia/Telegram/` | Cliente de la Bot API, comandos, bot, vinculación y avisos |
| `Vigilia/Screenshot/` | Capturas con ScreenCaptureKit y codificación JPEG/PNG |
| `Vigilia/Settings/` | Ventana de ajustes, Llavero, ajustes e inicio con la Mac |
| `VigiliaTests/` | Tests con Swift Testing; Telegram y el capturador son falsos |

Para ver los registros, abre **Consola.app** y filtra por el subsistema `com.tonis.vigilia`. Las categorías son `session`, `telegram` y `screenshot`.
