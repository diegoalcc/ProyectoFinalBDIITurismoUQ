-- =============================================================================
-- TURISMOUQ - SCRIPT DE PRUEBAS ENTREGA 2
-- Equipo: Sebastián Torres Morales · Jorge William Montoya Toro · Diego Alejandro Carvajal Camargo
--
-- Ejecutar DESPUÉS de toda la carga (00_EJECUTAR_TODO.sql completo).
-- Cada sección es independiente y tiene su propia verificación.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- PRUEBA 1: fn_valor_estadia — estadía que cruza temporadas
--
-- Escenario: buscar una habitación de hotel con tarifas configuradas,
-- calcular estadía del 18 al 26 de diciembre 2025.
-- Días 18-19-20-21-22-23 dic → temporada Baja/Media 2025 (hasta el 14 dic solo
-- hay baja tardía, del 15 en adelante es ALTA). Concretamente:
--   18-14 dic = BAJA tardía 2025  → hasta el 14 dic
--   15-26 dic = ALTA Diciembre 2025
-- La estadía 18–26 dic CRUZA de BAJA→ALTA el 15 dic... pero como empezamos el 18
-- ya estamos en ALTA. Usamos un rango más claro: 13-19 dic (cruce baja→alta el 15).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PRUEBA 1: fn_valor_estadia (cruce de temporadas)
--------------------------------------------------------------------------------

DECLARE
    -- Elegimos la primera habitación de hotel que tenga tarifas BAJA y ALTA 2025
    v_hab_id     NUMBER;
    v_valor_baja NUMBER(12,2);
    v_valor_alta NUMBER(12,2);
    v_valor_cruce NUMBER(12,2);

    v_precio_baja NUMBER(10,2);
    v_precio_alta NUMBER(10,2);
    v_esperado    NUMBER(12,2);

    -- Fechas que CRUZAN la frontera Baja→Alta 2025 (14 dic baja / 15 dic alta)
    v_fecha_in  DATE := DATE '2025-12-12';   -- 3 noches en Baja
    v_fecha_out DATE := DATE '2025-12-17';   -- 2 noches en Alta (15 y 16 dic)
    -- Total = 3 noches × precio_baja + 2 noches × precio_alta
BEGIN
    -- Buscar habitación con tarifas en ambas temporadas 2025
    SELECT tf_b.id_habitacion
    INTO   v_hab_id
    FROM   TARIFA   tf_b
    JOIN   TEMPORADA t_b ON t_b.id_temporada = tf_b.id_temporada
                        AND t_b.tipo_temporada = 'BAJA'
                        AND t_b.anio = 2025
    JOIN   TARIFA   tf_a ON tf_a.id_habitacion = tf_b.id_habitacion
    JOIN   TEMPORADA t_a ON t_a.id_temporada = tf_a.id_temporada
                        AND t_a.tipo_temporada = 'ALTA'
                        AND t_a.anio = 2025
                        AND t_a.fecha_inicio = DATE '2025-12-15'
    WHERE  ROWNUM = 1;

    -- Obtener los precios de cada temporada para esa habitación
    SELECT tf.precio_noche INTO v_precio_baja
    FROM   TARIFA tf JOIN TEMPORADA t ON t.id_temporada = tf.id_temporada
    WHERE  tf.id_habitacion = v_hab_id
      AND  t.tipo_temporada = 'BAJA' AND t.anio = 2025
      AND  ROWNUM = 1;

    SELECT tf.precio_noche INTO v_precio_alta
    FROM   TARIFA tf JOIN TEMPORADA t ON t.id_temporada = tf.id_temporada
    WHERE  tf.id_habitacion = v_hab_id
      AND  t.tipo_temporada = 'ALTA' AND t.fecha_inicio = DATE '2025-12-15'
      AND  ROWNUM = 1;

    -- Valor esperado: 3 noches baja + 2 noches alta
    v_esperado := (v_precio_baja * 3) + (v_precio_alta * 2);

    -- Llamar a la función
    v_valor_cruce := PKG_TURISMOUQ.fn_valor_estadia(v_hab_id, v_fecha_in, v_fecha_out);

    DBMS_OUTPUT.PUT_LINE('Habitación: '       || v_hab_id);
    DBMS_OUTPUT.PUT_LINE('Período: '          || TO_CHAR(v_fecha_in,'DD/MM/YYYY')
                                              || ' → ' || TO_CHAR(v_fecha_out,'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('Precio/noche BAJA:  $' || TO_CHAR(v_precio_baja,  'FM999,999,990'));
    DBMS_OUTPUT.PUT_LINE('Precio/noche ALTA:  $' || TO_CHAR(v_precio_alta,  'FM999,999,990'));
    DBMS_OUTPUT.PUT_LINE('Esperado (manual):  $' || TO_CHAR(v_esperado,     'FM999,999,990'));
    DBMS_OUTPUT.PUT_LINE('Función retornó:    $' || TO_CHAR(v_valor_cruce,  'FM999,999,990'));

    IF v_valor_cruce = v_esperado THEN
        DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: CORRECTO ✓');
    ELSE
        DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: ERROR ✗ (diferencia: '
                             || TO_CHAR(v_valor_cruce - v_esperado) || ')');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No se encontró habitación con tarifas en ambas temporadas 2025.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('EXCEPCIÓN: ' || SQLERRM);
END;
/

-- =============================================================================
-- PRUEBA 2: sp_crear_reserva — caso exitoso (1 habitación)
-- =============================================================================


DECLARE
    v_hab_id     NUMBER;
    v_id_reserva NUMBER;
    v_lineas     t_lista_lineas_habitacion;
    v_aloj_id    NUMBER;

    -- Buscar habitación disponible (sin reservas confirmadas en el rango de prueba)
    v_fin DATE := DATE '2027-06-10';
    v_fout DATE := DATE '2027-06-13';
BEGIN
    -- Habitación que NO tenga reservas confirmadas en esas fechas de prueba (futuro lejano)
    SELECT MIN(id_habitacion) INTO v_hab_id FROM HABITACION;

    v_lineas := t_lista_lineas_habitacion(
        t_linea_habitacion_reserva(v_hab_id, v_fin, v_fout, 2)
    );

    PKG_TURISMOUQ.sp_crear_reserva(
        p_id_cliente => 1,
        p_lineas     => v_lineas,
        p_estado     => 'CONFIRMADA',
        p_id_reserva => v_id_reserva
    );

    DBMS_OUTPUT.PUT_LINE('Reserva creada exitosamente. ID: ' || v_id_reserva);

    -- Verificar que se insertó
    SELECT COUNT(*) INTO v_aloj_id
    FROM   RESERVA_HABITACION
    WHERE  id_reserva = v_id_reserva;

    DBMS_OUTPUT.PUT_LINE('Líneas en RESERVA_HABITACION: ' || v_aloj_id);
    DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: ' || CASE WHEN v_aloj_id > 0 THEN 'CORRECTO ✓' ELSE 'ERROR ✗' END);

    ROLLBACK;  -- No contaminar datos de prueba
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('EXCEPCIÓN: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =============================================================================
-- PRUEBA 3: sp_crear_reserva — error checkout <= checkin
-- =============================================================================


DECLARE
    v_hab_id     NUMBER;
    v_id_reserva NUMBER;
    v_lineas     t_lista_lineas_habitacion;
BEGIN
    SELECT MIN(id_habitacion) INTO v_hab_id FROM HABITACION;

    v_lineas := t_lista_lineas_habitacion(
        t_linea_habitacion_reserva(v_hab_id, DATE '2027-06-15', DATE '2027-06-15', 1)
        -- checkout = checkin → debe fallar
    );

    PKG_TURISMOUQ.sp_crear_reserva(1, v_lineas, 'CONFIRMADA', v_id_reserva);

    DBMS_OUTPUT.PUT_LINE('>>> ERROR: debió lanzar excepción pero no lo hizo ✗');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20001 THEN
            DBMS_OUTPUT.PUT_LINE('Excepción capturada (-20001): ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: CORRECTO ✓');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Excepción inesperada (' || SQLCODE || '): ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- =============================================================================
-- PRUEBA 4: sp_crear_reserva — error capacidad excedida
-- =============================================================================


DECLARE
    v_hab_id     NUMBER;
    v_cap        NUMBER;
    v_id_reserva NUMBER;
    v_lineas     t_lista_lineas_habitacion;
BEGIN
    SELECT id_habitacion, capacidad INTO v_hab_id, v_cap
    FROM   HABITACION WHERE ROWNUM = 1;

    -- Pedir v_cap + 1 huéspedes (excede capacidad)
    v_lineas := t_lista_lineas_habitacion(
        t_linea_habitacion_reserva(v_hab_id, DATE '2027-07-01', DATE '2027-07-03', v_cap + 1)
    );

    PKG_TURISMOUQ.sp_crear_reserva(1, v_lineas, 'CONFIRMADA', v_id_reserva);

    DBMS_OUTPUT.PUT_LINE('>>> ERROR: debió lanzar excepción ✗');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20003 THEN
            DBMS_OUTPUT.PUT_LINE('Excepción capturada (-20003 capacidad): ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: CORRECTO ✓');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Excepción (' || SQLCODE || '): ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- =============================================================================
-- PRUEBA 5: sp_crear_reserva — habitaciones de distintos alojamientos (error)
-- =============================================================================

DECLARE
    v_hab1       NUMBER;
    v_hab2       NUMBER;
    v_id_reserva NUMBER;
    v_lineas     t_lista_lineas_habitacion;
BEGIN
    -- Habitación del alojamiento 1 y del alojamiento 2
    SELECT MIN(id_habitacion) INTO v_hab1 FROM HABITACION WHERE id_alojamiento = 1;
    SELECT MIN(id_habitacion) INTO v_hab2 FROM HABITACION WHERE id_alojamiento = 2;

    v_lineas := t_lista_lineas_habitacion(
        t_linea_habitacion_reserva(v_hab1, DATE '2027-08-01', DATE '2027-08-03', 1),
        t_linea_habitacion_reserva(v_hab2, DATE '2027-08-01', DATE '2027-08-03', 1)
    );

    PKG_TURISMOUQ.sp_crear_reserva(1, v_lineas, 'CONFIRMADA', v_id_reserva);

    DBMS_OUTPUT.PUT_LINE('>>> ERROR: debió lanzar excepción -20005 ✗');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20005 THEN
            DBMS_OUTPUT.PUT_LINE('Excepción capturada (-20005 alojamiento): ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: CORRECTO ✓');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Excepción (' || SQLCODE || '): ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- =============================================================================
-- PRUEBA 6: trigger trg_reshab_sin_solape — insertar solapamiento a mano
-- =============================================================================


DECLARE
    v_res1   NUMBER;
    v_res2   NUMBER;
    v_hab_id NUMBER;
BEGIN
    -- Buscar habitación con al menos una reserva CONFIRMADA
    SELECT rh.id_habitacion, rh.id_reserva
    INTO   v_hab_id, v_res1
    FROM   RESERVA_HABITACION rh
    JOIN   RESERVA r ON r.id_reserva = rh.id_reserva
    WHERE  r.estado = 'CONFIRMADA'
      AND  rh.fecha_checkin >= DATE '2026-01-01'
      AND  ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Habitación con reserva confirmada: ' || v_hab_id
                         || ' (reserva ' || v_res1 || ')');

    -- Crear reserva nueva CONFIRMADA solapada
    INSERT INTO RESERVA (id_cliente, fecha_reserva, fecha_checkin, fecha_checkout, estado)
    VALUES (2, SYSDATE, DATE '2027-12-01', DATE '2027-12-10', 'CONFIRMADA')
    RETURNING id_reserva INTO v_res2;

    -- Insertar línea solapada con la existente
    INSERT INTO RESERVA_HABITACION (
        id_reserva, id_habitacion,
        fecha_checkin, fecha_checkout,
        num_huespedes, precio_noche_contratado
    )
    SELECT v_res2, v_hab_id,
           DATE '2027-12-01', DATE '2027-12-10',
           1,
           (SELECT precio_noche FROM TARIFA tf
            JOIN TEMPORADA t ON t.id_temporada = tf.id_temporada
            WHERE tf.id_habitacion = v_hab_id
            FETCH FIRST 1 ROW ONLY)
    FROM   DUAL;

    -- Si llegamos aquí, el trigger no bloqueó (solo aplica si hay solapamiento real)
    DBMS_OUTPUT.PUT_LINE('Inserción OK (no había solapamiento en esas fechas futuras — esperado).');
    DBMS_OUTPUT.PUT_LINE('>>> Para probar solapamiento real, cambiar fechas a las de v_res1.');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20002 THEN
            DBMS_OUTPUT.PUT_LINE('Trigger bloqueó solapamiento (-20002): ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: CORRECTO ✓');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Excepción (' || SQLCODE || '): ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- Prueba directa de solapamiento (mismo rango que una reserva existente)
DECLARE
    v_res_nuevo   NUMBER;
    v_hab_id      NUMBER;
    v_chk_in      DATE;
    v_chk_out     DATE;
BEGIN
    -- Obtener una reserva CONFIRMADA existente y sus fechas
    SELECT rh.id_habitacion, rh.fecha_checkin, rh.fecha_checkout
    INTO   v_hab_id, v_chk_in, v_chk_out
    FROM   RESERVA_HABITACION rh
    JOIN   RESERVA r ON r.id_reserva = rh.id_reserva
    WHERE  r.estado = 'CONFIRMADA'
      AND  rh.fecha_checkout > SYSDATE
      AND  ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Intentando solapar habitación ' || v_hab_id
                         || ' del ' || TO_CHAR(v_chk_in,'DD/MM/YYYY')
                         || ' al ' || TO_CHAR(v_chk_out,'DD/MM/YYYY'));

    INSERT INTO RESERVA (id_cliente, fecha_reserva, fecha_checkin, fecha_checkout, estado)
    VALUES (3, SYSDATE, v_chk_in, v_chk_out, 'CONFIRMADA')
    RETURNING id_reserva INTO v_res_nuevo;

    INSERT INTO RESERVA_HABITACION (
        id_reserva, id_habitacion, fecha_checkin, fecha_checkout,
        num_huespedes, precio_noche_contratado
    ) VALUES (
        v_res_nuevo, v_hab_id, v_chk_in, v_chk_out, 1, 100000
    );

    DBMS_OUTPUT.PUT_LINE('>>> ERROR: el trigger debió bloquear el solapamiento ✗');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20002 THEN
            DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: CORRECTO — solapamiento bloqueado ✓ (' || SQLERRM || ')');
        ELSIF SQLCODE = -20004 THEN
            DBMS_OUTPUT.PUT_LINE('>>> Bloqueado por fechas inválidas (-20004): ' || SQLERRM);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Excepción (' || SQLCODE || '): ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- =============================================================================
-- PRUEBA 7: trigger trg_tarifa_auditoria — INSERT y UPDATE en TARIFA
-- =============================================================================

DECLARE
    v_hab_id  NUMBER;
    v_temp_id NUMBER;
    v_tarifa_id NUMBER;
    v_count_antes NUMBER;
    v_count_despues NUMBER;
BEGIN
    -- Contar auditorías antes
    SELECT COUNT(*) INTO v_count_antes FROM AUDITORIA_TARIFA;

    -- Habitación y temporada de prueba (usar datos reales)
    SELECT MIN(id_habitacion) INTO v_hab_id FROM HABITACION;
    SELECT MIN(id_temporada) INTO v_temp_id FROM TEMPORADA WHERE anio = 2026;

    -- UPDATE de tarifa existente
    UPDATE TARIFA
    SET    precio_noche = precio_noche * 1.10   -- subir 10%
    WHERE  id_habitacion = v_hab_id
      AND  id_temporada  = v_temp_id
    RETURNING id_tarifa INTO v_tarifa_id;

    -- Contar auditorías después
    SELECT COUNT(*) INTO v_count_despues FROM AUDITORIA_TARIFA;

    DBMS_OUTPUT.PUT_LINE('Registros en AUDITORIA_TARIFA antes:  ' || v_count_antes);
    DBMS_OUTPUT.PUT_LINE('Registros en AUDITORIA_TARIFA después: ' || v_count_despues);
    DBMS_OUTPUT.PUT_LINE('Nuevos registros de auditoría: ' || (v_count_despues - v_count_antes));

    -- Mostrar el registro de auditoría reciente
    FOR rec IN (
        SELECT usuario_bd, tipo_operacion, precio_anterior, precio_nuevo, fecha_evento
        FROM   AUDITORIA_TARIFA
        WHERE  id_tarifa = v_tarifa_id
        ORDER BY fecha_evento DESC
        FETCH FIRST 3 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            'Auditoría: usuario=' || rec.usuario_bd
            || ' op=' || rec.tipo_operacion
            || ' anterior=$' || NVL(TO_CHAR(rec.precio_anterior),'NULL')
            || ' nuevo=$' || NVL(TO_CHAR(rec.precio_nuevo),'NULL')
        );
    END LOOP;

    IF v_count_despues > v_count_antes THEN
        DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: CORRECTO ✓');
    ELSE
        DBMS_OUTPUT.PUT_LINE('>>> RESULTADO: ERROR — no se registró auditoría ✗');
    END IF;

    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('EXCEPCIÓN: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =============================================================================
-- PRUEBA 8: cursor de liquidación mensual
-- =============================================================================

EXEC PKG_TURISMOUQ.sp_liquidacion_mensual_alojamiento(4, 2025);



-- Probar con mes sin actividad
EXEC PKG_TURISMOUQ.sp_liquidacion_mensual_alojamiento(2, 2099);


-- =============================================================================
-- PRUEBA 9: Verificar volúmenes mínimos del enunciado
-- =============================================================================


SELECT
    'HABITACION ≥ 400'          AS criterio,
    (SELECT COUNT(*) FROM HABITACION)         AS actual,
    CASE WHEN (SELECT COUNT(*) FROM HABITACION) >= 400
         THEN 'CUMPLE ✓' ELSE 'NO CUMPLE ✗' END AS estado
FROM DUAL
UNION ALL
SELECT 'CLIENTE ≥ 3000',
    (SELECT COUNT(*) FROM CLIENTE),
    CASE WHEN (SELECT COUNT(*) FROM CLIENTE) >= 3000 THEN 'CUMPLE ✓' ELSE 'NO CUMPLE ✗' END
FROM DUAL
UNION ALL
SELECT 'RESERVA ≥ 25000',
    (SELECT COUNT(*) FROM RESERVA),
    CASE WHEN (SELECT COUNT(*) FROM RESERVA) >= 25000 THEN 'CUMPLE ✓' ELSE 'NO CUMPLE ✗' END
FROM DUAL
UNION ALL
SELECT 'RESERVA_HABITACION ≥ 25000',
    (SELECT COUNT(*) FROM RESERVA_HABITACION),
    CASE WHEN (SELECT COUNT(*) FROM RESERVA_HABITACION) >= 25000 THEN 'CUMPLE ✓' ELSE 'NO CUMPLE ✗' END
FROM DUAL
UNION ALL
SELECT 'PAGO ≥ 25000',
    (SELECT COUNT(*) FROM PAGO),
    CASE WHEN (SELECT COUNT(*) FROM PAGO) >= 25000 THEN 'CUMPLE ✓' ELSE 'NO CUMPLE ✗' END
FROM DUAL
UNION ALL
SELECT 'RESERVA_SERVICIO ≥ 40000',
    (SELECT COUNT(*) FROM RESERVA_SERVICIO),
    CASE WHEN (SELECT COUNT(*) FROM RESERVA_SERVICIO) >= 40000 THEN 'CUMPLE ✓' ELSE 'NO CUMPLE ✗' END
FROM DUAL
UNION ALL
SELECT '% RESENAS ≥ 40% completadas',
    ROUND(
        (SELECT COUNT(*) FROM RESENA) * 100.0
        / NULLIF((SELECT COUNT(*) FROM RESERVA WHERE estado = 'COMPLETADA'), 0), 1
    ),
    CASE WHEN
        (SELECT COUNT(*) FROM RESENA) * 100.0
        / NULLIF((SELECT COUNT(*) FROM RESERVA WHERE estado = 'COMPLETADA'), 0) >= 40
        THEN 'CUMPLE ✓' ELSE 'NO CUMPLE ✗' END
FROM DUAL;

-- =============================================================================
-- PRUEBA 10: Vista materializada
-- =============================================================================


SELECT municipio, anio, mes,
       total_noches, habitaciones_ocupadas, total_reservas,
       TO_CHAR(ingreso_estimado, 'FM$999,999,999,990') AS ingreso_est
FROM   MV_OCUPACION_MENSUAL_MUNICIPIO
WHERE  anio = 2025
ORDER BY anio_mes, municipio
FETCH FIRST 24 ROWS ONLY;


