-- =============================================================================
-- TURISMOUQ - ENTREGA 3
-- Script 11: Seguridad — Roles, Vistas, Usuarios y Perfil de sesión
-- Equipo: Sebastián Torres Morales · Jorge William Montoya Toro
--         Diego Alejandro Carvajal Camargo
-- Universidad del Quindío · BD II 2026-2
--
-- Ejecutar como SYSTEM (o DBA) en XEPDB1 DESPUÉS de que turismouq ya tenga
-- sus objetos creados (scripts 01 a 08).
-- =============================================================================

-- =============================================================================
-- SECCIÓN 0: LIMPIEZA PREVIA  (re-ejecución idempotente)
-- =============================================================================

BEGIN
    FOR u IN (SELECT username FROM dba_users
              WHERE username IN ('USR_RECEPCION','USR_ALOJAMIENTO',
                                 'USR_GERENTE','USR_AUDITOR')) LOOP
        EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
    END LOOP;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    FOR r IN (SELECT role FROM dba_roles
              WHERE role IN ('ROL_RECEPCION','ROL_ALOJAMIENTO',
                             'ROL_GERENTE','ROL_AUDITOR')) LOOP
        EXECUTE IMMEDIATE 'DROP ROLE ' || r.role;
    END LOOP;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP PROFILE perfil_recepcion CASCADE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/


-- =============================================================================
-- SECCIÓN 1: CUATRO ROLES CON PRIVILEGIOS DIFERENCIADOS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- ROL 1: RECEPCIÓN
-- Acceso solo a través de vistas (nunca a las tablas base directamente).
-- Puede consultar disponibilidad, crear reservas y registrar pagos.
-- ---------------------------------------------------------------------------
CREATE ROLE ROL_RECEPCION;

-- ---------------------------------------------------------------------------
-- ROL 2: ADMINISTRADOR DE ALOJAMIENTO
-- Gestiona la información de alojamientos y habitaciones, y sus tarifas.
-- Tiene acceso directo a las tablas de catálogo (no a datos financieros).
-- ---------------------------------------------------------------------------
CREATE ROLE ROL_ALOJAMIENTO;

-- ---------------------------------------------------------------------------
-- ROL 3: GERENTE
-- Acceso de lectura a todas las tablas y vistas para supervisión y análisis.
-- No puede modificar datos operativos.
-- ---------------------------------------------------------------------------
CREATE ROLE ROL_GERENTE;

-- ---------------------------------------------------------------------------
-- ROL 4: AUDITOR
-- Acceso de solo lectura a la tabla de auditoría y vistas de resumen.
-- Ningún permiso de escritura.
-- ---------------------------------------------------------------------------
CREATE ROLE ROL_AUDITOR;


-- =============================================================================
-- SECCIÓN 2: VISTAS PARA EL ROL DE RECEPCIÓN
-- (recepción nunca accede a las tablas directamente)
-- =============================================================================

-- ---- Vista: habitaciones disponibles ----
CREATE OR REPLACE VIEW turismouq.VW_HABITACIONES_DISPONIBLES AS
SELECT h.id_habitacion,
       h.numero_habitacion,
       h.tipo,
       h.capacidad,
       a.nombre   AS alojamiento,
       m.nombre   AS municipio,
       ta.nombre  AS tipo_alojamiento
FROM turismouq.HABITACION    h
JOIN turismouq.ALOJAMIENTO   a  ON a.id_alojamiento    = h.id_alojamiento
JOIN turismouq.MUNICIPIO     m  ON m.id_municipio       = a.id_municipio
JOIN turismouq.TIPO_ALOJAMIENTO ta ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
WHERE NOT EXISTS (
    SELECT 1 FROM turismouq.RESERVA_HABITACION rh
    JOIN turismouq.RESERVA r ON r.id_reserva = rh.id_reserva
    WHERE rh.id_habitacion = h.id_habitacion
      AND r.estado IN ('CONFIRMADA','PENDIENTE')
      AND rh.fecha_checkin  < TRUNC(SYSDATE) + 30
      AND rh.fecha_checkout > TRUNC(SYSDATE)
);

COMMENT ON TABLE turismouq.VW_HABITACIONES_DISPONIBLES IS
    'Vista de acceso para Recepción: habitaciones sin reserva activa en los próximos 30 días.';

-- ---- Vista: clientes registrados (sin datos sensibles completos) ----
CREATE OR REPLACE VIEW turismouq.VW_CLIENTES AS
SELECT id_cliente,
       nombre,
       RPAD(SUBSTR(documento_identidad, 1, 3), LENGTH(documento_identidad), '*')
           AS documento_parcial,
       email,
       ciudad_origen
FROM turismouq.CLIENTE;

COMMENT ON TABLE turismouq.VW_CLIENTES IS
    'Vista de acceso para Recepción: datos de clientes con documento parcialmente enmascarado.';

-- ---- Vista: reservas activas para consulta y seguimiento ----
CREATE OR REPLACE VIEW turismouq.VW_RESERVAS_ACTIVAS AS
SELECT r.id_reserva,
       c.nombre        AS cliente,
       c.email         AS email_cliente,
       a.nombre        AS alojamiento,
       m.nombre        AS municipio,
       r.fecha_checkin,
       r.fecha_checkout,
       r.estado,
       r.fecha_registro
FROM turismouq.RESERVA             r
JOIN turismouq.CLIENTE             c  ON c.id_cliente      = r.id_cliente
JOIN turismouq.RESERVA_HABITACION  rh ON rh.id_reserva     = r.id_reserva
JOIN turismouq.HABITACION          h  ON h.id_habitacion   = rh.id_habitacion
JOIN turismouq.ALOJAMIENTO         a  ON a.id_alojamiento  = h.id_alojamiento
JOIN turismouq.MUNICIPIO           m  ON m.id_municipio    = a.id_municipio
WHERE r.estado IN ('CONFIRMADA', 'PENDIENTE');

COMMENT ON TABLE turismouq.VW_RESERVAS_ACTIVAS IS
    'Vista de acceso para Recepción: reservas vigentes (CONFIRMADA o PENDIENTE).';

-- ---- Vista: pagos de reservas (recepción solo ve monto y estado, no más) ----
CREATE OR REPLACE VIEW turismouq.VW_PAGOS_RECEPCION AS
SELECT p.id_pago,
       p.id_reserva,
       p.fecha_pago,
       p.monto,
       p.metodo_pago,
       p.estado
FROM turismouq.PAGO p
JOIN turismouq.RESERVA r ON r.id_reserva = p.id_reserva
WHERE r.estado IN ('CONFIRMADA','PENDIENTE','COMPLETADA');

COMMENT ON TABLE turismouq.VW_PAGOS_RECEPCION IS
    'Vista de acceso para Recepción: pagos de reservas activas o completadas.';

-- ---- Vista gerencial: resumen de ingresos por municipio y mes ----
CREATE OR REPLACE VIEW turismouq.VW_INGRESOS_MUNICIPIO AS
SELECT m.nombre AS municipio,
       TO_CHAR(p.fecha_pago, 'YYYY-MM') AS periodo,
       COUNT(DISTINCT r.id_reserva)     AS total_reservas,
       SUM(p.monto)                     AS ingresos_totales
FROM turismouq.PAGO            p
JOIN turismouq.RESERVA         r  ON r.id_reserva   = p.id_reserva
JOIN turismouq.RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
JOIN turismouq.HABITACION      h  ON h.id_habitacion = rh.id_habitacion
JOIN turismouq.ALOJAMIENTO     a  ON a.id_alojamiento = h.id_alojamiento
JOIN turismouq.MUNICIPIO       m  ON m.id_municipio  = a.id_municipio
WHERE p.estado = 'EXITOSO'
GROUP BY m.nombre, TO_CHAR(p.fecha_pago, 'YYYY-MM');

COMMENT ON TABLE turismouq.VW_INGRESOS_MUNICIPIO IS
    'Vista gerencial: ingresos mensuales consolidados por municipio.';

-- ---- Vista de auditoría para el auditor ----
CREATE OR REPLACE VIEW turismouq.VW_AUDITORIA_TARIFAS AS
SELECT at.id_auditoria,
       at.usuario_bd,
       at.fecha_evento,
       at.tipo_operacion,
       at.id_tarifa,
       at.id_habitacion,
       at.id_temporada,
       at.precio_anterior,
       at.precio_nuevo,
       (at.precio_nuevo - NVL(at.precio_anterior, 0)) AS diferencia
FROM turismouq.AUDITORIA_TARIFA at;

COMMENT ON TABLE turismouq.VW_AUDITORIA_TARIFAS IS
    'Vista de auditoría: historial completo de cambios en tarifas con diferencia calculada.';


-- =============================================================================
-- SECCIÓN 3: PERFIL CON LÍMITES DE SESIÓN
-- Para usuarios de recepción: máximo 3 sesiones simultáneas,
-- contraseña expira cada 60 días, bloqueo tras 5 intentos fallidos.
-- =============================================================================

CREATE PROFILE perfil_recepcion LIMIT
    SESSIONS_PER_USER         3
    CPU_PER_SESSION            UNLIMITED
    CPU_PER_CALL               UNLIMITED
    CONNECT_TIME               480
    IDLE_TIME                  30
    LOGICAL_READS_PER_SESSION  UNLIMITED
    LOGICAL_READS_PER_CALL     UNLIMITED
    COMPOSITE_LIMIT            UNLIMITED
    PASSWORD_LIFE_TIME         60
    PASSWORD_REUSE_TIME        365
    PASSWORD_REUSE_MAX         5
    PASSWORD_VERIFY_FUNCTION   NULL
    PASSWORD_LOCK_TIME         1/24
    PASSWORD_GRACE_TIME        7
    FAILED_LOGIN_ATTEMPTS      5;


-- =============================================================================
-- SECCIÓN 4: USUARIOS DE PRUEBA
-- =============================================================================

CREATE USER USR_RECEPCION
    IDENTIFIED BY "Recepcion#2026"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 0 ON USERS
    PROFILE perfil_recepcion;

CREATE USER USR_ALOJAMIENTO
    IDENTIFIED BY "Alojam#2026"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 5M ON USERS;

CREATE USER USR_GERENTE
    IDENTIFIED BY "Gerente#2026"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 0 ON USERS;

CREATE USER USR_AUDITOR
    IDENTIFIED BY "Auditor#2026"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 0 ON USERS;


-- =============================================================================
-- SECCIÓN 5: GRANTs SOBRE VISTAS (ROL_RECEPCION)
-- La recepción JAMÁS recibe privilegios directos sobre las tablas base.
-- =============================================================================

-- Sesión
GRANT CREATE SESSION TO ROL_RECEPCION;

-- Solo vistas — SELECT
GRANT SELECT ON turismouq.VW_HABITACIONES_DISPONIBLES TO ROL_RECEPCION;
GRANT SELECT ON turismouq.VW_CLIENTES                  TO ROL_RECEPCION;
GRANT SELECT ON turismouq.VW_RESERVAS_ACTIVAS          TO ROL_RECEPCION;
GRANT SELECT ON turismouq.VW_PAGOS_RECEPCION           TO ROL_RECEPCION;

-- Recepción puede ejecutar los procedimientos del paquete para crear reservas y pagos
-- pero NO puede acceder a las tablas subyacentes directamente.
GRANT EXECUTE ON turismouq.PKG_TURISMOUQ TO ROL_RECEPCION;


-- =============================================================================
-- SECCIÓN 6: GRANTs SOBRE TABLAS (ROL_ALOJAMIENTO)
-- Administra catálogos: alojamientos, habitaciones, tarifas, temporadas.
-- Sin acceso a datos de clientes, reservas ni pagos.
-- =============================================================================

GRANT CREATE SESSION TO ROL_ALOJAMIENTO;

GRANT SELECT, INSERT, UPDATE, DELETE ON turismouq.ALOJAMIENTO      TO ROL_ALOJAMIENTO;
GRANT SELECT, INSERT, UPDATE, DELETE ON turismouq.HABITACION        TO ROL_ALOJAMIENTO;
GRANT SELECT, INSERT, UPDATE, DELETE ON turismouq.TARIFA            TO ROL_ALOJAMIENTO;
GRANT SELECT, INSERT, UPDATE, DELETE ON turismouq.TEMPORADA         TO ROL_ALOJAMIENTO;
GRANT SELECT, INSERT, UPDATE, DELETE ON turismouq.SERVICIO          TO ROL_ALOJAMIENTO;
GRANT SELECT, INSERT, UPDATE, DELETE ON turismouq.TIPO_ALOJAMIENTO  TO ROL_ALOJAMIENTO;
GRANT SELECT                         ON turismouq.MUNICIPIO         TO ROL_ALOJAMIENTO;

-- Vistas de referencia (solo lectura)
GRANT SELECT ON turismouq.VW_HABITACIONES_DISPONIBLES TO ROL_ALOJAMIENTO;


-- =============================================================================
-- SECCIÓN 7: GRANTs DE LECTURA (ROL_GERENTE)
-- Lectura total para supervisión; sin escritura en ninguna tabla operativa.
-- =============================================================================

GRANT CREATE SESSION TO ROL_GERENTE;

GRANT SELECT ON turismouq.ALOJAMIENTO       TO ROL_GERENTE;
GRANT SELECT ON turismouq.HABITACION        TO ROL_GERENTE;
GRANT SELECT ON turismouq.TARIFA            TO ROL_GERENTE;
GRANT SELECT ON turismouq.TEMPORADA         TO ROL_GERENTE;
GRANT SELECT ON turismouq.SERVICIO          TO ROL_GERENTE;
GRANT SELECT ON turismouq.TIPO_ALOJAMIENTO  TO ROL_GERENTE;
GRANT SELECT ON turismouq.MUNICIPIO         TO ROL_GERENTE;
GRANT SELECT ON turismouq.CLIENTE           TO ROL_GERENTE;
GRANT SELECT ON turismouq.RESERVA           TO ROL_GERENTE;
GRANT SELECT ON turismouq.RESERVA_HABITACION TO ROL_GERENTE;
GRANT SELECT ON turismouq.PAGO              TO ROL_GERENTE;
GRANT SELECT ON turismouq.RESERVA_SERVICIO  TO ROL_GERENTE;
GRANT SELECT ON turismouq.RESENA            TO ROL_GERENTE;

-- Vistas analíticas
GRANT SELECT ON turismouq.VW_INGRESOS_MUNICIPIO     TO ROL_GERENTE;
GRANT SELECT ON turismouq.VW_RESERVAS_ACTIVAS       TO ROL_GERENTE;
GRANT SELECT ON turismouq.VW_HABITACIONES_DISPONIBLES TO ROL_GERENTE;

-- Puede ejecutar el paquete para cálculos (read-only en la práctica)
GRANT EXECUTE ON turismouq.PKG_TURISMOUQ TO ROL_GERENTE;


-- =============================================================================
-- SECCIÓN 8: GRANTs DE AUDITORÍA (ROL_AUDITOR)
-- Solo lectura sobre auditoría y vistas de resumen; cero acceso a tablas operativas.
-- =============================================================================

GRANT CREATE SESSION TO ROL_AUDITOR;

GRANT SELECT ON turismouq.AUDITORIA_TARIFA      TO ROL_AUDITOR;
GRANT SELECT ON turismouq.VW_AUDITORIA_TARIFAS  TO ROL_AUDITOR;
GRANT SELECT ON turismouq.VW_INGRESOS_MUNICIPIO TO ROL_AUDITOR;


-- =============================================================================
-- SECCIÓN 9: ASIGNAR ROLES A USUARIOS
-- =============================================================================

GRANT ROL_RECEPCION   TO USR_RECEPCION;
GRANT ROL_ALOJAMIENTO TO USR_ALOJAMIENTO;
GRANT ROL_GERENTE     TO USR_GERENTE;
GRANT ROL_AUDITOR     TO USR_AUDITOR;


-- =============================================================================
-- SECCIÓN 10: VERIFICACIÓN
-- =============================================================================

SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee IN ('USR_RECEPCION','USR_ALOJAMIENTO','USR_GERENTE','USR_AUDITOR')
ORDER BY grantee;

SELECT grantee, privilege, table_name, grantable
FROM dba_tab_privs
WHERE grantee IN ('ROL_RECEPCION','ROL_ALOJAMIENTO','ROL_GERENTE','ROL_AUDITOR')
ORDER BY grantee, table_name;

SELECT username, profile, account_status, lock_date, expiry_date
FROM dba_users
WHERE username IN ('USR_RECEPCION','USR_ALOJAMIENTO','USR_GERENTE','USR_AUDITOR');

SELECT resource_name, limit
FROM dba_profiles
WHERE profile = 'PERFIL_RECEPCION'
ORDER BY resource_name;
