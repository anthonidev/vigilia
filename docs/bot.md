# Bot de Telegram: contrato común

Cómo se comporta el bot de Vigilia, en cualquier plataforma. Cada versión (macOS, Windows…) lo implementa a su manera, pero **desde el celular deben ser indistinguibles**: mismos comandos, botones, avisos, textos y reglas de seguridad.

- La referencia es la versión de macOS (`macos/Vigilia/Telegram/`). Si algo cambia allí, se actualiza este documento.
- En los textos, `{equipo}` es "Mac" o "PC" según la plataforma.

---

## 1. Ciclo de vida

- **Cuándo está encendido:**
  - durante una sesión activa, si en Ajustes está activado el bot, hay token y hay cuenta vinculada;
  - mientras se vincula una cuenta (aunque no haya sesión).

  Cuando deja de cumplirse, se apaga.
- **Recepción:** long polling con `getUpdates` (`timeout` 50 s, `allowed_updates: ["message", "callback_query"]`). No se abren puertos.
- **Al encender:**
  1. Descarta los mensajes pendientes con `getUpdates(offset: -1, timeout: 0)` y continúa desde el último + 1. Así un `/off` enviado mientras estaba apagado no afecta a una sesión nueva.
  2. Registra los comandos con `setMyCommands` (sección 3).
- **Al reconectar** (al despertar el equipo o al volver la red): corta la petición en curso y vuelve a pedir enseguida **sin** descartar los mensajes pendientes, salvo que el paso 1 aún no se hubiera completado.
- **Errores:**
  - Red: reintentos con espera creciente de 1, 2, 4… hasta 60 s.
  - `401`/`404`: token inválido. El bot se para y lo indica en la interfaz.
  - `409`: otro programa usa el bot. Se reintenta 3 veces cada 2 s y después se para con un aviso.
- **Apagado:** si se pide apagar mientras responde a un mensaje, primero termina de responder.
- **Un bot por equipo:** un bot no puede leer mensajes en dos equipos a la vez. Cada equipo tiene el suyo (por ejemplo, "Vigilia Mac" y "Vigilia PC").

## 2. Seguridad

- **Token:** se guarda en el almacén seguro del sistema (Llavero en macOS; en Windows, el Administrador de credenciales o DPAPI). Nunca aparece en registros ni en mensajes de error; ojo, la URL de la API lo contiene.
- **Autorización:** solo se procesan mensajes y botones cuyo `from.id` sea el de la cuenta vinculada **y** cuyo chat sea `private`. Todo lo demás se ignora en silencio, sin responder.
- **Vinculación:**
  - Código de 6 dígitos, válido 5 minutos, con un máximo de 5 intentos fallidos.
  - Durante la vinculación, cualquier cuenta puede enviar `/vincular <código>` o `/start <código>`, pero solo eso.
  - El enlace `https://t.me/<bot>?start=<código>` envía `/start <código>` con un toque.
  - Con el código correcto, se guarda `from.id` (y el `@username` o el nombre, solo para mostrarlo).
- **Botones:** solo se aceptan los valores de `callback_data` de la sección 5. Cualquier otro se ignora.
- **Desactivar desde la app:** solo con el bot desactivado en Ajustes, o desvinculando la cuenta.

## 3. Comandos

| Comando | Acción | Respuesta |
|---|---|---|
| `/estado` | — | `☕ Vigilia activa. Quedan 1 h 23 min.` o `☕ Vigilia activa de forma indefinida.` + botones de control |
| `/mas <duración>` | Suma tiempo | `➕ Sumados 30 min. Quedan 1 h 53 min.` + botones de control. Si es indefinida: `La sesión ya es indefinida.` |
| `/set <duración>` | Reemplaza el tiempo restante | `⏱️ Listo. Quedan 2 h.` + botones de control |
| `/indefinido` | Pasa a indefinida | `♾️ Sesión indefinida. La {equipo} seguirá despierta hasta que desactives la sesión.` + botones de control |
| `/off` | Desactiva, **después** de responder | `😴 Sesión desactivada. Tu {equipo} ya puede dormir y el bot se apaga hasta la próxima sesión.` |
| `/captura` | Captura normal (sección 6) | La foto, o la pregunta de qué pantalla |
| `/captura hd` | Captura HD (sección 6) | El archivo, o la pregunta de qué pantalla |
| `/ayuda` | — | La lista de comandos |

**Reglas de análisis:**
- Se ignoran las mayúsculas, las tildes (`/más` = `/mas`) y el sufijo `@NombreDelBot`.
- `/help` equivale a `/ayuda`. `/start` sin argumento también muestra la ayuda: es lo primero que envía Telegram al abrir el bot.
- Un texto que no empieza por `/` se ignora.

**Respuestas de error:**
- Comando desconocido: `No conozco ese comando. Escribe /ayuda para ver la lista.`
- Falta la duración o no se entiende:
  - `/mas`: `Uso: /mas 30m, /mas 1h o /mas 1h30m`
  - `/set`: `Uso: /set 2h, /set 45m`
- Sin sesión activa (`/estado`, `/mas`, `/set`, `/indefinido`, `/off`, `/captura`): `Vigilia está inactiva. Actívala desde el menú de la {equipo}.`
- `/vincular` con la cuenta ya vinculada: `Tu cuenta ya está vinculada.`

**`setMyCommands`:**

| Comando | Descripción |
|---|---|
| `estado` | Si está activa y cuánto tiempo queda |
| `mas` | Suma tiempo: /mas 30m, /mas 1h |
| `set` | Reemplaza el tiempo restante: /set 2h |
| `indefinido` | Pasa la sesión a tiempo indefinido |
| `off` | Desactiva la sesión |
| `captura` | Captura de pantalla (/captura hd en resolución completa) |
| `ayuda` | Lista los comandos |

## 4. Duraciones

| Texto | Minutos |
|---|---|
| `30m`, `30min` | 30 |
| `90` (número suelto = minutos) | 90 |
| `2h` | 120 |
| `1h30m`, `1h30` | 90 |
| `1.5h`, `1,5h` | 90 |

- Se ignoran los espacios y las mayúsculas (`2 H` = `2h`).
- Rango válido: de 1 a 1440 minutos (24 h). Fuera del rango, o con otro formato, es un error de uso.
- **Formato de salida:** `10 min`, `1 h`, `1 h 30 min`. El tiempo restante se redondea **hacia arriba** al minuto, así nunca se muestra "0 min" mientras quedan segundos.

## 5. Botones

| Teclado | Botones (`callback_data`) |
|---|---|
| **Control** | `+30 min` (`ext:30`) · `+1 h` (`ext:60`) · `+2 h` (`ext:120`) / `Apagar` (`off`) · `Captura` (`shot`) |
| **Aviso de 10 min** | `+30 min` (`ext:30`) · `+1 h` (`ext:60`) · `+2 h` (`ext:120`) / `Dejar terminar` (`dismiss`) |
| **Elegir pantalla** | Un botón por pantalla con su nombre (`shot:<id>:<n\|hd>`) y `Todas` (`shot:all:<n\|hd>`) |

**Valores aceptados de `callback_data`:**
- `ext:<1–1440>`: como `/mas`.
- `off`: como `/off`.
- `dismiss`: responde `👍 Vale, la sesión terminará a su hora.`
- `shot`: como `/captura`.
- `shot:<id de pantalla>:n`, `shot:<id>:hd`, `shot:all:n`, `shot:all:hd`.

Ninguno puede pasar de 64 bytes (límite de Telegram).

**Al pulsar un botón:**
1. `answerCallbackQuery` enseguida, para quitar el reloj de carga.
2. `editMessageReplyMarkup` sin teclado, para quitar los botones de ese mensaje y que no se pulsen dos veces.
3. Se ejecuta la acción. La respuesta trae botones nuevos.

## 6. Capturas de pantalla

- **Una pantalla:** se envía directamente.
- **Varias:** se pregunta `¿Qué pantalla?` (o `¿Qué pantalla? (HD)`) con el teclado de elegir pantalla. La pantalla principal va primero.
- **Normal:** JPEG con calidad 0,75 y el lado mayor limitado a 2560 px, enviado con `sendPhoto`.
- **HD:** PNG a resolución nativa, enviado con `sendDocument` y el nombre `vigilia-AAAA-MM-DD-HHMM.png`. Con varias pantallas, se añade `-1`, `-2`…
- **Todas:** un álbum con `sendMediaGroup`, con un máximo de 10 elementos, todos del mismo tipo.
- **Pie de foto:** `<nombre de la pantalla> · <hora local corta>`, por ejemplo `Pantalla integrada · 14:32`.
- **Mientras se prepara:** `sendChatAction` con `upload_photo` o `upload_document`.
- **Mensajes de error:**
  - Sin permiso: un mensaje que explica dónde darlo en el sistema; en el equipo se muestra la solicitud.
  - Pantalla desconectada: `Esa pantalla ya no está conectada. Vuelve a pedir la /captura.`
  - Otro fallo: `No se pudo hacer la captura. Inténtalo de nuevo.`

## 7. Avisos automáticos

Se envían si el bot está activado, hay cuenta vinculada, hay token y **Avisos automáticos** está activado. No necesitan que el polling esté encendido.

| Momento | Texto | Botones |
|---|---|---|
| Al activar | `☕ Vigilia activa por 2 h.` / `☕ Vigilia activa de forma indefinida.` | Control |
| Quedan 10 min | `⏳ Quedan 10 min. ¿Ampliar?` | Aviso de 10 min |
| Fin del tiempo | `😴 Sesión terminada. Tu {equipo} ya puede dormir.` | — |
| Desactivada en el equipo (o al cerrar la app) | `😴 Sesión desactivada desde la {equipo}. Tu {equipo} ya puede dormir.` | — |
| `/off` desde Telegram | Ningún aviso (el bot ya respondió) | — |

**Reglas:**
- **Aviso de 10 min:** una sola vez por sesión, y solo si quedaban más de 10 min. Si se amplía por encima de 10 min, se rearma.
- **Fin con el equipo dormido:** si al despertar han pasado más de 2 min desde el fin, se añade `(Terminó a las HH:MM, mientras la {equipo} dormía.)`. No se envía el aviso de 10 min atrasado.
- **Fallos de red:** se reintenta a los 5 s y a los 15 s.
- **Al cerrar la app:** se espera hasta 5 s a que salga el aviso de fin.
