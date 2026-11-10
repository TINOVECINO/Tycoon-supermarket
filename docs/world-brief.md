# World brief: Calle Comercial

Plantilla de `lihfolk-worldbuilding`. Todo lo que se construye en `src/server/` se revisa contra esto.

```
WORLD BRIEF: Calle Comercial

Fantasy      sos el dueño del kiosco más chico de una calle comercial soleada, y lo ves crecer hasta hipermercado
Play pattern aparecés frente a tu local -> cobrás la caja -> pisás un botón de compra -> reponés; sesiones de 10-20 min; 1-6 jugadores
Target       mobile first; 6 jugadores; StreamingEnabled on
Scale        R15 default (5 studs); WalkSpeed 16
Style        flat stylised: piezas SmoothPlastic de un solo color, sin texturas realistas. Combina con la UI Folk Stud
Mood         bright cartoon, ClockTime 13.5
Palette      asfalto 58,58,68 | vereda 205,200,190 | piso del terreno 232,226,210 | pasto 104,170,80 | pared crema 245,240,228
Accents      lima 140,255,0 solo en lo que se toca o paga (botones de compra, caja, plata). El color de la etapa
             (naranja, azul, verde, rojo, violeta) solo en toldo, franja y cartel del local
Hero         por terreno: el tótem con el nombre del local, 26 studs (el local mide 13). Se ve desde el spawn y la calle.
             En el centro: la torre "SUPERMARKET EMPIRE" de 44 studs en la plaza, visible desde los 6 terrenos
Districts    plaza central (spawn general), calle, 6 terrenos (3 por lado), borde de árboles y edificios de fondo
Paths        calle 40 de ancho con sendas peatonales frente a cada terreno; vereda 8; camino de entrada 12 hasta la puerta
Not this     sin bloques grises lisos; sin props desparramados al azar; sin neón salvo cajas y carteles; sin texturas PBR;
             sin colores saturados en el piso
Story        carritos mal estacionados junto a la entrada; cajas de reparto apiladas al costado del local;
             el cartel "EN ALQUILER" en los terrenos libres
Budget       <= 6k instancias con los 6 locales en Hipermercado; <= 12 luces, 0 con sombra; decoración sin colisión
Assets       LihFolk Asset Pack: PineTree_01/03, Boulder_01/07, Rock_03/09 (ya subidos). El local, la calle y los props
             se arman con piezas en código, porque el local cambia de tamaño con cada etapa
```

## Medidas usadas (de `budgets.md`)

- Planta alta: 12 studs de piso a alero. Puerta: 8 de ancho x 8 de alto (más ancha que la regla de 4, porque pasan clientes en fila).
- Ventanas: antepecho a 3, alto 5.
- El tótem mide 2x el local, para cumplir "hero >= 1,5x".
- Aparición a 28 studs de la puerta, mirando al local.
