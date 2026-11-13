-- =============================================================================
-- TURISMOUQ - ENTREGA 3
-- Script 09: Transacciones atómicas con SAVEPOINT y ROLLBACK parcial
-- Equipo: Sebastián Torres Morales · Jorge William Montoya Toro
--         Diego Alejandro Carvajal Camargo
-- Universidad del Quindío · BD II 2026-2
--
-- Ejecutar como usuario turismouq en XEPDB1
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- PARTE 1: PROCEDIMIENTO ATÓMICO  sp_reserva_y_pago
--
-- Registra una reserva completa (encabezado + habitaciones) y su primer pago
-- en una sola transacción.  Usa dos SAVEPOINTs para permitir rollback parcial:
--
--   sp_antes_reserva  → punto seguro antes de crear la reserva
--   sp_antes_pago     → punto seguro después de crear la reserva, antes del pago
--
-- Si el pago falla (monto negativo, método inválido, etc.) se hace ROLLBACK al
-- sp_antes_pago: la reserva queda creada pero sin pago registrado.
-- Si la reserva misma falla, se hace ROLLBACK total al sp_antes_reserva.
-- =============================================================================

CREATE OR REPLACE PROCEDURE sp_reserva_y_pago (
    p_id_cliente     IN  NUMBER,
    p_lineas         IN  t_lista_lineas_habitacion,
    p_monto_pago     IN  NUMBER,
    p_metodo_pago    IN  VARCHAR2,
    p_id_reserva     OUT NUMBER,
    p_id_pago        OUT NUMBER,
    p_estado_pago    OUT VARCHAR2
) AS
    v_id_reserva  NUMBER;
    v_id_pago     NUMBER;
BEGIN
    -- -------------------------------------------------------------------------
    -- SAVEPOINT 1: punto de retorno si falla la creación de la reserva
    -- -------------------------------------------------------------------------
    SAVEPOINT sp_antes_reserva;

    PKG_TURISMOUQ.sp_crear_reserva(
        p_id_cliente => p_id_cliente,
        p_lineas     => p_lineas,
        p_estado     => 'CONFIRMADA',
        p_id_reserva => v_id_reserva
    );

    DBMS_OUTPUT.PUT_LINE('[OK] Reserva creada con ID = ' || v_id_reserva);

    -- -------------------------------------------------------------------------
    -- SAVEPOINT 2: la reserva existe; punto de retorno si falla el pago
    -- -------------------------------------------------------------------------
    SAVEPOINT sp_antes_pago;

    -- Validar método de pago antes del INSERT
    -- (la columna de la tabla se llama "metodo", no "metodo_pago")
    IF p_metodo_pago NOT IN ('PSE','TARJETA_CREDITO','TARJETA_DEBITO',
                              'TRANSFERENCIA','EFECTIVO') THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Método de pago inválido: ' || p_metodo_pago);
    END IF;

    -- Validar monto (el CHECK de la tabla ya lo hace, pero lo anticipamos)
    IF p_monto_pago <= 0 THEN
        RAISE_APPLICATION_ERROR(-20011,
            'El monto debe ser mayor que cero. Recibido: ' || p_monto_pago);
    END IF;

    -- Registrar el pago — columna "metodo" según DDL de PAGO
    INSERT INTO PAGO (id_reserva, fecha_pago, monto, metodo, estado)
    VALUES (v_id_reserva, SYSDATE, p_monto_pago, p_metodo_pago, 'EXITOSO')
    RETURNING id_pago INTO v_id_pago;

    DBMS_OUTPUT.PUT_LINE('[OK] Pago registrado con ID = ' || v_id_pago
        || '  Monto = $' || TO_CHAR(p_monto_pago, 'FM999,999,990'));

    p_id_reserva  := v_id_reserva;
    p_id_pago     := v_id_pago;
    p_estado_pago := 'EXITOSO';

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[COMMIT] Reserva + pago confirmados.');

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE IN (-20010, -20011) THEN
            -- Solo el pago falló: rollback al segundo savepoint
            ROLLBACK TO SAVEPOINT sp_antes_pago;
            p_id_reserva  := v_id_reserva;
            p_id_pago     := NULL;
            p_estado_pago := 'PAGO_FALLIDO';
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('[ROLLBACK PARCIAL] Pago deshecho. '
                || 'Reserva ' || v_id_reserva || ' persiste sin pago.');
            DBMS_OUTPUT.PUT_LINE('[CAUSA] ' || SQLERRM);
        ELSE
            -- La reserva misma falló: rollback total
            ROLLBACK TO SAVEPOINT sp_antes_reserva;
            p_id_reserva  := NULL;
            p_id_pago     := NULL;
            p_estado_pago := 'RESERVA_FALLIDA';
            DBMS_OUTPUT.PUT_LINE('[ROLLBACK TOTAL] Todo deshecho (reserva + pago).');
            DBMS_OUTPUT.PUT_LINE('[CAUSA] ' || SQLERRM);
            RAISE;
        END IF;
END sp_reserva_y_pago;
/

-- =============================================================================
-- PARTE 2: DEMOSTRACIÓN DE LOS TRES ESCENARIOS
--
-- A) Caso exitoso:    reserva + pago correctos      → COMMIT completo
-- B) Rollback parcial: pago con monto negativo      → reserva queda, pago no
-- C) Rollback total:   habitación inexistente       → se deshace todo
--
-- NOTA: los subSELECTs como argumentos de procedimiento no son válidos en
-- PL/SQL. Se resuelven en variables locales antes de la llamada.
-- =============================================================================

-- -------------------------------------------------------
-- ESCENARIO A: Reserva + pago exitosos → COMMIT completo
-- -------------------------------------------------------
DECLARE
    v_id_reserva  NUMBER;
    v_id_pago     NUMBER;
    v_estado      VARCHAR2(30);
    v_lineas      t_lista_lineas_habitacion;
    v_id_hab      NUMBER;
    v_id_cli      NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=================================================');
    DBMS_OUTPUT.PUT_LINE(' ESCENARIO A: Reserva + pago exitosos (COMMIT)');
    DBMS_OUTPUT.PUT_LINE('=================================================');

    -- Resolver IDs en variables (PL/SQL no admite SELECT anidado en argumentos)
    SELECT MIN(id_habitacion) INTO v_id_hab FROM HABITACION;
    SELECT MIN(id_cliente)    INTO v_id_cli FROM CLIENTE;

    v_lineas := t_lista_lineas_habitacion(
        t_linea_habitacion_reserva(
            v_id_hab,
            TRUNC(SYSDATE) + 15,
            TRUNC(SYSDATE) + 18,
            2
        )
    );

    sp_reserva_y_pago(
        p_id_cliente  => v_id_cli,
        p_lineas      => v_lineas,
        p_monto_pago  => 350000,
        p_metodo_pago => 'PSE',
        p_id_reserva  => v_id_reserva,
        p_id_pago     => v_id_pago,
        p_estado_pago => v_estado
    );

    DBMS_OUTPUT.PUT_LINE('Resultado: reserva=' || v_id_reserva
        || ', pago=' || v_id_pago || ', estado=' || v_estado);
END;
/

-- -----------------------------------------------------------------
-- ESCENARIO B: Monto negativo → rollback PARCIAL (reserva persiste)
-- -----------------------------------------------------------------
DECLARE
    v_id_reserva  NUMBER;
    v_id_pago     NUMBER;
    v_estado      VARCHAR2(30);
    v_lineas      t_lista_lineas_habitacion;
    v_id_hab      NUMBER;
    v_id_cli      NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=================================================');
    DBMS_OUTPUT.PUT_LINE(' ESCENARIO B: Rollback PARCIAL (monto negativo)');
    DBMS_OUTPUT.PUT_LINE(' La reserva se crea; el pago se deshace.');
    DBMS_OUTPUT.PUT_LINE('=================================================');

    SELECT MIN(id_habitacion) INTO v_id_hab FROM HABITACION;
    SELECT MIN(id_cliente)    INTO v_id_cli FROM CLIENTE;

    v_lineas := t_lista_lineas_habitacion(
        t_linea_habitacion_reserva(
            v_id_hab,
            TRUNC(SYSDATE) + 20,
            TRUNC(SYSDATE) + 23,
            1
        )
    );

    sp_reserva_y_pago(
        p_id_cliente  => v_id_cli,
        p_lineas      => v_lineas,
        p_monto_pago  => -1,          -- fuerza RAISE_APPLICATION_ERROR(-20011,...)
        p_metodo_pago => 'EFECTIVO',
        p_id_reserva  => v_id_reserva,
        p_id_pago     => v_id_pago,
        p_estado_pago => v_estado
    );

    DBMS_OUTPUT.PUT_LINE('Resultado: reserva=' || NVL(TO_CHAR(v_id_reserva),'NULL')
        || ', pago=' || NVL(TO_CHAR(v_id_pago),'NULL')
        || ', estado=' || v_estado);
END;
/

-- -------------------------------------------------------------------
-- ESCENARIO C: Habitación inexistente → rollback TOTAL (nada persiste)
-- -------------------------------------------------------------------
DECLARE
    v_id_reserva  NUMBER;
    v_id_pago     NUMBER;
    v_estado      VARCHAR2(30);
    v_lineas      t_lista_lineas_habitacion;
    v_id_cli      NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=================================================');
    DBMS_OUTPUT.PUT_LINE(' ESCENARIO C: Rollback TOTAL (habitación inexistente)');
    DBMS_OUTPUT.PUT_LINE(' No se crea nada en la BD.');
    DBMS_OUTPUT.PUT_LINE('=================================================');

    SELECT MIN(id_cliente) INTO v_id_cli FROM CLIENTE;

    v_lineas := t_lista_lineas_habitacion(
        t_linea_habitacion_reserva(
            999999999,              -- ID inexistente → error en sp_crear_reserva
            TRUNC(SYSDATE) + 5,
            TRUNC(SYSDATE) + 8,
            2
        )
    );

    BEGIN
        sp_reserva_y_pago(
            p_id_cliente  => v_id_cli,
            p_lineas      => v_lineas,
            p_monto_pago  => 200000,
            p_metodo_pago => 'TRANSFERENCIA',
            p_id_reserva  => v_id_reserva,
            p_id_pago     => v_id_pago,
            p_estado_pago => v_estado
        );
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[EXCEPCIÓN EN LLAMADOR] ' || SQLERRM);
    END;

    DBMS_OUTPUT.PUT_LINE('Resultado: reserva=' || NVL(TO_CHAR(v_id_reserva),'NULL')
        || ', pago=' || NVL(TO_CHAR(v_id_pago),'NULL')
        || ', estado=' || NVL(v_estado,'NULL'));
END;
/

-- =============================================================================
-- PARTE 3: VERIFICACIÓN — qué quedó realmente persistido hoy
-- =============================================================================
SELECT
    'RESERVA'              AS entidad,
    r.id_reserva           AS id,
    r.estado,
    TO_CHAR(r.fecha_registro, 'DD/MM/YYYY HH24:MI:SS') AS fecha,
    TO_CHAR(NULL)          AS metodo,
    TO_NUMBER(NULL)        AS monto
FROM RESERVA r
WHERE r.fecha_registro >= TRUNC(SYSDATE)
UNION ALL
SELECT
    'PAGO'                 AS entidad,
    p.id_pago              AS id,
    p.estado,
    TO_CHAR(p.fecha_pago, 'DD/MM/YYYY HH24:MI:SS') AS fecha,
    p.metodo,
    p.monto
FROM PAGO p
WHERE p.id_reserva IN (
    SELECT id_reserva FROM RESERVA
    WHERE fecha_registro >= TRUNC(SYSDATE)
)
ORDER BY entidad DESC, id;
