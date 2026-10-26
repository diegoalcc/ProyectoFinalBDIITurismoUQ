-- =============================================================================
-- TURISMOUQ - DISPARADORES
-- Equipo: Sebastián Torres Morales · Jorge William Montoya Toro · Diego Alejandro Carvajal Camargo
--
-- CONTENIDO:
--   A) Auditoría de TARIFA  → disparador compuesto (compound trigger)
--   B) Anti-solapamiento en RESERVA_HABITACION → compound trigger
--
-- ORDEN DE EJECUCIÓN: DESPUÉS de la carga  (05_Carga_Datos.sql).
-- Los triggers se activan solo para operaciones POST-carga.
-- =============================================================================

CREATE OR REPLACE TRIGGER trg_tarifa_auditoria
FOR INSERT OR UPDATE OR DELETE ON TARIFA
COMPOUND TRIGGER

    -- Tipo colección para acumular filas durante la sentencia
    TYPE t_fila_aud IS RECORD (
        id_tarifa       NUMBER(10),
        id_habitacion   NUMBER(10),
        id_temporada    NUMBER(6),
        precio_anterior NUMBER(10,2),
        precio_nuevo    NUMBER(10,2),
        tipo_operacion  VARCHAR2(10)
    );
    TYPE t_tabla_aud IS TABLE OF t_fila_aud INDEX BY PLS_INTEGER;

    g_filas   t_tabla_aud;   -- colección en memoria (nivel de sentencia)
    g_idx     PLS_INTEGER := 0;

    -- -------------------------------------------------------------------------
    -- AFTER EACH ROW: captura los valores OLD/NEW de cada fila modificada
    -- -------------------------------------------------------------------------
    AFTER EACH ROW IS
        v_rec t_fila_aud;
    BEGIN
        g_idx := g_idx + 1;

        IF INSERTING THEN
            v_rec.id_tarifa       := :NEW.id_tarifa;
            v_rec.id_habitacion   := :NEW.id_habitacion;
            v_rec.id_temporada    := :NEW.id_temporada;
            v_rec.precio_anterior := NULL;
            v_rec.precio_nuevo    := :NEW.precio_noche;
            v_rec.tipo_operacion  := 'INSERT';

        ELSIF UPDATING THEN
            v_rec.id_tarifa       := :NEW.id_tarifa;
            v_rec.id_habitacion   := :NEW.id_habitacion;
            v_rec.id_temporada    := :NEW.id_temporada;
            v_rec.precio_anterior := :OLD.precio_noche;
            v_rec.precio_nuevo    := :NEW.precio_noche;
            v_rec.tipo_operacion  := 'UPDATE';

        ELSE  -- DELETING
            v_rec.id_tarifa       := :OLD.id_tarifa;
            v_rec.id_habitacion   := :OLD.id_habitacion;
            v_rec.id_temporada    := :OLD.id_temporada;
            v_rec.precio_anterior := :OLD.precio_noche;
            v_rec.precio_nuevo    := NULL;
            v_rec.tipo_operacion  := 'DELETE';
        END IF;

        g_filas(g_idx) := v_rec;
    END AFTER EACH ROW;

    -- -------------------------------------------------------------------------
    -- AFTER STATEMENT: vuelca la colección a la tabla de auditoría
    -- Se ejecuta UNA SOLA VEZ por sentencia, sin importar cuántas filas afectó.
    -- -------------------------------------------------------------------------
    AFTER STATEMENT IS
    BEGIN
        IF g_filas.COUNT > 0 THEN
            FOR i IN 1 .. g_filas.COUNT LOOP
                INSERT INTO AUDITORIA_TARIFA (
                    usuario_bd,
                    tipo_operacion,
                    id_tarifa,
                    id_habitacion,
                    id_temporada,
                    precio_anterior,
                    precio_nuevo
                ) VALUES (
                    USER,
                    g_filas(i).tipo_operacion,
                    g_filas(i).id_tarifa,
                    g_filas(i).id_habitacion,
                    g_filas(i).id_temporada,
                    g_filas(i).precio_anterior,
                    g_filas(i).precio_nuevo
                );
            END LOOP;
            -- Vaciar colección para la próxima sentencia
            g_filas.DELETE;
            g_idx := 0;
        END IF;
    END AFTER STATEMENT;

END trg_tarifa_auditoria;
/

PROMPT Disparador trg_tarifa_auditoria creado (compound trigger: AFTER EACH ROW + AFTER STATEMENT).

-- =============================================================================
-- SECCIÓN B: ANTI-SOLAPAMIENTO EN RESERVA_HABITACION
-- =============================================================================

CREATE OR REPLACE TRIGGER trg_reshab_sin_solape
FOR INSERT OR UPDATE ON RESERVA_HABITACION
COMPOUND TRIGGER

    -- Colección de filas a validar
    TYPE t_fila_reshab IS RECORD (
        id_reserva_habitacion NUMBER(10),
        id_reserva            NUMBER(10),
        id_habitacion         NUMBER(10),
        fecha_checkin         DATE,
        fecha_checkout        DATE
    );
    TYPE t_tabla_reshab IS TABLE OF t_fila_reshab INDEX BY PLS_INTEGER;

    g_filas t_tabla_reshab;
    g_idx   PLS_INTEGER := 0;

    -- -------------------------------------------------------------------------
    -- BEFORE EACH ROW: validaciones inmediatas (fechas) y captura para solapamiento
    -- -------------------------------------------------------------------------
    BEFORE EACH ROW IS
    BEGIN
        -- Validar fechas de la propia línea (no requiere leer otras tablas)
        IF :NEW.fecha_checkout <= :NEW.fecha_checkin THEN
            RAISE_APPLICATION_ERROR(
                -20004,
                'Checkout (' || TO_CHAR(:NEW.fecha_checkout,'DD/MM/YYYY')
                || ') debe ser posterior al check-in ('
                || TO_CHAR(:NEW.fecha_checkin,'DD/MM/YYYY') || ').'
            );
        END IF;

        -- Acumular solo si la reserva padre es activa (CONFIRMADA o COMPLETADA)
        -- Nota: leemos RESERVA con SELECT puntual — no es la tabla en mutación.
        DECLARE
            v_estado VARCHAR2(15);
        BEGIN
            SELECT estado INTO v_estado
            FROM   RESERVA
            WHERE  id_reserva = :NEW.id_reserva;

            IF v_estado IN ('CONFIRMADA', 'COMPLETADA') THEN
                g_idx := g_idx + 1;
                g_filas(g_idx).id_reserva_habitacion :=
                    NVL(:NEW.id_reserva_habitacion, -1);
                g_filas(g_idx).id_reserva    := :NEW.id_reserva;
                g_filas(g_idx).id_habitacion := :NEW.id_habitacion;
                g_filas(g_idx).fecha_checkin  := :NEW.fecha_checkin;
                g_filas(g_idx).fecha_checkout := :NEW.fecha_checkout;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN NULL;  -- Reserva padre no existe aún (se manejará por FK)
        END;
    END BEFORE EACH ROW;

    -- -------------------------------------------------------------------------
    -- AFTER STATEMENT: verifica solapamientos contra datos ya confirmados
    -- La tabla ya no está mutando → SELECT seguro.
    -- -------------------------------------------------------------------------
    AFTER STATEMENT IS
        v_solapa NUMBER;
    BEGIN
        FOR i IN 1 .. g_filas.COUNT LOOP
            SELECT COUNT(*)
            INTO   v_solapa
            FROM   RESERVA_HABITACION  rh
            JOIN   RESERVA             r  ON r.id_reserva = rh.id_reserva
            WHERE  rh.id_habitacion = g_filas(i).id_habitacion
              AND  r.estado IN ('CONFIRMADA', 'COMPLETADA')
              -- Excluir la propia línea en caso de UPDATE
              AND  rh.id_reserva_habitacion <> g_filas(i).id_reserva_habitacion
              -- Condición de solapamiento
              AND  NOT (
                       rh.fecha_checkout <= g_filas(i).fecha_checkin
                    OR rh.fecha_checkin  >= g_filas(i).fecha_checkout
                   );

            IF v_solapa > 0 THEN
                g_filas.DELETE;
                g_idx := 0;
                RAISE_APPLICATION_ERROR(
                    -20002,
                    'Solapamiento detectado: la habitación '
                    || g_filas(i).id_habitacion
                    || ' ya tiene una reserva confirmada que se superpone con el rango '
                    || TO_CHAR(g_filas(i).fecha_checkin,  'DD/MM/YYYY') || ' – '
                    || TO_CHAR(g_filas(i).fecha_checkout, 'DD/MM/YYYY') || '.'
                );
            END IF;
        END LOOP;

        -- Vaciar colección
        g_filas.DELETE;
        g_idx := 0;
    END AFTER STATEMENT;

END trg_reshab_sin_solape;
/

PROMPT Disparador trg_reshab_sin_solape creado (compound trigger: resuelve mutating table).

-- =============================================================================
-- VERIFICACIÓN RÁPIDA
-- =============================================================================
SELECT trigger_name, trigger_type, status
FROM   user_triggers
WHERE  trigger_name IN ('TRG_TARIFA_AUDITORIA', 'TRG_RESHAB_SIN_SOLAPE');


