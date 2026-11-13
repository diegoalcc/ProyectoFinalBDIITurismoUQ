-- =============================================================================
-- TURISMOUQ - ENTREGA 3
-- Script 10: Índices — Identificación de consultas lentas, planes de ejecución,
--            creación de índices (compuesto + basado en función) y análisis del
--            caso donde el índice NO ayuda.
-- Equipo: Sebastián Torres Morales · Jorge William Montoya Toro
--         Diego Alejandro Carvajal Camargo
-- Universidad del Quindío · BD II 2026-2
--
-- Ejecutar como usuario turismouq en XEPDB1
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- PRELIMINAR 0: eliminar índices de ejecuciones anteriores (idempotente)
-- =============================================================================
BEGIN
    FOR i IN (
        SELECT index_name FROM user_indexes
        WHERE index_name IN (
            'IDX_PAGO_ESTADO_RESERVA',
            'IDX_RESERVA_ANIO_CHECKIN',
            'IDX_RH_FECHAS_HAB',
            'IDX_RESERVA_ESTADO'
        )
    ) LOOP
        EXECUTE IMMEDIATE 'DROP INDEX ' || i.index_name;
        DBMS_OUTPUT.PUT_LINE('Índice ' || i.index_name || ' eliminado.');
    END LOOP;
END;
/

-- Limpiar planes anteriores de PLAN_TABLE para no mezclar resultados
DELETE FROM plan_table
WHERE statement_id IN (
    'CL1_ANTES','CL1_DESPUES',
    'CL2_ANTES','CL2_DESPUES',
    'CL3_ANTES','CL3_DESPUES',
    'NO_IDX_ANTES','NO_IDX_DESPUES'
);
COMMIT;

-- =============================================================================
-- PRELIMINAR 1: actualizar estadísticas para que el optimizador tenga información
-- real de cardinalidad antes de los planes.
-- =============================================================================
BEGIN
    DBMS_STATS.GATHER_SCHEMA_STATS(
        ownname          => 'TURISMOUQ',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        cascade          => TRUE
    );
END;
/


-- =============================================================================
-- CONSULTA LENTA 1
-- Pagos exitosos de reservas confirmadas/completadas con JOIN de 5 tablas.
-- Sin índice en PAGO(estado, id_reserva) el plan usa TABLE ACCESS FULL en PAGO.
-- =============================================================================

-- ---- Plan ANTES ----
EXPLAIN PLAN SET STATEMENT_ID = 'CL1_ANTES' FOR
SELECT p.id_pago, p.monto, p.metodo, p.fecha_pago,
       r.id_reserva, c.nombre AS cliente,
       a.nombre AS alojamiento, m.nombre AS municipio
FROM PAGO p
JOIN RESERVA   r ON r.id_reserva     = p.id_reserva
JOIN CLIENTE   c ON c.id_cliente     = r.id_cliente
JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
JOIN HABITACION h ON h.id_habitacion = rh.id_habitacion
JOIN ALOJAMIENTO a ON a.id_alojamiento = h.id_alojamiento
JOIN MUNICIPIO m ON m.id_municipio   = a.id_municipio
WHERE p.estado = 'EXITOSO'
  AND r.estado IN ('CONFIRMADA', 'COMPLETADA');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'CL1_ANTES',
    format       => 'TYPICAL +COST +ROWS'));

-- ---- Crear índice 1: COMPUESTO en PAGO(estado, id_reserva) ----
-- Cubre el filtro de estado Y el join con RESERVA en una sola lectura de índice.
CREATE INDEX idx_pago_estado_reserva
    ON PAGO (estado, id_reserva);

-- ---- Plan DESPUÉS ----
EXPLAIN PLAN SET STATEMENT_ID = 'CL1_DESPUES' FOR
SELECT p.id_pago, p.monto, p.metodo, p.fecha_pago,
       r.id_reserva, c.nombre AS cliente,
       a.nombre AS alojamiento, m.nombre AS municipio
FROM PAGO p
JOIN RESERVA   r ON r.id_reserva     = p.id_reserva
JOIN CLIENTE   c ON c.id_cliente     = r.id_cliente
JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
JOIN HABITACION h ON h.id_habitacion = rh.id_habitacion
JOIN ALOJAMIENTO a ON a.id_alojamiento = h.id_alojamiento
JOIN MUNICIPIO m ON m.id_municipio   = a.id_municipio
WHERE p.estado = 'EXITOSO'
  AND r.estado IN ('CONFIRMADA', 'COMPLETADA');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'CL1_DESPUES',
    format       => 'TYPICAL +COST +ROWS'));


-- =============================================================================
-- CONSULTA LENTA 2
-- Búsqueda de reservas por cliente filtradas por año de check-in.
-- Sin índice funcional en RESERVA, el filtro EXTRACT(YEAR ...) obliga a un
-- TABLE ACCESS FULL porque una función sobre la columna no puede usar índice
-- normal sobre fecha_checkin.
-- =============================================================================

-- ---- Plan ANTES ----
EXPLAIN PLAN SET STATEMENT_ID = 'CL2_ANTES' FOR
SELECT r.id_reserva, c.nombre AS cliente, r.fecha_checkin, r.estado
FROM RESERVA r
JOIN CLIENTE c ON c.id_cliente = r.id_cliente
WHERE EXTRACT(YEAR FROM r.fecha_checkin) = 2025
ORDER BY r.fecha_checkin;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'CL2_ANTES',
    format       => 'TYPICAL +COST +ROWS'));

-- ---- Crear índice 2: BASADO EN FUNCIÓN sobre EXTRACT(YEAR FROM fecha_checkin) ----
CREATE INDEX idx_reserva_anio_checkin
    ON RESERVA (EXTRACT(YEAR FROM fecha_checkin));

-- ---- Plan DESPUÉS ----
EXPLAIN PLAN SET STATEMENT_ID = 'CL2_DESPUES' FOR
SELECT r.id_reserva, c.nombre AS cliente, r.fecha_checkin, r.estado
FROM RESERVA r
JOIN CLIENTE c ON c.id_cliente = r.id_cliente
WHERE EXTRACT(YEAR FROM r.fecha_checkin) = 2025
ORDER BY r.fecha_checkin;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'CL2_DESPUES',
    format       => 'TYPICAL +COST +ROWS'));


-- =============================================================================
-- CONSULTA LENTA 3
-- Ocupación de habitaciones en un rango de fechas: busca reservas donde el
-- período de estadía se solapa con [fecha_in, fecha_out].
-- Sin índice compuesto en RESERVA_HABITACION(id_habitacion, fecha_checkin,
-- fecha_checkout) el optimizador hace full scan de la tabla.
-- =============================================================================

-- ---- Plan ANTES ----
EXPLAIN PLAN SET STATEMENT_ID = 'CL3_ANTES' FOR
SELECT rh.id_habitacion,
       h.numero_habitacion,
       h.tipo,
       rh.fecha_checkin,
       rh.fecha_checkout,
       r.estado
FROM RESERVA_HABITACION rh
JOIN HABITACION h ON h.id_habitacion = rh.id_habitacion
JOIN RESERVA    r ON r.id_reserva    = rh.id_reserva
WHERE rh.fecha_checkin  < DATE '2025-07-01'
  AND rh.fecha_checkout > DATE '2025-06-01'
  AND r.estado IN ('CONFIRMADA', 'COMPLETADA');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'CL3_ANTES',
    format       => 'TYPICAL +COST +ROWS'));

-- ---- Crear índice 3: COMPUESTO en RESERVA_HABITACION(fecha_checkin, fecha_checkout, id_habitacion) ----
-- Las dos columnas de fecha al frente permiten range scan;
-- id_habitacion al final permite index-only lookup (covering index).
CREATE INDEX idx_rh_fechas_hab
    ON RESERVA_HABITACION (fecha_checkin, fecha_checkout, id_habitacion);

-- ---- Plan DESPUÉS ----
EXPLAIN PLAN SET STATEMENT_ID = 'CL3_DESPUES' FOR
SELECT rh.id_habitacion,
       h.numero_habitacion,
       h.tipo,
       rh.fecha_checkin,
       rh.fecha_checkout,
       r.estado
FROM RESERVA_HABITACION rh
JOIN HABITACION h ON h.id_habitacion = rh.id_habitacion
JOIN RESERVA    r ON r.id_reserva    = rh.id_reserva
WHERE rh.fecha_checkin  < DATE '2025-07-01'
  AND rh.fecha_checkout > DATE '2025-06-01'
  AND r.estado IN ('CONFIRMADA', 'COMPLETADA');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'CL3_DESPUES',
    format       => 'TYPICAL +COST +ROWS'));


-- =============================================================================
-- CASO ESPECIAL: ÍNDICE QUE NO AYUDA
--
-- Consulta: total de reservas por estado (agregación sobre toda la tabla).
--
-- Si creamos un índice sobre RESERVA(estado), el optimizador LO IGNORARÁ
-- en la mayoría de los casos porque:
--
--  1. BAJA SELECTIVIDAD: la columna 'estado' solo tiene 4 valores distintos
--     (PENDIENTE, CONFIRMADA, CANCELADA, COMPLETADA).  Con una cardinalidad
--     baja, cada valor representa ~25 % de las filas.  Un índice B-tree no es
--     eficiente cuando hay que acceder a más del 10-15 % de los bloques de la
--     tabla; resulta más costoso (índice + tabla) que un TABLE ACCESS FULL.
--
--  2. CONSULTA DE AGREGACIÓN COMPLETA: el GROUP BY sobre toda la tabla obliga
--     a leer TODAS las filas de todas maneras.  El índice no evita ninguna
--     lectura; solo añade una estructura extra.
--
--  3. PLAN ESPERADO: TABLE ACCESS FULL + HASH GROUP BY, igual antes y después.
--     El costo del plan no cambia porque el optimizador ya elige el camino
--     más eficiente (full scan) dada la distribución de datos.
-- =============================================================================

-- ---- Crear índice (ineficaz para esta consulta) ----
CREATE INDEX idx_reserva_estado
    ON RESERVA (estado);

-- ---- Plan ANTES del índice (ya que el índice acaba de crearse, mostramos
--      el comportamiento equivalente con hint NO_INDEX para ilustrar) ----
EXPLAIN PLAN SET STATEMENT_ID = 'NO_IDX_ANTES' FOR
SELECT /*+ NO_INDEX(r idx_reserva_estado) */ r.estado, COUNT(*) AS total
FROM RESERVA r
GROUP BY r.estado
ORDER BY total DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'NO_IDX_ANTES',
    format       => 'TYPICAL +COST +ROWS'));

-- ---- Plan DESPUÉS del índice (sin hint; el optimizador decide solo) ----
EXPLAIN PLAN SET STATEMENT_ID = 'NO_IDX_DESPUES' FOR
SELECT r.estado, COUNT(*) AS total
FROM RESERVA r
GROUP BY r.estado
ORDER BY total DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'NO_IDX_DESPUES',
    format       => 'TYPICAL +COST +ROWS'));

-- Comparación directa de costos
SELECT statement_id,
       SUM(cost)       AS costo_total,
       SUM(cardinality) AS filas_estimadas
FROM PLAN_TABLE
WHERE statement_id IN ('NO_IDX_ANTES','NO_IDX_DESPUES')
GROUP BY statement_id
ORDER BY statement_id;


-- =============================================================================
-- RESUMEN: índices creados en este script
-- =============================================================================
SELECT index_name,
       index_type,
       table_name,
       status,
       num_rows
FROM user_indexes
WHERE index_name IN (
    'IDX_PAGO_ESTADO_RESERVA',
    'IDX_RESERVA_ANIO_CHECKIN',
    'IDX_RH_FECHAS_HAB',
    'IDX_RESERVA_ESTADO'
)
ORDER BY table_name, index_name;
