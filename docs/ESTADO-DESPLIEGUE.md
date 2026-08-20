# Estado de despliegue de GRI — qué existe de verdad

> **Fuente de verdad del estado del sistema.** Última verificación: **2026-08-20**,
> proyecto Firebase `p-gri-b5b40`.
>
> Esto es un **inventario, no una disculpa**. Si en seis meses alguien —incluido el
> propietario— tiene que decidir algo sobre este sistema, este documento le dice en dos
> minutos qué está desplegado, qué no, por qué, y qué haría falta para cambiarlo.
>
> **Por qué existe.** La Fase 11 arrancó porque `CLAUDE.md` describía un backend FastAPI +
> MySQL que se había archivado en la Fase 10. Cualquier agente o persona que lo leyera
> planificaba contra un sistema inexistente. Cerrar la fase dejando documentación que
> describe unas Cloud Functions que nadie ha desplegado sería repetir exactamente ese error.

---

## 1. Desplegado y verificado

| Pieza | Estado | Evidencia |
|---|---|---|
| `firestore.rules` | **DESPLEGADO** el 2026-08-20 | Ruleset activo `25efd44a-8a0e-496a-9e96-2a92d8e3a28b`. Se **releyó del proyecto** y se comparó con el archivo del repo: idénticos. No es «se subió y suponemos que llegó» |
| `firestore.indexes.json` | **DESPLEGADO** — los **10** índices | Ya lo estaban antes de la fase, incluido `categorias(restauranteId, orden)`, que fue el tercer bug P0 de la Fase 10 |
| `app_cliente` | **Funciona** contra `p-gri-b5b40` | Auth, lectura de restaurantes y menú, escaneo de QR, sesión de mesa, pedidos, cuenta y calificación |
| `panel_admin` | **Funciona** contra `p-gri-b5b40` | Dashboard, mesas, menú, cocina, reservas, clientes, reportes, configuración |
| `/equipo` — **el listado** | **Funciona** | Es una lectura de Firestore. La habilitó el despliegue de reglas del 2026-08-20 (`match /usuarios/{uid}`, lectura acotada al `rid` del llamador, plan 11-10). Antes respondía `permission-denied` aunque el código fuera correcto |

**Consecuencia práctica:** todo el producto está operativo contra el proyecto real salvo lo
del punto 2.

---

## 2. NO desplegado, y por qué

Las **tres Cloud Functions callable** del repo:

| Función | Archivo | Qué hace |
|---|---|---|
| `bootstrapPlataforma` | `functions/src/bootstrap-plataforma.js` | Crea el PRIMER `super_admin` y queda inerte para siempre |
| `crearUsuarioStaff` | `functions/src/crear-usuario-staff.js` | Alta de personal con claims `{role, rid}` |
| `cambiarEstadoStaff` | `functions/src/cambiar-estado-staff.js` | Baja reversible y readmisión de personal |

**Por qué no están desplegadas.** Cloud Functions exige el plan **Blaze**, y el propietario
decidió el **2026-08-20 no activarlo** (`11-CONTEXT.md`, «Blaze — REVERTIDO»). Blaze pide una
tarjeta y el almacenamiento de los artefactos de despliegue genera cargos pequeños pero **no
nulos**.

**Esto no es un fallo, un olvido ni una tarea pendiente que se traspapeló.** Es una decisión
de producto, tomada por quien paga la factura, registrada y con su alternativa construida
(punto 4). Quien lea esto no tiene que «arreglarlo».

**Qué se rompe exactamente hoy:** dos botones de `/equipo` — «Nuevo usuario» y la
baja/readmisión de cada fila. Nada más. Los botones **siguen ahí y siguen pulsándose**: la
pantalla muestra un aviso permanente que explica la situación y remite al script, y si se
pulsan, el mensaje de error dice lo mismo. Antes decía *«El restaurante no existe»*, que era
falso y mandaba a investigar lo que no era (plan 11-26).

---

## 3. Qué se conserva — y por qué NO se borra

Nada de lo siguiente se elimina. Está **escrito, probado y listo** para el día que se decida
desplegar; lo único que le falta es el plan de facturación. Borrarlo sería tirar trabajo
verificado para tener que rehacerlo peor.

| Qué | Cuánto | Dónde |
|---|---|---|
| Las tres callables | 3 archivos | `functions/src/bootstrap-plataforma.js`, `crear-usuario-staff.js`, `cambiar-estado-staff.js` |
| Pruebas **unitarias** (matrices, política de contraseñas, contratos estáticos) | **149** | `functions/test/*.test.js` |
| Pruebas **e2e** contra emuladores, con tokens reales | **50** | `scripts/test/functions/*.e2e.mjs` |
| Pruebas de **rules** contra el emulador de Firestore | **221** | `scripts/test/rules/*.test.mjs` |

Las **matrices puras** —`functions/src/auth-matrix.js`, `baja-matrix.js` y
`password-policy.js`— no solo se conservan: el script de gestión de personal (punto 4) las
**importa**. Es decir, esas 149 pruebas siguen protegiendo la lógica que se ejecuta de verdad
hoy, no un código dormido.

Los emuladores **no necesitan Blaze**: `npm run test:functions` sigue ejercitando las tres
callables de punta a punta, y `docs/SMOKE-E2E-v2.md` sigue siendo un runbook válido **contra
emuladores**.

---

## 4. Cómo se hace HOY la gestión de personal

Con **`scripts/gestion_staff.mjs`**, que ejecuta el Admin SDK con la clave de servicio del
propietario, en su máquina, reutilizando las mismas matrices que usaban las callables.

```bash
node scripts/gestion_staff.mjs listar --como admin@demo.gri.dev
node scripts/gestion_staff.mjs crear  --como admin@demo.gri.dev \
     --email ana@demo.gri.dev --nombre "Ana Mesera" --rol mesero
# atajo equivalente:  cd scripts && npm run staff -- listar --como ...
```

Manual completo, con los cinco comandos, la matriz de autorización y sus límites:
**[`docs/GESTION-PERSONAL.md`](GESTION-PERSONAL.md)**.

**Limitación importante que ese manual explica en detalle:** en la Cloud Function la matriz
era una frontera de seguridad real (corría en un servidor, contra un llamador que no
controlaba nada). En el script es una **barrera contra errores**, no contra un atacante:
quien tiene la clave de servicio tiene el Admin SDK entero.

---

## 5. Qué haría falta para activar las funciones

Lista ejecutable, en orden. Nada de esto está hecho.

1. **Subir `p-gri-b5b40` al plan Blaze**, en la consola de Firebase, y **crear una alerta de
   presupuesto** en el mismo paso (Blaze no tiene tope por defecto).
2. **Comprobar que `functions/.env` existe y tiene `BOOTSTRAP_EMAIL` y `BOOTSTRAP_SECRET`.**
   Ese archivo está **gitignored** y sus valores **no se escriben en ningún documento
   versionado** — se referencia por su ubicación, nunca por su contenido. Las dos variables
   deben estar puestas **antes** del deploy: si faltan, la función responde
   `failed-precondition` (*fail closed*) y cambiarlas después exige volver a desplegar.
3. **Desplegar:**
   ```bash
   cd scripts
   npx firebase deploy --only functions --project p-gri-b5b40
   ```
   El **primer** despliegue puede pedir habilitar APIs de Google Cloud: **Cloud Build**,
   **Artifact Registry**, **Cloud Run** y **Eventarc**. Es normal; la CLI ofrece habilitarlas.
4. **Comprobar en el panel:** `/equipo` → «Nuevo usuario». Debe crear la cuenta en vez de
   mostrar el aviso.

### Qué dejaría de hacer falta — y qué sí habría que tocar

- **Los botones de `/equipo` empiezan a funcionar solos.** No hay que tocar código: la rama
  de «función no desplegada» se distingue por que el `not-found` llega **sin mensaje del
  servidor**, y una callable desplegada siempre manda el suyo. Se apaga sola.
- **El script queda como herramienta de administración de respaldo**, no se retira: sigue
  siendo la vía cuando el panel no está a mano o cuando hay que reparar algo.
- ⚠️ **Una cosa SÍ hay que tocar, y son dos líneas.** En
  `panel_admin/lib/features/equipo/equipo_controller.dart`, la función
  `_callableNoDesplegada()` agrupa hoy `unavailable` e `internal` con «no desplegada».
  Con las funciones desplegadas esos dos códigos pasan a significar «la función existe y se
  cayó», y hay que sacarlos de ese grupo para que vuelvan al mensaje genérico. Está anotado
  también en el propio archivo. `not-found` no requiere nada.

---

## 6. Limitación aceptada: esto no es autoservicio

Sin las callables, **la plataforma no se arranca ni se gestiona desde el producto**: hace
falta alguien con la clave de servicio en su máquina.

- **Es viable** mientras el propietario gestione sus propios restaurantes: da de alta a su
  equipo con el script y todo lo demás lo hacen ellos desde el panel.
- **Deja de serlo** el día que la plataforma se abra a terceros: un restaurante cliente no
  puede depender de que el propietario le cree las cuentas a mano, y desde luego no puede
  recibir la clave de servicio. Ese día hará falta Blaze y el punto 5.

Es una **decisión consciente y registrada**, con su alternativa construida y probada. No es
deuda oculta.

---

## 7. Deuda conocida que sigue abierta

| Deuda | Impacto | Estado |
|---|---|---|
| **App Check sin habilitar** | Las callables (cuando se desplieguen) no distinguen una app legítima de un `curl` con un idToken válido | Diferido |
| **Sin flujo de invitación por correo** | Quien crea una cuenta de staff teclea o dicta la contraseña de esa persona | Aceptado en v1 |
| **Huella SHA-1 de release** | Google Sign-In en Android falla con `DEVELOPER_ERROR` (código 10) si se firma un APK de producción sin registrar su SHA-1 | **Pendiente.** La de depuración ya está registrada; la verificación del ingreso con Google es el checkpoint del plan **11-17** |
| **Contraste de la marca** | Blanco sobre `#FF4C05` da 3.34:1 en etiquetas de 14px normal | Pendiente de decisión: arreglarlo exige oscurecer la paleta (bloqueada) o subir esas etiquetas a 16 bold |
| **Pagos en línea** | Solo se *solicita* la cuenta; no se cobra | Diferido desde la Fase 10 |
| **Reportes agregan en cliente** | No escalan a años de datos | Aceptado en v1 |

---

## Documentos relacionados

- **[`docs/GESTION-PERSONAL.md`](GESTION-PERSONAL.md)** — cómo se da de alta y de baja al personal hoy.
- **[`docs/SMOKE-E2E-v2.md`](SMOKE-E2E-v2.md)** — runbook del flujo completo **contra emuladores**,
  donde las callables SÍ funcionan. Su cabecera dice qué pasos no se pueden ejecutar contra el
  proyecto real.
- **[`docs/FIREBASE_SETUP.md`](FIREBASE_SETUP.md)** — operación de Firebase: emuladores, seed, claims, deploy.
