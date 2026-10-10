# Vigilia ☕

Mantén tu equipo despierto el tiempo que necesites y contrólalo desde Telegram.

Vigilia vive en la barra de menú (o en la bandeja del sistema). Mientras hay una sesión activa, el equipo no se duerme ni apaga la pantalla, y un bot de Telegram te permite consultar el tiempo, ampliarlo, apagarla o pedir una captura de pantalla.

## Plataformas

| Plataforma | Carpeta | Estado |
|---|---|---|
| macOS 27 | [`macos/`](macos/) | ✅ Completa: Swift, AppKit y SwiftUI |
| Windows | `windows/` | Pendiente |

Cada plataforma tiene su propio código, README y plan. No comparten código, pero sí el comportamiento.

## Documentación común

- **[`docs/IDEA.md`](docs/IDEA.md):** qué es Vigilia y qué debe hacer.
- **[`docs/bot.md`](docs/bot.md):** el contrato del bot de Telegram (comandos, botones, avisos, textos y seguridad). Toda versión debe cumplirlo, para que desde el celular no se note la diferencia.

Cada equipo usa **su propio bot** de Telegram (por ejemplo "Vigilia Mac" y "Vigilia PC"), porque un mismo bot no puede leer mensajes en dos equipos a la vez.
