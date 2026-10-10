# Vigilia ☕

> Mantén tu Mac despierta el tiempo que necesites y contrólala desde tu celular.

Vigilia es una app para la barra de menú de macOS. Evita que la Mac se duerma durante el tiempo que elijas, y mientras está activa, te permite controlarla a distancia desde un bot de Telegram.

---

## 1. Ícono en la barra de menú

- La app vive solo en la barra superior. No tiene ventana ni ícono en el Dock.
- El ícono cambia según el estado:
  - **Inactiva:** la Mac se comporta normal y puede dormirse.
  - **Activa:** la Mac se mantiene despierta.
- Al pasar el cursor o abrir el menú se ve el **tiempo restante**.

## 2. Menú desplegable

Al hacer clic en el ícono aparecen las opciones de duración:

- Indefinido
- 10 minutos
- 30 minutos
- 1 hora
- 2 horas
- 4 horas
- 8 horas
- 12 horas

Además:

- **Desactivar**: vuelve al estado normal.
- **Tiempo restante** visible cuando hay una sesión activa.
- Acceso a la **configuración**.
- **Salir** de la app.

## 3. Mantener la Mac despierta

- Mientras está activa, la Mac **no se duerme** y **la pantalla no se apaga**. Así las capturas de pantalla siempre salen bien.
- Cuando el tiempo se acaba, la Mac vuelve a su comportamiento normal automáticamente.
- Si se elige un tiempo nuevo con una sesión activa, el tiempo se reemplaza.

## 4. Bot de Telegram (control remoto)

### Cuándo funciona

- El bot **solo está encendido mientras hay una sesión activa**.
- Al desactivar la sesión, o cuando se acaba el tiempo, el bot se apaga también. Así no consume recursos.
- No hace falta abrir puertos ni configurar el router.

### Seguridad

- El bot **solo obedece a mi cuenta de Telegram**. Cualquier otra persona que le escriba es ignorada.
- El token del bot se guarda de forma segura en la Mac.

### Comandos

| Comando | Qué hace |
|---|---|
| `/estado` | Indica si está activa y cuánto tiempo queda |
| `/mas 30m`, `/mas 1h`… | Suma tiempo a la sesión actual |
| `/set 2h` | Reemplaza el tiempo restante por uno nuevo |
| `/indefinido` | Pasa la sesión a tiempo indefinido |
| `/off` | Desactiva la sesión (y el bot se apaga) |
| `/captura` | Envía una captura de pantalla |
| `/captura hd` | Envía la captura en resolución completa, como archivo |
| `/ayuda` | Lista los comandos disponibles |

### Botones rápidos

En lugar de escribir comandos, el bot muestra botones en el chat:

- **+30 min**, **+1 h**, **+2 h**
- **Apagar**
- **Captura**

### Avisos automáticos

- **Al activar la sesión:** "Vigilia activa por 2 h", con botones de control.
- **Cuando quedan 10 minutos:** "Quedan 10 min. ¿Ampliar?", con botones para sumar tiempo o dejar que termine.
- **Al terminar la sesión:** "Sesión terminada. Tu Mac ya puede dormir."

## 5. Captura de pantalla remota

- Se pide desde el bot con `/captura`.
- **Con una sola pantalla**, la envía directamente.
- **Con varias pantallas**, el bot pregunta cuál, con un botón por cada monitor (con su nombre) y una opción **Todas**.
- Dos calidades:
  - **Normal:** foto comprimida, rápida de ver en el celular.
  - **HD:** archivo en resolución completa, para leer texto pequeño.

## 6. Configuración

Una ventana simple de ajustes con:

- **Token del bot** de Telegram.
- **Mi cuenta autorizada**, con un botón para vincularla de forma sencilla (por ejemplo, enviándole un código al bot).
- Activar o desactivar el bot. La app también debe poder usarse sin bot.
- Activar o desactivar los avisos automáticos.
- Iniciar Vigilia al encender la Mac.

## 7. Primer uso

1. Abrir la app; aparece el ícono en la barra de menú.
2. Pegar el token del bot (creado con @BotFather en Telegram).
3. Vincular mi cuenta de Telegram.
4. Dar el permiso de **Grabación de pantalla** cuando la app lo pida, solo si se van a usar capturas.

## 8. Limitaciones conocidas

- Si se **cierra la tapa** de la MacBook sin monitor externo y cargador conectados, la Mac se duerme igual y el bot deja de responder.
- Si la Mac está **bloqueada**, la captura muestra la pantalla de bloqueo.
- Los chats con bots de Telegram no tienen cifrado de extremo a extremo. No usar la captura con información sensible en pantalla.

---

## Ideas para el futuro

- Mantener la Mac despierta **con la tapa cerrada**.
- **Mantener despierta mientras una app esté abierta** (por ejemplo, mientras corre una descarga o un render).
- **Mantener despierta hasta que termine una descarga** o un proceso concreto.
- Aviso por Telegram si la **batería** baja de cierto nivel.
- Comando para **bloquear la pantalla** a distancia.
- Atajo de teclado global para activar o desactivar.
- Historial de sesiones.

## Versión para Windows (después)

- Primero se construye la versión para Mac completa; luego una versión para Windows con las mismas funciones.
- En Windows el ícono vive en la bandeja del sistema (junto al reloj).
- Cada equipo usa **su propio bot de Telegram** (por ejemplo "Vigilia Mac" y "Vigilia PC"), porque un mismo bot no puede funcionar en dos equipos al mismo tiempo.
