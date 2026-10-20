-- =============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - CONSULTAS DE ANÁLISIS (ENTREGA 1)
-- Equipo: Sebastian Torres Morales - Jorge William Montoya Toro - Diego ALejandro Carvajal Camar
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CONSULTA 1: Ocupación por Municipio y Mes con PIVOT
-- Calcula el total de noches reservadas por municipio agrupadas por mes.
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
        '01' AS Enero, '02' AS Febrero, '03' AS Marzo, '04' AS Abril,
        '05' AS Mayo, '06' AS Junio, '07' AS Julio, '08' AS Agosto,
        '09' AS Septiembre, '10' AS Octubre, '11' AS Noviembre, '12' AS Diciembre
    )
)
ORDER BY municipio;


-- -----------------------------------------------------------------------------
-- CONSULTA 2: Ingresos por Municipio, Tipo de Alojamiento y Temporada (ROLLUP/GROUPING)
-- Permite visualizar subtotales y gran total de ingresos distinguidos dinámicamente.
-- -----------------------------------------------------------------------------
SELECT 
    CASE WHEN GROUPING(m.nombre) = 1 THEN '--- TOTAL GENERAL ---' ELSE m.nombre END AS municipio,
    CASE WHEN GROUPING(ta.nombre) = 1 THEN '--- Subtotal Municipio ---' ELSE ta.nombre END AS tipo_alojamiento,
    CASE WHEN GROUPING(t.tipo_temporada) = 1 THEN '--- Subtotal Tipo ---' ELSE t.tipo_temporada END AS temporada,
    SUM(p.monto) AS ingresos_totales
FROM PAGO p
JOIN RESERVA r ON p.id_reserva = r.id_reserva
JOIN RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
JOIN ALOJAMIENTO a ON h.id_alojamiento = a.id_alojamiento
JOIN MUNICIPIO m ON a.id_municipio = m.id_municipio
JOIN TIPO_ALOJAMIENTO ta ON a.id_tipo_alojamiento = ta.id_tipo_alojamiento
LEFT JOIN TARIFA tf ON h.id_habitacion = tf.id_habitacion
LEFT JOIN TEMPORADA t ON tf.id_temporada = t.id_temporada
WHERE p.estado = 'EXITOSO'
GROUP BY ROLLUP(m.nombre, ta.nombre, t.tipo_temporada);


-- -----------------------------------------------------------------------------
-- CONSULTA 3: Top 3 Alojamientos de mayor ingreso por Municipio (RANK con PARTITION BY)
-- Clasifica los 3 establecimientos mas rentables dentro de cada municipio.
-- -----------------------------------------------------------------------------
WITH IngresosAlojamiento AS (
    SELECT 
        m.nombre AS municipio,
        a.nombre AS alojamiento,
        SUM(p.monto) AS total_ingresos,
        RANK() OVER (PARTITION BY m.nombre ORDER BY SUM(p.monto) DESC) AS ranking
    FROM ALOJAMIENTO a
    JOIN MUNICIPIO m ON a.id_municipio = m.id_municipio
    JOIN HABITACION h ON a.id_alojamiento = h.id_alojamiento
    JOIN RESERVA_HABITACION rh ON h.id_habitacion = rh.id_habitacion
    JOIN RESERVA r ON rh.id_reserva = r.id_reserva
    JOIN PAGO p ON r.id_reserva = p.id_reserva
    WHERE p.estado = 'EXITOSO'
    GROUP BY m.nombre, a.nombre
)
SELECT municipio, ranking, alojamiento, total_ingresos
FROM IngresosAlojamiento
WHERE ranking <= 3
ORDER BY municipio, ranking;

-- -----------------------------------------------------------------------------
-- CONSULTA 4: Variación de Ingresos Mes contra Mes (LAG)
-- Compara la facturación mensual actual con el mes inmediatamente anterior.
-- -----------------------------------------------------------------------------
WITH IngresosMensuales AS (
    SELECT 
        TO_CHAR(fecha_pago, 'YYYY-MM') AS periodo,
        SUM(monto) AS ingreso_actual
    FROM PAGO
    WHERE estado = 'EXITOSO'
    GROUP BY TO_CHAR(fecha_pago, 'YYYY-MM')
)
SELECT 
    periodo,
    ingreso_actual,
    LAG(ingreso_actual, 1, 0) OVER (ORDER BY periodo) AS ingreso_mes_anterior,
    (ingreso_actual - LAG(ingreso_actual, 1, 0) OVER (ORDER BY periodo)) AS variacion_absoluta,
    ROUND(
        ((ingreso_actual - LAG(ingreso_actual, 1, 0) OVER (ORDER BY periodo)) / 
        NULLIF(LAG(ingreso_actual, 1, 0) OVER (ORDER BY periodo), 0)) * 100, 2
    ) AS variacion_porcentual
FROM IngresosMensuales
ORDER BY periodo;


-- -----------------------------------------------------------------------------
-- CONSULTA 5: Consulta Parametrizada por Rango de Fechas
-- Filtra reservas y sus clientes mediante variables de enlace (:fecha_inicio y :fecha_fin).
-- -----------------------------------------------------------------------------
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
WHERE r.fecha_checkin >= :fecha_inicio 
  AND r.fecha_checkout <= :fecha_fin
ORDER BY r.fecha_checkin ASC;


-- -----------------------------------------------------------------------------
-- CONSULTA 6: Transformación de Matriz a Filas con UNPIVOT
-- Normaliza un consolidado semestral en una estructura orientada a filas.
-- -----------------------------------------------------------------------------
WITH ConsolidadoIngresos AS (
    SELECT *
    FROM (
        SELECT 
            m.nombre AS municipio,
            TO_CHAR(p.fecha_pago, 'MM') AS mes,
            p.monto
        FROM PAGO p
        JOIN RESERVA r ON p.id_reserva = r.id_reserva
        JOIN RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
        JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
        JOIN ALOJAMIENTO a ON h.id_alojamiento = a.id_alojamiento
        JOIN MUNICIPIO m ON a.id_municipio = m.id_municipio
        WHERE p.estado = 'EXITOSO'
          AND TO_CHAR(p.fecha_pago, 'YYYY') = '2025'
    )
    PIVOT (
        SUM(monto) FOR mes IN ('01' AS ENE, '02' AS FEB, '03' AS MAR, '04' AS ABR)
    )
)
SELECT municipio, mes_nombre, total_ingreso
FROM ConsolidadoIngresos
UNPIVOT (
    total_ingreso FOR mes_nombre IN (ENE AS 'Enero', FEB AS 'Febrero', MAR AS 'Marzo', ABR AS 'Abril')
)
ORDER BY municipio, mes_nombre;


-- -----------------------------------------------------------------------------
-- CONSULTA 7 (Consulta Libre): Desempeño Operativo y Reputación por Alojamiento
-- Responde: ¿Qué alojamientos combinan alta demanda, volumen de ingresos
-- y calificaciones superiores según la opinión de los clientes?
-- -----------------------------------------------------------------------------
SELECT 
    m.nombre AS municipio,
    a.nombre AS alojamiento,
    ta.nombre AS tipo,
    COUNT(DISTINCT r.id_reserva) AS total_reservas_completadas,
    ROUND(AVG(res.calificacion), 2) AS promedio_estrellas_reseñas,
    SUM(p.monto) AS ingresos_acumulados
FROM ALOJAMIENTO a
JOIN MUNICIPIO m ON a.id_municipio = m.id_municipio
JOIN TIPO_ALOJAMIENTO ta ON a.id_tipo_alojamiento = ta.id_tipo_alojamiento
JOIN HABITACION h ON a.id_alojamiento = h.id_alojamiento
JOIN RESERVA_HABITACION rh ON h.id_habitacion = rh.id_habitacion
JOIN RESERVA r ON rh.id_reserva = r.id_reserva
LEFT JOIN PAGO p ON r.id_reserva = p.id_reserva AND p.estado = 'EXITOSO'
LEFT JOIN RESENA res ON a.id_alojamiento = res.id_alojamiento
WHERE r.estado = 'COMPLETADA'
GROUP BY m.nombre, a.nombre, ta.nombre
HAVING COUNT(DISTINCT r.id_reserva) > 5
ORDER BY promedio_estrellas_reseñas DESC, ingresos_acumulados DESC;