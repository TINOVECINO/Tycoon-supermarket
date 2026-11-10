# Supermarket Empire

Empezás con un kiosco y lo convertís en una cadena de supermercados. Administrás el stock, los empleados, los precios y los clientes.

## Cómo se juega

- Cada jugador recibe un terreno con su local (hay 6 terrenos por servidor).
- Los **clientes** entran desde la calle, agarran de 1 a 3 productos de las góndolas, pagan en la **caja** y se van.
- La plata queda en la caja. **Tocá la caja** para cobrarla, o contratá un **Cajero** que cobra solo.
- Frente al local hay **botones de compra** con el nombre y el precio. Con ellos ampliás el local (Kiosco → Almacén → Minimercado → Supermercado → Hipermercado), sumás góndolas de productos nuevos y comprás mejoras: el cartel, la heladera, el aire, el estacionamiento y las escaleras mecánicas.
- **Stock:** cada venta saca una unidad. Una góndola vacía no vende. Reponés desde la ventana Stock (cada unidad cuesta su precio de costo) o con un **Repositor**.
- **Precios:** en la ventana Precios hay un control deslizante por producto, del 50% al 200%. Más barato atrae más clientes; más caro deja más por venta, pero muchos no compran. El punto justo queda un poco por encima del 100%.
- **Mejoras chicas:** 16 compras baratas, una detrás de otra en su propio botón (maceteros, faroles, toldo, carritos, banderines, expendedora...). Cada una se ve en el local y trae unos clientes más. El kiosco arranca pelado y se va completando.
- **Depósito y camiones:** desde el Almacén podés construir el Depósito al costado del local. En la ventana Depósito comprás hasta 3 camiones y tocás PEDIR: el camión entra por la calle, descarga cajas y se va. Las cajas cuestan 30% menos que reponer con plata, y al reponer se usan primero.
- **Empleados:** Cajero, Repositor, Promotor (trae más clientes) y Gerente (pide los camiones solo y suma plata por venta). Cada uno tiene 3 niveles.
- **Sucursal (rebirth):** con el Hipermercado y la plata suficiente abrís una sucursal nueva. Volvés al kiosco, pero cada sucursal suma +50% de plata para siempre.
- **Misiones:** son objetivos con premio en plata, que el servidor verifica antes de pagar.

## Estructura

```
SupermarketEmpire/
├─ default.project.json        estructura Rojo (qué carpeta va a qué servicio)
├─ SupermarketEmpire.rbxlx     el place listo para abrir en Studio (lo genera el build)
├─ tools/build_place.py        genera el .rbxlx sin instalar nada (solo Python)
└─ src/
   ├─ Main.server.luau         único Script del servidor: arranca todo en orden
   ├─ ClientMain.client.luau   único LocalScript: arma la UI
   ├─ server/                  → ServerScriptService.GameServer
   │  ├─ Kit.luau              paleta y piezas compartidas (bloques, carteles, árbol, farol, carrito)
   │  ├─ Scenery.luau          la calle: ruta, veredas, torre central, fondo, árboles del pack, luz
   │  ├─ World.luau            terrenos, dibujo del local, botones de compra, caja
   │  ├─ Store.luau            datos del local, compras, stock, empleados, sucursales, misiones, remotes
   │  ├─ Customers.luau        clientes que caminan, compran y pagan
   │  └─ Passes.luau           pases de juego (x2 Dinero, Clientes x2)
   ├─ client/Ui.luau           → StarterPlayerScripts.GameClient: todas las ventanas
   ├─ shared/                  → ReplicatedStorage.Game
   │  ├─ GameConfig.luau       TODOS los números del juego: precios, etapas, productos, empleados
   │  ├─ AssetIds.luau         ids de pases e íconos (0 o "" = sin configurar)
   │  └─ FolkStudUI.luau       tu kit Folk Stud UI, con las pantallas nuevas agregadas al final
   └─ lib/                     módulos de LihFolk (guardado con bloqueo de sesión, plata, remotes)
```

La UI usa tu kit **Folk Stud UI** (de `folk-stud-ui.skill`): la barra izquierda de cuadrados (Tienda, Misiones, Stock, Equipo, Precios, Sucursal) y las ventanas Tienda, Misiones, Precios y Sucursal salen del kit tal cual. Al final de `FolkStudUI.luau` agregué, con las mismas piezas y colores del kit:

- `M.manage`: filas con barra, texto amarillo y un botón. Las usan Stock y Empleados.
- `M.money`: la plata gigante en verde lima arriba, la línea del multiplicador y el objetivo con un color por palabra, como pide el style spec.
- `M.toast`: los avisos ("¡No te alcanza la plata!").

Las ventanas se arman al entrar al juego, así que en Edit no aparecen en StarterGui. Se ven al darle Jugar.

## Cómo probarlo

1. Abrí `SupermarketEmpire.rbxlx` con doble clic, o desde Studio con **Archivo (File) > Abrir desde archivo (Open from File)**.
2. Dale **Jugar (Play)**. Probado el 9/11/2026: arranca sin errores, los clientes compran y las ventanas responden. Sin publicar, el juego anda pero **no guarda**: en la **Salida (Output)** vas a ver `Studio offline: nothing will be saved`. Es lo esperado.
3. Para probar el guardado: publicá el place y activá **Archivo (File) > Configuración de la experiencia (Experience Settings) > Seguridad (Security) > Habilitar el acceso de Studio a los servicios de API (Enable Studio Access to API Services)**. Studio guarda en una base aparte (`_STUDIO`), así que no toca los datos reales.
4. En **Configuración del juego (Game Settings) > Lugares (Places)**, poné el máximo de jugadores en **6**, uno por terreno.

Si "Publicar como" se queda colgado en "Espera" (pasa con Team Create): abrí el place publicado desde Roblox, insertá el código como `.rbxmx` con **Importar modelo Roblox (Import Roblox Model)**, movelo a su lugar con la **barra de comandos (Command Bar)** y usá **Guardar en Roblox (Save to Roblox)**.

Para probar cosas caras sin esperar, poné `Config.StudioTestCash` (en `GameConfig.luau`) en, por ejemplo, 40000: te da esa plata al entrar, solo dentro de Studio. Dejalo en 0 para jugar normal.

### Después de cambiar código

```bash
python tools/build_place.py
```

Eso regenera el `.rbxlx`. Si usás Rojo, `rojo serve` con el mismo `default.project.json` también funciona.

## El mundo

El diseño sigue `docs/world-brief.md` (plantilla de la skill `lihfolk-worldbuilding`): paleta, medidas y qué cosas no hacer. Hay capturas en `docs/capturas/`. Los pinos y rocas son del LihFolk Asset Pack, ya subidos a la cuenta; sus ids están en `AssetIds.Models`.

## Lo que falta configurar

- **Pases:** crealos en Creator Hub (tu experiencia > Monetización > Pases) y pegá los ids en `src/shared/AssetIds.luau`. Mientras estén en 0, la Tienda avisa "Pase sin configurar" y no cobra nada. El precio en Robux se lee solo desde Roblox.
- **Íconos:** los 14 íconos de `assets/icons/` (del FOLK Icon Pack) ya están subidos a la cuenta `stewiertle` y sus ids están en `AssetIds.Icons`. Para cambiar uno, subí la imagen nueva y reemplazá su id. Las pestañas laterales de las ventanas y las misiones siguen con la estrella de muestra. Ojo: esas carpetas del pack no traen licencia; revisalo antes de publicar.
- **Regalos:** el botón de regalo de la Tienda solo muestra un aviso.
- **Ganancia offline:** no hay. Si la querés, el Vault recomienda un tope de 2 horas al 50%.

## Seguridad y datos

- El cliente solo manda ids: qué producto reponer, a qué empleado contratar o qué misión cobrar. Los precios y los saldos salen siempre del servidor (`GameConfig`).
- Cada remote tiene un límite de velocidad y valida sus argumentos (`lib/shared/Net.luau`).
- Los datos se guardan con `UpdateAsync` y bloqueo de sesión. Hay autoguardado escalonado y guardado al salir y al cerrar el servidor (`lib/server/PlayerData.luau`).

## Créditos

- Los módulos de `src/lib/` son de LihFolk Systems (CC BY 4.0). Ver `src/lib/LICENSE-LihFolk.md`.
- El kit de UI es Folk Stud UI, del paquete que pasaste.
