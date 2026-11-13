# Justificaciones técnicas — Entrega 2 TurismoUQ

**Equipo:** Sebastián Torres Morales · Jorge William Montoya Toro · Diego Alejandro Carvajal Camargo  
**Curso:** Bases de Datos II · Universidad del Quindío · 2026-2

---

## 1. Tablespace `TBS_TURISMOUQ_HIST`

**Justificación de separar el histórico en su propio tablespace:**

1. **Separación de cargas de trabajo (I/O).** El tablespace `USERS` soporta el OLTP activo (inserciones de reservas, actualizaciones de estado). Mezclar ahí registros históricos que solo se leen en consultas analíticas genera contención de I/O: los full-scans de gerencia compiten con las escrituras de recepción. El tablespace dedicado elimina esa competencia.

2. **Política de backup diferenciada.** Los datos históricos no cambian una vez archivados. Pueden respaldarse semanalmente en lugar de diariamente, reduciendo la ventana de mantenimiento y el consumo de almacenamiento de backup.

3. **Crecimiento controlado en Oracle XE.** XE tiene un límite de 12 GB por contenedor. Con `AUTOEXTEND ON NEXT 20M MAXSIZE 1G`, el histórico no puede consumir todo el espacio disponible y afectar el segmento transaccional.

4. **Portabilidad.** Si el proyecto migrara a Enterprise Edition, mover el histórico a almacenamiento más económico (disco frío) se haría con un simple `ALTER TABLE RESERVA_HISTORICO MOVE TABLESPACE nuevo_ts` sin reescribir código.

---

## 2. Vista materializada `MV_OCUPACION_MENSUAL_MUNICIPIO`

**Objetivo:** precalcular métricas de ocupación mensual (noches, habitaciones, reservas, ingreso estimado) por municipio para el dashboard gerencial, evitando JOINs de 5 tablas en cada consulta interactiva.

**Política de refresco — `REFRESH COMPLETE ON DEMAND`:**

- Los datos de reserva se actualizan en lotes (cargas periódicas, cierres mensuales), no en tiempo real de microsegundos. No hay justificación de costo para un refresco `ON COMMIT`.
- `COMPLETE` es apropiado porque no se mantiene un MV LOG sobre `RESERVA_HABITACION`. Mantener ese log tendría overhead permanente en una tabla con 25.000+ filas activas.
- El refresco se dispara manualmente con `DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL_MUNICIPIO', 'C')` tras cada carga masiva. En producción se programaría como job nocturno con `DBMS_SCHEDULER`.

**Columna `ANIO_MES` (decisión de diseño):** se agregó como `DATE` (primer día del mes con `TRUNC(fecha, 'MM')`) para permitir ordenamiento cronológico directo y consultas de rango con `WHERE anio_mes BETWEEN :f1 AND :f2` aprovechando el índice.

---

## 3. Disparadores

### 3.1 `trg_tarifa_auditoria` — auditoría sobre TARIFA

**Por qué compound trigger en lugar de GTT:**

El diseño anterior (Entrega 1) usaba una `GLOBAL TEMPORARY TABLE ON COMMIT DELETE ROWS`. El problema es que **SQL Developer tiene autocommit activado por defecto**: el `COMMIT` implícito tras el DML sobre `TARIFA` borraba la GTT **antes** de que el disparador de sentencia pudiera leerla, dejando `AUDITORIA_TARIFA` vacía silenciosamente.

**Solución — Compound Trigger (Oracle 11g+):**

- La sección `AFTER EACH ROW` acumula los valores OLD/NEW en una colección PL/SQL **en memoria** (no en disco), que existe mientras dura la sentencia. No hay GTT, no hay problema de autocommit.
- La sección `AFTER STATEMENT` vuelca esa colección a `AUDITORIA_TARIFA` en una sola pasada y luego la limpia.
- Resultado: un registro de auditoría por fila modificada, registrando usuario, timestamp, tipo de operación, precio anterior y precio nuevo.

### 3.2 `trg_reshab_sin_solape` — anti-solapamiento en RESERVA_HABITACION

**Por qué compound trigger en lugar de trigger FOR EACH ROW clásico:**

Un trigger `BEFORE INSERT OR UPDATE FOR EACH ROW` sobre `RESERVA_HABITACION` que hace `SELECT` sobre la misma tabla provoca **ORA-04091 (mutating table)**. Oracle no permite leer una tabla mientras está siendo modificada por la sentencia que disparó el trigger.

**Solución — Compound Trigger:**

- La sección `BEFORE EACH ROW` captura las fechas y la habitación de la fila nueva en una colección en memoria. También valida fechas locales (checkout <= checkin) que no requieren leer otras tablas.
- La sección `AFTER STATEMENT` hace el `SELECT anti-solapamiento` sobre `RESERVA_HABITACION` **después** de que la sentencia terminó (la tabla ya no está mutando). Si detecta solapamiento, lanza `RAISE_APPLICATION_ERROR(-20002, ...)`.

**Regla implementada:** para una misma habitación no pueden coexistir dos registros con estado de reserva `CONFIRMADA` o `COMPLETADA` cuyos rangos `[fecha_checkin, fecha_checkout)` se solapen. Fórmula: solapan si `NOT (checkout_existente <= checkin_nuevo OR checkin_existente >= checkout_nuevo)`.

---

## 4. `fn_valor_estadia` — decisión de diseño

La función calcula el costo total de una estadía sumando el precio de **cada noche individualmente** según la temporada vigente ese día. Esto resuelve la primera decisión de diseño del proyecto: estadías que cruzan temporadas con tarifas distintas.

**Ejemplo:** estadía del 12 al 17 de diciembre 2025.
- 12, 13, 14 dic → `Baja tardía 2025` → $X por noche
- 15, 16 dic    → `Diciembre 2025` (ALTA) → $Y por noche
- Total = 3X + 2Y

**Corrección implementada (determinismo):** la consulta interna ordena por prioridad `ALTA(1) > MEDIA(2) > BAJA(3)` para que si dos temporadas se solapan (posible por diseño del calendario), siempre se use la de mayor peso en lugar de un resultado no determinístico.

---

## 5. `sp_crear_reserva` — validaciones

El procedimiento crea encabezado + líneas de habitación de forma atómica con tres validaciones propias:

| Código  | Condición                                          | Error                              |
|---------|----------------------------------------------------|------------------------------------|
| -20001  | `fecha_checkout <= fecha_checkin`                  | Fechas inválidas                   |
| -20002  | Habitación ya ocupada en ese rango                 | No disponible                      |
| -20003  | `num_huespedes > capacidad` de la habitación       | Capacidad excedida                 |
| -20005  | Habitaciones de distintos alojamientos en 1 reserva| Regla de negocio sección 1.3       |

La validación de **mismo alojamiento** es nueva: el enunciado sección 1.3 dice "un grupo puede reservar 3 habitaciones **del mismo alojamiento**". Sin esta restricción se podría crear una reserva mezclando habitaciones de alojamientos distintos, lo que es operativamente incoherente.

---

## 6. Cursor `c_liquidacion` — liquidación mensual

El cursor parametrizado `c_liquidacion(p_m, p_y)` recorre todos los alojamientos con actividad en el mes/año dado. Calcula:

- **Valor estadías:** `precio_noche_contratado × (fecha_checkout - fecha_checkin)` en SQL puro, sin llamar `fn_valor_estadia` en cada fila del cursor (evita N llamadas PL/SQL dentro del query).
- **Valor servicios:** `SUM(cantidad × precio_unitario)` con `LEFT JOIN` para incluir alojamientos sin servicios contratados ese mes.
- **Total combinado:** estadías + servicios, mostrado en la línea de cada alojamiento y en el total general.

---

## 7. Correcciones al DDL (respecto a Entrega 1)

| Problema original | Corrección |
|-------------------|------------|
| `RESENA` con `UNIQUE(id_reserva)` — un cliente podía reseñar con otra reserva del mismo alojamiento | Cambiado a `UNIQUE(id_cliente, id_alojamiento)` |
| `RESERVA_SERVICIO` sin restricción de unicidad — mismo servicio duplicable en misma reserva | Agregado `UNIQUE(id_reserva, id_servicio)` |
| `HABITACION.tipo` no incluía `'GLAMPING'` | Añadido al CHECK |
| `USUARIO_SISTEMA` sin roles para Entrega 3 | CHECK ampliado: `RECEPCION`, `GERENTE`, `AUDITOR` |
| Sin índices en FKs | Índices creados en todas las FK de tablas grandes |
| Temporada 2024 como un solo periodo MEDIA | Reemplazado con ALTA/MEDIA/BAJA reales para 2024 |
