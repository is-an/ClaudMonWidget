# ClaudMonWidget

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · **Español**

Un widget de Windows translúcido y siempre visible que muestra tu consumo de
Claude Code.

```
┌──────────────────────────────────┐
│  ● 54%                   2h 57m  │
│  ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░  │
│  6%                       6d 4h  │
│  ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└──────────────────────────────────┘
```

No hay nada que instalar. Funciona con el PowerShell 5.1 y el WPF que vienen con
Windows. Sin `npm install` y sin un inicio de sesión aparte: reutiliza las
credenciales que Claude Code ya guardó.

---

## Índice

- [Instalación](#instalación)
- [Ejecución](#ejecución)
- [Arranque automático](#arranque-automático)
  - [Con Windows](#con-windows)
  - [Con Claude Code](#con-claude-code)
- [Controles](#controles)
- [Skins](#skins)
- [De dónde salen los números](#de-dónde-salen-los-números)
- [Configuración](#configuración)
- [Resolución de problemas](#resolución-de-problemas)
- [Pruebas](#pruebas)
- [Compilación](#compilación)
- [Crear tu propio skin](#crear-tu-propio-skin)
- [Límites conocidos](#límites-conocidos)

---

## Instalación

Windows 10/11 con Claude Code instalado y con la sesión iniciada: ese es todo el
requisito.

```powershell
git clone https://github.com/is-an/ClaudMonWidget.git
cd ClaudMonWidget
```

También sirve descomprimir un ZIP en cualquier carpeta. La ubicación da igual,
pero el widget escribe `config.json` y `usage-cache.json` en su propia carpeta,
así que debe tener permiso de escritura. Evita `C:\Program Files`.

No hay instalador ni nada en el registro. Para quitarlo, borra la carpeta (si
configuraste el [arranque automático](#arranque-automático), deshazlo primero).

## Ejecución

Haz doble clic en **`ClaudMonWidget.exe`**. No aparece ninguna consola.

`start-hidden.vbs` hace lo mismo sin el ejecutable, si prefieres no correr un
binario que no compilaste. O desde una consola:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File widget.ps1 -Skin detail
```

`-ExecutionPolicy Bypass` solo afecta a ese arranque. No cambia la directiva del
sistema.

El exe es un lanzador de 46KB, no el widget reempaquetado: inicia `widget.ps1`
desde su propia carpeta sin consola, y nada más. El widget sigue siendo
PowerShell plano que puedes leer y editar. Para regenerarlo, mira
[Compilación](#compilación).

**Solo se ejecuta un widget a la vez.** Si lanzas otro mientras uno está
abierto, el segundo se cierra en silencio. Así se evita que se apilen widgets en
pantalla con uno viejo encima mostrando valores caducados.

## Arranque automático

### Con Windows

1. `Win+R` → `shell:startup` abre la carpeta de Inicio.
2. Pon ahí un **acceso directo** a `ClaudMonWidget.exe`.

Para deshacerlo, borra el acceso directo.

### Con Claude Code

Arranca el widget cuando empieza una sesión de Claude Code. Mejor si solo lo
quieres mientras trabajas con Claude.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1
```

Añade una entrada a `hooks.SessionStart` en `~/.claude/settings.json`. Tus otros
hooks y ajustes quedan intactos, y antes se escribe una copia de seguridad con
marca de tiempo junto al archivo. Ejecutarlo dos veces no duplica la entrada.

Para deshacerlo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-hook.ps1 -Uninstall
```

A mano, la entrada es así:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "wscript.exe \"C:\\ruta\\ClaudMonWidget\\start-hidden.vbs\""
          }
        ]
      }
    ]
  }
}
```

El hook se dispara en cada sesión, pero el widget es de instancia única, así que
todo arranque posterior al primero termina de inmediato.

**El widget sobrevive a Claude Code.** Ciérralo con `Exit` en su menú
contextual. Cerrarlo al terminar la sesión requeriría un hook de parada que mate
el proceso, y ese se dispararía incluso con otras sesiones de Claude abiertas,
así que no se incluye.

## Controles

| Acción | Resultado |
|---|---|
| Arrastrar | Mover. La posición se guarda en `config.json` al salir |
| Pasar el ratón | Tooltip: inicio de la ventana, tokens facturados, tokens de lectura de caché, origen del dato |
| Clic derecho | Menú |

Menú:

- **Skin** — `simple1` / `simple2` / `border1` / `border2` / `detail`. Uno a la vez.
- **Opacity** — 55 / 75 / 92 / 100%. Uno a la vez.
- **Always on top** — alternar siempre visible.
- **Auto sync** — alternar la consulta a Anthropic cada 5 minutos.
- **Sync now** — consultar a Anthropic ahora mismo.
- **Refresh now** — releer solo los archivos locales.
- **Exit** — salir.

## Skins

Cinco. Un `1` final significa solo la sesión de 5 horas; `2` añade la ventana de
7 días.

| Nombre | Ancho | Muestra |
|---|---|---|
| `simple1` | 150 | Solo el número de 5 horas, sin panel |
| `simple2` | 250 | Dos columnas sin panel: 5 horas y 7 días |
| `border1` | 270 | Píldora redondeada con la barra de 5 horas |
| `border2` | 270 | Píldora redondeada con las barras de 5 horas y 7 días |
| `detail` | 300 | Nombre de cuenta e insignia de plan, ambas barras, tokens y peticiones, origen del dato |

El predeterminado es `border2`. La altura sigue al contenido, así que nada se
corta en equipos con la fuente ampliada.

Ambas ventanas muestran el **tiempo restante** hasta el próximo reinicio. La
unidad sigue a la escala: `3h 04m` para la ventana de 5 horas, `6d 5h` para la
de 7 días. `149h 05m` no es un número que puedas retener.

```
simple1              simple2
  ● 54%              ● 54%  │  6%
   2h 57m              2h 57m │  6d 4h

border1                          border2
┌──────────────────────┐  ┌──────────────────────┐
│ ● 54%        2h 57m  │  │ ● 54%        2h 57m  │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │  │ ▓▓▓▓▓▓▓░░░░░░░░░░░░  │
└──────────────────────┘  │ 6%              6d 4h│
                          │ ▓░░░░░░░░░░░░░░░░░░  │
                          └──────────────────────┘
```

`detail`:

```
ANIN                        [Pro]
─────────────────────────────────
● Sesión de 5 horas       2h 57m
54%
▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░
6%                         6d 4h
▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
807.1k tok / 399 req / live 2m
```

Ambas filas siguen la misma regla: el porcentaje a la izquierda, el tiempo
restante a la derecha.

Escala de color: verde por debajo del 70%, ámbar a partir del 70%, rojo a partir
del 90%, gris cuando no hay valor.

---

## De dónde salen los números

Tres orígenes, del más fresco al menos.

### 1. Preguntar a Anthropic directamente (cada 5 minutos por defecto)

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <token de acceso>
anthropic-beta: oauth-2025-04-20
```

Es el mismo endpoint que llama Claude Code para dibujar `/usage`, así que el
porcentaje del widget es el porcentaje que muestra `/usage`.

El token es el que Claude Code ya tenía guardado:

```
%USERPROFILE%\.claude\.credentials.json  →  claudeAiOauth.accessToken
```

El widget nunca te pide iniciar sesión ni envía el token a ningún sitio que no
sea la cabecera de arriba. Si el token caducó, omite la llamada: renovarlo es
tarea del flujo OAuth de Claude Code, y el widget no lo imita.

La respuesta:

```json
{
  "five_hour": { "utilization": 36.0, "resets_at": "2026-09-09T09:04:59+00:00" },
  "seven_day": { "utilization": 4.0,  "resets_at": "2026-09-15T09:59:59+00:00" },
  "limits": [ ... ],
  "spend": { ... }
}
```

Se guarda tal cual en `usage-cache.json`, dentro de la carpeta del widget.

**Nunca se escribe en los archivos de Claude Code.** `~/.claude.json` lo
reescribe Claude Code entero, y escribir desde fuera podría corromper ese
estado. Si el widget falla o muere, nada del lado de Claude Code se ve afectado.

### 2. `%USERPROFILE%\.claude.json` → `cachedUsageUtilization`

Los mismos números, pero solo se refrescan cuando Claude Code los pide. Pueden
tener días. Se usa únicamente cuando el origen 1 no está disponible.

En la práctica, esta caché llevaba 44 horas sin actualizarse marcando 70% / 60%
mientras una llamada en vivo en ese mismo instante devolvía 28% / 3%. Por eso
existe el origen 1.

### 3. `%USERPROFILE%\.claude\projects\**\*.jsonl` → líneas assistant

```json
"usage": { "input_tokens": 2, "cache_creation_input_tokens": 25110,
           "cache_read_input_tokens": 29894, "output_tokens": 599 }
```

Tokens por petición con marca de tiempo, releídos cada 5 segundos sin tocar la
red. Siempre al día, pero es nuestro recuento, no el del servidor.

Solo se suman las líneas dentro de la ventana de sesión. Inicio de la ventana =
`five_hour.resets_at` − 5 horas.

Los tokens de lectura de caché superan 20 veces a los facturados, así que se
cuentan aparte. La cifra `tok` en pantalla son tokens facturados (entrada +
salida + escrituras de caché); las lecturas de caché solo aparecen en el
tooltip.

### Nombre de cuenta y plan

Se leen del bloque `oauthAccount` de `~/.claude.json`, sin llamada de red.

| Campo | Se usa para |
|---|---|
| `displayName` | Nombre de cuenta |
| `emailAddress` | Tooltip sobre el nombre |
| `organizationType` | Insignia de plan |

`organizationType` se traduce así: `claude_pro`→`Pro`, `claude_max`→`Max`,
`claude_max_5x`→`Max 5x`, `claude_max_20x`→`Max 20x`, `claude_team`→`Team`,
`claude_enterprise`→`Enterprise`.

No cambia mientras el widget corre, así que se lee una sola vez al crear la
ventana.

### Saber qué estás viendo

La última línea del skin `detail` indica el origen y su antigüedad.

| Muestra | Significado |
|---|---|
| `live now` | Recién obtenido de Anthropic |
| `live 12m` | Obtenido hace 12 minutos |
| `claude-code 2d` | La llamada en vivo falló; se usa la caché de Claude Code, de hace dos días |
| `token expired` | Token caducado. Ejecuta Claude Code una vez para renovarlo |
| `http 429` | Demasiadas llamadas. Se resuelve solo en el siguiente ciclo |
| `http 401` | Autenticación rechazada. Vuelve a iniciar sesión en Claude Code |
| `sync failed` | Error de red y similares |

Reiniciar el widget no vuelve a consultar si la caché es más reciente que
`syncSeconds` (300 por defecto). Así, los reinicios frecuentes —que el hook de
Claude Code hace muy fáciles— no golpean el endpoint hasta provocar un
`http 429`. `Sync now` ignora ese límite.

Si `resets_at` ya pasó, ese porcentaje pertenece a una ventana caducada y **no
se muestra**. En su lugar aparece nuestro propio recuento de tokens. No
presentar nunca un número viejo como si fuera actual es la regla sobre la que
está construido este widget.

No se muestra el coste en dólares. La línea `cost-state` que lo registra se
escribe cerca del final de una sesión, así que un archivo de sesión en curso no
la tiene.

---

## Configuración

`config.json` se crea la primera vez que el widget se cierra. El menú
contextual cambia casi todo, así que rara vez hace falta abrir el archivo.

| Clave | Valor por defecto | Significado |
|---|---|---|
| `skin` | `border2` | Skin inicial. Un nombre desconocido vuelve al predeterminado |
| `opacity` | `0.92` | Opacidad de la ventana |
| `left` / `top` | `-1` | Posición. `-1` la coloca abajo a la derecha |
| `pollSeconds` | `5` | Cada cuánto se releen los archivos locales |
| `syncSeconds` | `300` | Cada cuánto se consulta a Anthropic |
| `autoSync` | `true` | Sincronización automática. Desactivada, solo `Sync now` |
| `windowHours` | `5` | Duración de la ventana de sesión |
| `warnPct` / `dangerPct` | `70` / `90` | Umbrales de ámbar y rojo |

`usage-cache.json` es la última respuesta de sincronización. Borrarlo es seguro:
la siguiente sincronización lo vuelve a crear.

## Resolución de problemas

**El widget no aparece por ninguna parte**
`left` / `top` en `config.json` puede apuntar a un monitor que ya no tienes.
Borra ese archivo y vuelve a arrancar; regresa a la esquina inferior derecha.

**El tiempo restante no coincide con la app o la web de Claude**
Ambos leen el mismo `resets_at`, así que no deberían discrepar. Si lo hacen, lo
más probable es que el widget esté desactualizado: busca una versión más nueva.
Los segundos se descartan, así que hasta un minuto de diferencia es normal; más
que eso es un fallo.

**Los números están congelados**
Probablemente sea una instancia que lleva mucho abierta. `Exit` y arráncala de
nuevo. El tiempo restante se recalcula cada 5 segundos, así que debería perder
un minuto por minuto.

**La última línea se queda en `claude-code`**
La llamada en vivo sigue fallando. Pulsa `Sync now` para ver el motivo. Si dice
`token expired`, ejecuta Claude Code una vez para renovar el token.

**Aparece un recuento de tokens en vez de un `%`**
Todo lo disponible pertenece a una ventana de sesión caducada. Pulsa `Sync now`,
o ejecuta `/usage` una vez en Claude Code.

**Se bloquea la ejecución de scripts**
`ClaudMonWidget.exe`, `start-hidden.vbs` y los comandos de arriba aplican
`-ExecutionPolicy Bypass` solo a ese arranque. Si aun así se bloquea, es
probable que sea una directiva de la organización.

## Pruebas

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test-usage.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File test-menu.ps1
```

`test-usage.ps1` construye un árbol `.claude` falso en TEMP y fija el reloj de
referencia; luego comprueba la agregación, el análisis de la cuenta, la
prioridad de orígenes y el respaldo. No toca la red ni depende de lo que
contengan los registros reales, así que da el mismo resultado siempre.

`test-menu.ps1` comprueba que el menú contextual se comporte de verdad como
botones de radio. `MenuItem` de WPF no tiene modo radio, así que sin ayuda las
opciones de opacidad se seleccionan todas a la vez.

## Compilación

`icon.ico` y `ClaudMonWidget.exe` están en el repositorio, así que esto solo
hace falta al cambiar el icono o el lanzador:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
```

Dibuja el icono con `System.Drawing`, arma el `.ico` a mano y compila el
lanzador con el compilador de C# que viene con el .NET Framework en cualquier
Windows. No descarga nada.

## Crear tu propio skin

Añade un archivo, `skins\<nombre>.xaml`. `widget.ps1` no necesita cambios.

El host busca estos nombres con `FindName` y rellena **solo los que existan**,
así que incluye únicamente los que quieras.

| `x:Name` | Tipo | Se rellena con |
|---|---|---|
| `Dot` | Shape | Color de estado |
| `TxtMain` | TextBlock | Porcentaje de 5 horas, o el recuento de tokens si no hay |
| `TxtReset` | TextBlock | Tiempo hasta el reinicio de 5 horas (`3h 04m`), si no `--` |
| `TxtWeek` | TextBlock | Porcentaje de 7 días |
| `TxtWeekReset` | TextBlock | Tiempo hasta el reinicio de 7 días (`6d 5h`), si no `--` |
| `TxtSub` | TextBlock | `563.0k tok / 249 req / live now` |
| `TxtUser` | TextBlock | Nombre de cuenta, correo en el tooltip |
| `TxtPlan` | TextBlock | Insignia de plan |
| `BarTrack` / `BarFill` | Border | Barra de progreso de 5 horas |
| `WeekTrack` / `WeekFill` | Border | Barra de progreso de 7 días |
| `Root` | cualquier contenedor | Donde se engancha el menú contextual |

La `Window` necesita `WindowStyle="None"`, `AllowsTransparency="True"` y
`Background="Transparent"`. Usa `SizeToContent="Height"` para que nada se corte
cuando cambian los tamaños de fuente.

Para que un skin nuevo salga en el menú, añade el nombre al array `$Skins` cerca
del principio de `widget.ps1` y al `ValidateSet` del parámetro `-Skin`.

```powershell
$Skins = @('simple1','simple2','border1','border2','detail')
```

Si `config.json` nombra un skin que ya no existe, el widget vuelve al
predeterminado en lugar de negarse a arrancar.

## Límites conocidos

- El recuento de tokens es nuestro y no está garantizado que coincida con cómo
  factura o mide Anthropic. El `%` en pantalla es el número del servidor; `tok`
  es el nuestro.
- `/api/oauth/usage` no es una API documentada públicamente. El widget usa lo
  que usa Claude Code. Si cambia la forma de la respuesta, la sincronización
  registra `unrecognized response` y **deja intacta la última caché válida**: la
  pantalla no se queda en blanco.
- No hay click-through. Activarlo dejaría el menú contextual fuera de alcance y
  arrastraría consigo un atajo global.
- Si una actualización de Claude Code renombra campos del JSONL, el recuento
  puede irse a cero. El widget muestra `--` en vez de morirse.
- Solo Windows. Está atado a WPF.

## Minas pisadas en PowerShell 5.1

Anotadas para que el siguiente cambio no las vuelva a pisar. Todas fallan en
silencio con un valor incorrecto, no con un error.

- **No analices `~/.claude.json` con `ConvertFrom-Json`.** Contiene un mapa de
  proyectos indexado por ruta absoluta, y el analizador trata las claves sin
  distinguir mayúsculas, así que `c:\...` y `C:\...` chocan como duplicadas y
  todo el análisis lanza una excepción. Extrae con una expresión regular solo
  los pocos valores que necesitas.
- **Mantén los caracteres no ASCII fuera de los `.ps1`.** Un script sin BOM se
  lee como ANSI y los caracteres se corrompen. Las etiquetas localizadas viven
  en el XAML, que se lee explícitamente como UTF-8. Por lo mismo, nunca hagas
  ida y vuelta con `Get-Content | Set-Content` en estos archivos.
- **Un scriptblock con `GetNewClosure()` corre en un ámbito clonado.** No ve ni
  las variables `$script:` que su creador asignó después ni las funciones
  definidas dentro de la función que lo envuelve. Mete el estado compartido en
  una sola tabla hash y pásala por referencia, y coloca a nivel de script los
  ayudantes que llame un manejador. Pasar esto por alto hizo que un manejador de
  `SourceInitialized` lanzara una excepción a mitad, así que el temporizador de
  sondeo que venía después nunca arrancó. El widget seguía ahí, aparentemente
  bien, congelado en su primer fotograma: un widget muerto se nota, uno parado
  no. Ahora el temporizador de sondeo arranca **primero y sin condiciones**.
- **Una conversión `[int]` redondea, no trunca.** `[int]3.58` es `4`. Calcular
  el tiempo restante como `[int]$span.TotalHours` convirtió 3h34m en `4h 34m`.
  Los minutos seguían siendo correctos, así que parecía del todo plausible, y se
  leía como una hora de margen que no existía. Usa `[math]::Floor` al cortar
  horas. Un número que representa un presupuesto no debe errar por arriba.
- **`return $array` se despliega en la tubería.** Quien llama recibe un
  `object[]` de elementos encajonados en vez del `byte[]` que pidió. `.Length`
  sigue dando bien, así que el directorio del icono parecía correcto mientras
  `BinaryWriter.Write` elegía otra sobrecarga y emitía un byte por entrada: un
  `.ico` de 108 bytes con una cabecera perfecta y ninguna imagen. Devuelve
  `, $array`.
- **No uses `.Count` sobre el resultado de una tubería con `StrictMode 2.0`.**
  Un único resultado vuelve como escalar y `.Count` lanza una excepción. Si eso
  ocurre al evaluar un argumento, la comprobación entera se salta, así que la
  suite de pruebas finge pasar en silencio. Envuélvelo en `@(...)`.
