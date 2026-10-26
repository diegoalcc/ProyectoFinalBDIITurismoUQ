-- =============================================================================
-- TURISMOUQ - CONSULTAS DE ANÁLISIS (ENTREGA 1 CORREGIDAS + ENTREGA 2)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CONSULTA 1: Ocupación por municipio y mes (PIVOT)
-- -----------------------------------------------------------------------------
SELECT *
FROM (
    SELECT
        m.nombre AS municipio,
        TO_CHAR(rh.fecha_checkin, 'MM') AS mes,
        (rh.fecha_checkout - rh.fecha_checkin) AS noches_reservadas
    FROM RESERVA_HABITACION rh
    JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
    JOIN ALOJAMIENTO a ON h.id_alojamiento = a.id_alojamiento
    JOIN MUNICIPIO m ON a.id_municipio = m.id_municipio
    JOIN RESERVA r ON rh.id_reserva = r.id_reserva
    WHERE r.estado IN ('CONFIRMADA', 'COMPLETADA')
)
PIVOT (
    SUM(noches_reservadas)
    FOR mes IN (
        '01' AS ene, '02' AS feb, '03' AS mar, '04' AS abr,
        '05' AS may, '06' AS jun, '07' AS jul, '08' AS ago,
        '09' AS sep, '10' AS oct, '11' AS nov, '12' AS dic
    )
)
ORDER BY municipio;

-- -----------------------------------------------------------------------------
-- CONSULTA 2: Ingresos por municipio, tipo y temporada (ROLLUP + GROUPING)
-- Ingreso por noche según tarifa vigente en cada día de estadía (sin inflar filas).
-- -----------------------------------------------------------------------------
WITH noches_estadia AS (
    SELECT
        rh.id_reserva_habitacion,
        rh.id_habitacion,
        r.id_reserva,
        (TRUNC(rh.fecha_checkin) + (n.n - 1)) AS dia_estadia
    FROM RESERVA_HABITACION rh
    JOIN RESERVA r ON r.id_reserva = rh.id_reserva
    JOIN (
        SELECT LEVEL AS n FROM DUAL CONNECT BY LEVEL <= 60
    ) n ON n.n <= (rh.fecha_checkout - rh.fecha_checkin)
    WHERE r.estado IN ('CONFIRMADA', 'COMPLETADA')
),
ingreso_noche AS (
    SELECT
        ne.id_reserva,
        ne.id_habitacion,
        ne.dia_estadia,
        (
            SELECT tf.precio_noche
            FROM TARIFA tf
            JOIN TEMPORADA t ON t.id_temporada = tf.id_temporada
            WHERE tf.id_habitacion = ne.id_habitacion
              AND ne.dia_estadia BETWEEN t.fecha_inicio AND t.fecha_fin
            FETCH FIRST 1 ROW ONLY
        ) AS valor_noche
    FROM noches_estadia ne
),
ingreso_reserva AS (
    SELECT id_reserva, SUM(NVL(valor_noche, 0)) AS ingreso_estadia
    FROM ingreso_noche
    GROUP BY id_reserva
),
ingreso_servicios AS (
    SELECT id_reserva, SUM(cantidad * precio_unitario) AS ingreso_serv
    FROM RESERVA_SERVICIO
    GROUP BY id_reserva
),
ingreso_noche_temp AS (
    SELECT
        in2.id_habitacion,
        in2.dia_estadia,
        NVL(in2.valor_noche, 0) AS valor_noche,
        (
            SELECT t.tipo_temporada
            FROM TARIFA tf
            JOIN TEMPORADA t ON t.id_temporada = tf.id_temporada
            WHERE tf.id_habitacion = in2.id_habitacion
              AND in2.dia_estadia BETWEEN t.fecha_inicio AND t.fecha_fin
            FETCH FIRST 1 ROW ONLY
        ) AS tipo_temporada
    FROM ingreso_noche in2
),
ingreso_temporada AS (
    SELECT
        m.nombre AS municipio,
        ta.nombre AS tipo_alojamiento,
        intp.tipo_temporada,
        SUM(intp.valor_noche) AS ingresos
    FROM ingreso_noche_temp intp
    JOIN HABITACION h ON h.id_habitacion = intp.id_habitacion
    JOIN ALOJAMIENTO a ON a.id_alojamiento = h.id_alojamiento
    JOIN MUNICIPIO m ON m.id_municipio = a.id_municipio
    JOIN TIPO_ALOJAMIENTO ta ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
    GROUP BY m.nombre, ta.nombre, intp.tipo_temporada
)
SELECT
    CASE WHEN GROUPING(municipio) = 1 THEN '--- TOTAL GENERAL ---' ELSE municipio END AS municipio,
    CASE WHEN GROUPING(tipo_alojamiento) = 1 THEN '--- Subtotal municipio ---' ELSE tipo_alojamiento END AS tipo_alojamiento,
    CASE WHEN GROUPING(tipo_temporada) = 1 THEN '--- Subtotal tipo ---' ELSE tipo_temporada END AS temporada,
    SUM(ingresos) AS ingresos_estadia_por_temporada
FROM ingreso_temporada
GROUP BY ROLLUP (municipio, tipo_alojamiento, tipo_temporada);

-- -----------------------------------------------------------------------------
-- CONSULTA 3: Top 3 alojamientos por ingreso en cada municipio (RANK)
-- -----------------------------------------------------------------------------
WITH ingresos_aloj AS (
    SELECT
        m.nombre AS municipio,
        a.nombre AS alojamiento,
        SUM(p.monto) AS total_ingresos
    FROM PAGO p
    JOIN RESERVA r ON r.id_reserva = p.id_reserva
    JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
    JOIN HABITACION h ON h.id_habitacion = rh.id_habitacion
    JOIN ALOJAMIENTO a ON a.id_alojamiento = h.id_alojamiento
    JOIN MUNICIPIO m ON m.id_municipio = a.id_municipio
    WHERE p.estado = 'EXITOSO'
    GROUP BY m.nombre, a.nombre
),
ranking AS (
    SELECT
        municipio,
        alojamiento,
        total_ingresos,
        RANK() OVER (PARTITION BY municipio ORDER BY total_ingresos DESC) AS pos
    FROM ingresos_aloj
)
SELECT municipio, pos, alojamiento, total_ingresos
FROM ranking
WHERE pos <= 3
ORDER BY municipio, pos;

-- -----------------------------------------------------------------------------
-- CONSULTA 4: Variación de ingresos mes a mes (LAG)
-- -----------------------------------------------------------------------------
WITH ingresos_mensuales AS (
    SELECT TO_CHAR(fecha_pago, 'YYYY-MM') AS periodo, SUM(monto) AS ingreso_actual
    FROM PAGO
    WHERE estado = 'EXITOSO'
    GROUP BY TO_CHAR(fecha_pago, 'YYYY-MM')
)
SELECT
    periodo,
    ingreso_actual,
    LAG(ingreso_actual, 1, 0) OVER (ORDER BY periodo) AS ingreso_mes_anterior,
    ingreso_actual - LAG(ingreso_actual, 1, 0) OVER (ORDER BY periodo) AS variacion_absoluta,
    ROUND(
        (ingreso_actual - LAG(ingreso_actual, 1, 0) OVER (ORDER BY periodo))
        / NULLIF(LAG(ingreso_actual, 1, 0) OVER (ORDER BY periodo), 0) * 100,
        2
    ) AS variacion_pct
FROM ingresos_mensuales
ORDER BY periodo;

-- -----------------------------------------------------------------------------
-- CONSULTA 5: Parametrizada con VARIABLE y TO_DATE
-- Ejecutar en SQL*Plus / SQLcl:
-- -----------------------------------------------------------------------------
VARIABLE fecha_inicio VARCHAR2(10);
VARIABLE fecha_fin VARCHAR2(10);
EXEC :fecha_inicio := '2025-01-01';
EXEC :fecha_fin := '2025-12-31';

SELECT
    r.id_reserva,
    c.nombre AS cliente,
    c.documento_identidad,
    a.nombre AS alojamiento,
    r.fecha_checkin,
    r.fecha_checkout,
    r.estado
FROM RESERVA r
JOIN CLIENTE c ON r.id_cliente = c.id_cliente
JOIN RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
JOIN ALOJAMIENTO a ON h.id_alojamiento = a.id_alojamiento
WHERE r.fecha_checkin >= TO_DATE(:fecha_inicio, 'YYYY-MM-DD')
  AND r.fecha_checkout <= TO_DATE(:fecha_fin, 'YYYY-MM-DD')
ORDER BY r.fecha_checkin;

-- -----------------------------------------------------------------------------
-- CONSULTA 6: UNPIVOT
-- -----------------------------------------------------------------------------
WITH consolidado AS (
    SELECT *
    FROM (
        SELECT m.nombre AS municipio, TO_CHAR(p.fecha_pago, 'MM') AS mes, p.monto
        FROM PAGO p
        JOIN RESERVA r ON p.id_reserva = r.id_reserva
        JOIN RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
        JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
        JOIN ALOJAMIENTO a ON h.id_alojamiento = a.id_alojamiento
        JOIN MUNICIPIO m ON a.id_municipio = m.id_municipio
        WHERE p.estado = 'EXITOSO'
          AND EXTRACT(YEAR FROM p.fecha_pago) = 2025
    )
    PIVOT (SUM(monto) FOR mes IN ('01' AS ene, '02' AS feb, '03' AS mar, '04' AS abr))
)
SELECT municipio, mes_nombre, total_ingreso
FROM consolidado
UNPIVOT (total_ingreso FOR mes_nombre IN (ene AS 'Enero', feb AS 'Febrero', mar AS 'Marzo', abr AS 'Abril'))
ORDER BY municipio, mes_nombre;

-- -----------------------------------------------------------------------------
-- CONSULTA 7: Libre (demanda + ingresos + reseñas sin duplicar filas)
-- -----------------------------------------------------------------------------
WITH promedio_resenas AS (
    SELECT id_alojamiento, ROUND(AVG(calificacion), 2) AS promedio_estrellas, COUNT(*) AS total_resenas
    FROM RESENA
    GROUP BY id_alojamiento
),
ingresos_alojamiento AS (
    SELECT a.id_alojamiento, SUM(p.monto) AS ingresos_acumulados
    FROM ALOJAMIENTO a
    JOIN HABITACION h ON h.id_alojamiento = a.id_alojamiento
    JOIN RESERVA_HABITACION rh ON rh.id_habitacion = h.id_habitacion
    JOIN RESERVA r ON r.id_reserva = rh.id_reserva
    JOIN PAGO p ON p.id_reserva = r.id_reserva AND p.estado = 'EXITOSO'
    WHERE r.estado = 'COMPLETADA'
    GROUP BY a.id_alojamiento
),
reservas_completadas AS (
    SELECT a.id_alojamiento, COUNT(DISTINCT r.id_reserva) AS total_reservas
    FROM ALOJAMIENTO a
    JOIN HABITACION h ON h.id_alojamiento = a.id_alojamiento
    JOIN RESERVA_HABITACION rh ON rh.id_habitacion = h.id_habitacion
    JOIN RESERVA r ON r.id_reserva = rh.id_reserva
    WHERE r.estado = 'COMPLETADA'
    GROUP BY a.id_alojamiento
)
SELECT
    m.nombre AS municipio,
    a.nombre AS alojamiento,
    ta.nombre AS tipo,
    rc.total_reservas,
    pr.promedio_estrellas,
    ia.ingresos_acumulados
FROM ALOJAMIENTO a
JOIN MUNICIPIO m ON m.id_municipio = a.id_municipio
JOIN TIPO_ALOJAMIENTO ta ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
LEFT JOIN reservas_completadas rc ON rc.id_alojamiento = a.id_alojamiento
LEFT JOIN ingresos_alojamiento ia ON ia.id_alojamiento = a.id_alojamiento
LEFT JOIN promedio_resenas pr ON pr.id_alojamiento = a.id_alojamiento
WHERE NVL(rc.total_reservas, 0) > 5
ORDER BY pr.promedio_estrellas DESC NULLS LAST, ia.ingresos_acumulados DESC NULLS LAST;
