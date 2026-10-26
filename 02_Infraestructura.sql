-- =============================================================================
-- TURISMOUQ - INFRAESTRUCTURA: TABLESPACE HISTÓRICO Y VISTA MATERIALIZADA
-- Equipo: Sebastián Torres Morales · Jorge William Montoya Toro · Diego Alejandro Carvajal Camargo
-- IMPORTANTE: Ejecutar como SYSTEM o con privilegio CREATE TABLESPACE.
--             En SQL Developer: conectarse como SYSTEM antes de correr este script.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SECCIÓN 1: TABLESPACE TBS_TURISMOUQ_HIST
-- -----------------------------------------------------------------------------
BEGIN
    EXECUTE IMMEDIATE q'[
        CREATE TABLESPACE TBS_TURISMOUQ_HIST
        DATAFILE 'turismouq_hist01.dbf'
            SIZE 50M
            AUTOEXTEND ON NEXT 20M MAXSIZE 1G
        EXTENT MANAGEMENT LOCAL
        SEGMENT SPACE MANAGEMENT AUTO
    ]';
    DBMS_OUTPUT.PUT_LINE('Tablespace TBS_TURISMOUQ_HIST creado correctamente.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE IN (-1543, -1537, -955, -1119) THEN
            DBMS_OUTPUT.PUT_LINE('INFO: Tablespace ya existe o límite XE alcanzado. Se continúa.');
        ELSE
            RAISE;
        END IF;
END;
/

-- Tabla de archivo histórico en el tablespace dedicado
-- Se usa para mover reservas CANCELADAS/COMPLETADAS antiguas fuera del segmento activo.
BEGIN
    EXECUTE IMMEDIATE q'[
        CREATE TABLE RESERVA_HISTORICO (
            id_reserva      NUMBER(10)   NOT NULL,
            id_cliente      NUMBER(10)   NOT NULL,
            fecha_reserva   DATE,
            fecha_checkin   DATE,
            fecha_checkout  DATE,
            estado          VARCHAR2(15),
            fecha_archivo   TIMESTAMP    DEFAULT SYSTIMESTAMP,
            CONSTRAINT pk_res_hist PRIMARY KEY (id_reserva)
        ) TABLESPACE TBS_TURISMOUQ_HIST
    ]';
    DBMS_OUTPUT.PUT_LINE('Tabla RESERVA_HISTORICO creada en TBS_TURISMOUQ_HIST.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN
            DBMS_OUTPUT.PUT_LINE('INFO: RESERVA_HISTORICO ya existe.');
        ELSE
            RAISE;
        END IF;
END;
/

COMMENT ON TABLE RESERVA_HISTORICO IS
    'Archivo de reservas cerradas. Permite consultas históricas sin penalizar el segmento activo RESERVA.';

-- -----------------------------------------------------------------------------
-- SECCIÓN 2: VISTA MATERIALIZADA MV_OCUPACION_MENSUAL_MUNICIPIO

-- Limpiar vista anterior si existe
BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_OCUPACION_MENSUAL_MUNICIPIO';
    DBMS_OUTPUT.PUT_LINE('Vista materializada anterior eliminada.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE IN (-12003, -942) THEN
            DBMS_OUTPUT.PUT_LINE('INFO: MV no existía previamente.');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE MATERIALIZED VIEW MV_OCUPACION_MENSUAL_MUNICIPIO
    BUILD DEFERRED
    REFRESH COMPLETE ON DEMAND
    ENABLE QUERY REWRITE
AS
SELECT
    m.id_municipio,
    m.nombre                                                  AS municipio,
    EXTRACT(YEAR  FROM rh.fecha_checkin)                      AS anio,
    EXTRACT(MONTH FROM rh.fecha_checkin)                      AS mes,
    -- FIX: columna ordenable como DATE para rangos cronológicos
    TRUNC(rh.fecha_checkin, 'MM')                             AS anio_mes,
    SUM(rh.fecha_checkout - rh.fecha_checkin)                 AS total_noches,
    COUNT(DISTINCT rh.id_habitacion)                          AS habitaciones_ocupadas,
    COUNT(DISTINCT r.id_reserva)                              AS total_reservas,
    -- Ingreso estimado usando precio_noche_contratado × noches (aproximación rápida)
    SUM(rh.precio_noche_contratado * (rh.fecha_checkout - rh.fecha_checkin))
                                                              AS ingreso_estimado
FROM  RESERVA_HABITACION rh
JOIN  RESERVA     r  ON r.id_reserva    = rh.id_reserva
JOIN  HABITACION  h  ON h.id_habitacion = rh.id_habitacion
JOIN  ALOJAMIENTO a  ON a.id_alojamiento = h.id_alojamiento
JOIN  MUNICIPIO   m  ON m.id_municipio   = a.id_municipio
WHERE r.estado IN ('CONFIRMADA', 'COMPLETADA')
GROUP BY
    m.id_municipio,
    m.nombre,
    EXTRACT(YEAR  FROM rh.fecha_checkin),
    EXTRACT(MONTH FROM rh.fecha_checkin),
    TRUNC(rh.fecha_checkin, 'MM');

COMMENT ON MATERIALIZED VIEW MV_OCUPACION_MENSUAL_MUNICIPIO IS
    'Ocupación mensual precalculada por municipio. Refresco manual tras cargas masivas: DBMS_MVIEW.REFRESH(''MV_OCUPACION_MENSUAL_MUNICIPIO'',''C'').';

-- Índice sobre la MV para acelerar consultas por periodo
CREATE INDEX idx_mv_ocup_anio_mes    ON MV_OCUPACION_MENSUAL_MUNICIPIO (anio_mes);
CREATE INDEX idx_mv_ocup_municipio   ON MV_OCUPACION_MENSUAL_MUNICIPIO (id_municipio);


