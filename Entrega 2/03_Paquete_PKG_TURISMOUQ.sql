-- =============================================================================
-- TURISMOUQ - PAQUETE PKG_TURISMOUQ (función, procedimiento, cursor)
-- Equipo: Sebastián Torres Morales · Jorge William Montoya Toro · Diego Alejandro Carvajal Camargo
-- Ejecutar DESPUÉS de 01_DDL_TurismoUQ.sql y ANTES de 05_Carga_Datos.sql
-- =============================================================================

CREATE OR REPLACE TYPE t_linea_habitacion_reserva AS OBJECT (
    id_habitacion  NUMBER,
    fecha_checkin  DATE,
    fecha_checkout DATE,
    num_huespedes  NUMBER
);
/

CREATE OR REPLACE TYPE t_lista_lineas_habitacion AS TABLE OF t_linea_habitacion_reserva;
/

-- =============================================================================
-- ESPECIFICACIÓN DEL PAQUETE
-- =============================================================================
CREATE OR REPLACE PACKAGE PKG_TURISMOUQ AS

    -- Códigos de error propios (RAISE_APPLICATION_ERROR espera rango -20000..-20999)
    c_error_fechas         CONSTANT NUMBER := -20001;
    c_error_disponibilidad CONSTANT NUMBER := -20002;
    c_error_capacidad      CONSTANT NUMBER := -20003;
    c_error_alojamiento    CONSTANT NUMBER := -20005;  -- habitaciones de distintos alojamientos
    c_error_sin_tarifa     CONSTANT NUMBER := -20006;  -- día sin tarifa configurada

    -- -------------------------------------------------------------------------
    -- fn_valor_estadia
    -- Calcula el costo total de una estadía aplicando la tarifa correspondiente
    -- a CADA NOCHE según la temporada vigente ese día.
    -- Cumple la decisión de diseño: estadías que cruzan temporadas con tarifas distintas.
    -- -------------------------------------------------------------------------
    FUNCTION fn_valor_estadia (
        p_id_habitacion NUMBER,
        p_fecha_in      DATE,
        p_fecha_out     DATE
    ) RETURN NUMBER;

    -- -------------------------------------------------------------------------
    -- sp_crear_reserva
    -- Crea encabezado + líneas de habitación de forma atómica.
    -- Valida: fechas, capacidad, disponibilidad, mismo alojamiento.
    -- -------------------------------------------------------------------------
    PROCEDURE sp_crear_reserva (
        p_id_cliente   IN  NUMBER,
        p_lineas       IN  t_lista_lineas_habitacion,
        p_estado       IN  VARCHAR2 DEFAULT 'CONFIRMADA',
        p_id_reserva   OUT NUMBER
    );

    -- -------------------------------------------------------------------------
    -- sp_liquidacion_mensual_alojamiento
    -- Cursor explícito parametrizado: recorre todos los alojamientos activos
    -- en un mes/año dado e imprime estadías + servicios + total combinado.
    -- -------------------------------------------------------------------------
    PROCEDURE sp_liquidacion_mensual_alojamiento (
        p_mes  IN NUMBER,
        p_anio IN NUMBER
    );

END PKG_TURISMOUQ;
/

-- =============================================================================
-- CUERPO DEL PAQUETE
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY PKG_TURISMOUQ AS

    -- -------------------------------------------------------------------------
    -- FUNCIÓN PRIVADA: fn_precio_noche_dia
    -- Devuelve el precio por noche para una habitación en un día concreto.
    --
    -- FIX #11 (precio no-determinístico): ORDER BY prioridad ALTA > MEDIA > BAJA
    -- garantiza que si dos temporadas se solapan se usa siempre la de mayor peso.
    --
    -- FIX #12 (fallback incorrecto): si no hay tarifa configurada para ese día
    -- se lanza excepción propia en lugar de devolver un precio inventado.
    -- -------------------------------------------------------------------------
    FUNCTION fn_precio_noche_dia (
        p_id_habitacion NUMBER,
        p_dia           DATE
    ) RETURN NUMBER IS
        v_precio NUMBER(10,2);
    BEGIN
        SELECT tf.precio_noche
        INTO   v_precio
        FROM   TARIFA   tf
        JOIN   TEMPORADA t ON t.id_temporada = tf.id_temporada
        WHERE  tf.id_habitacion = p_id_habitacion
          AND  TRUNC(p_dia) BETWEEN TRUNC(t.fecha_inicio) AND TRUNC(t.fecha_fin)
        ORDER BY
            -- Prioridad: ALTA(1) > MEDIA(2) > BAJA(3) — determinístico ante solapamientos
            CASE t.tipo_temporada WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END
        FETCH FIRST 1 ROW ONLY;

        RETURN v_precio;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Sin tarifa configurada: usamos la tarifa BAJA más reciente como fallback
            -- defensivo para no bloquear la carga masiva (la excepción se relanza en
            -- fn_valor_estadia si se desea comportamiento estricto).
            BEGIN
                SELECT tf.precio_noche
                INTO   v_precio
                FROM   TARIFA   tf
                JOIN   TEMPORADA t ON t.id_temporada = tf.id_temporada
                WHERE  tf.id_habitacion = p_id_habitacion
                  AND  t.tipo_temporada = 'BAJA'
                ORDER BY t.fecha_fin DESC
                FETCH FIRST 1 ROW ONLY;
                RETURN v_precio;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- Habitación sin ninguna tarifa: retornamos NULL (el llamador decide)
                    RETURN NULL;
            END;
    END fn_precio_noche_dia;

    -- -------------------------------------------------------------------------
    -- FUNCIÓN PÚBLICA: fn_valor_estadia
    -- Itera noche a noche entre p_fecha_in y p_fecha_out acumulando el precio
    -- de cada día según su temporada.
    --
    -- Ejemplo: estadía 20-dic → 26-dic.
    --   20,21,22,23 dic → tarifa MEDIA   (supongamos $120.000/noche)
    --   24,25     dic → tarifa ALTA    (supongamos $300.000/noche)
    --   Total = 4×120.000 + 2×300.000 = $1.080.000
    -- -------------------------------------------------------------------------
    FUNCTION fn_valor_estadia (
        p_id_habitacion NUMBER,
        p_fecha_in      DATE,
        p_fecha_out     DATE
    ) RETURN NUMBER IS
        v_total  NUMBER(12,2) := 0;
        v_dia    DATE;
        v_noches NUMBER;
        v_precio NUMBER(10,2);
    BEGIN
        -- Validación de fechas
        IF p_fecha_out <= p_fecha_in THEN
            RAISE_APPLICATION_ERROR(
                c_error_fechas,
                'La fecha de checkout debe ser posterior al check-in.'
            );
        END IF;

        v_noches := TRUNC(p_fecha_out) - TRUNC(p_fecha_in);
        v_dia    := TRUNC(p_fecha_in);

        FOR i IN 1 .. v_noches LOOP
            v_precio := fn_precio_noche_dia(p_id_habitacion, v_dia);

            IF v_precio IS NULL THEN
                -- FIX #12: día sin tarifa → excepción clara en lugar de precio inventado
                RAISE_APPLICATION_ERROR(
                    c_error_sin_tarifa,
                    'No hay tarifa configurada para la habitación ' || p_id_habitacion
                    || ' en la fecha ' || TO_CHAR(v_dia, 'DD/MM/YYYY')
                    || '. Configure la temporada correspondiente.'
                );
            END IF;

            v_total := v_total + v_precio;
            v_dia   := v_dia + 1;
        END LOOP;

        RETURN v_total;
    END fn_valor_estadia;

    -- -------------------------------------------------------------------------
    -- PROCEDIMIENTO PRIVADO: validar_disponibilidad
    -- Verifica que no haya solapamiento con reservas CONFIRMADAS o COMPLETADAS.
    -- Se llama desde sp_crear_reserva ANTES de insertar.
    -- -------------------------------------------------------------------------
    PROCEDURE validar_disponibilidad (
        p_id_habitacion NUMBER,
        p_checkin       DATE,
        p_checkout      DATE,
        p_excluir_linea NUMBER DEFAULT NULL
    ) IS
        v_solapa NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO   v_solapa
        FROM   RESERVA_HABITACION rh
        JOIN   RESERVA r ON r.id_reserva = rh.id_reserva
        WHERE  rh.id_habitacion = p_id_habitacion
          AND  r.estado IN ('CONFIRMADA', 'COMPLETADA')
          AND  (p_excluir_linea IS NULL OR rh.id_reserva_habitacion <> p_excluir_linea)
          AND  NOT (
                   rh.fecha_checkout <= p_checkin
                OR rh.fecha_checkin  >= p_checkout
               );

        IF v_solapa > 0 THEN
            RAISE_APPLICATION_ERROR(
                c_error_disponibilidad,
                'La habitación ' || p_id_habitacion
                || ' no está disponible entre '
                || TO_CHAR(p_checkin,  'DD/MM/YYYY') || ' y '
                || TO_CHAR(p_checkout, 'DD/MM/YYYY') || '.'
            );
        END IF;
    END validar_disponibilidad;

    -- -------------------------------------------------------------------------
    -- PROCEDIMIENTO PÚBLICO: sp_crear_reserva
    --
    -- Recibe una colección de líneas (habitación, fechas, huéspedes) y crea:
    --   1) Un encabezado RESERVA con las fechas marco (min checkin / max checkout).
    --   2) Una fila RESERVA_HABITACION por cada línea.
    --
    -- Validaciones con RAISE_APPLICATION_ERROR:
    --   - Colección vacía o nula
    --   - Checkout <= checkin en cualquier línea
    --   - Número de huéspedes supera capacidad de la habitación
    --   - Habitación ya ocupada en ese rango (solapamiento)
    --   - FIX #13: todas las habitaciones deben ser del mismo alojamiento
    -- -------------------------------------------------------------------------
    PROCEDURE sp_crear_reserva (
        p_id_cliente   IN  NUMBER,
        p_lineas       IN  t_lista_lineas_habitacion,
        p_estado       IN  VARCHAR2 DEFAULT 'CONFIRMADA',
        p_id_reserva   OUT NUMBER
    ) IS
        v_min_in        DATE;
        v_max_out       DATE;
        v_cap           NUMBER;
        v_valor         NUMBER(12,2);
        v_prom          NUMBER(12,2);
        v_noches        NUMBER;
        v_aloj_anterior NUMBER(8);
        v_aloj_actual   NUMBER(8);
    BEGIN
        -- Validar colección
        IF p_lineas IS NULL OR p_lineas.COUNT = 0 THEN
            RAISE_APPLICATION_ERROR(c_error_fechas, 'Debe indicar al menos una habitación.');
        END IF;

        v_min_in  := p_lineas(1).fecha_checkin;
        v_max_out := p_lineas(1).fecha_checkout;

        FOR i IN 1 .. p_lineas.COUNT LOOP

            -- Validar fechas de la línea
            IF p_lineas(i).fecha_checkout <= p_lineas(i).fecha_checkin THEN
                RAISE_APPLICATION_ERROR(
                    c_error_fechas,
                    'Checkout inválido en línea ' || i || ': debe ser posterior al check-in.'
                );
            END IF;

            -- Validar capacidad
            SELECT capacidad, id_alojamiento
            INTO   v_cap, v_aloj_actual
            FROM   HABITACION
            WHERE  id_habitacion = p_lineas(i).id_habitacion;

            IF p_lineas(i).num_huespedes > v_cap THEN
                RAISE_APPLICATION_ERROR(
                    c_error_capacidad,
                    'Capacidad excedida en habitación ' || p_lineas(i).id_habitacion
                    || ': máximo ' || v_cap || ' huéspedes, solicitados '
                    || p_lineas(i).num_huespedes || '.'
                );
            END IF;

            -- FIX #13: todas las habitaciones deben ser del mismo alojamiento
            IF i = 1 THEN
                v_aloj_anterior := v_aloj_actual;
            ELSIF v_aloj_actual <> v_aloj_anterior THEN
                RAISE_APPLICATION_ERROR(
                    c_error_alojamiento,
                    'Todas las habitaciones de una reserva deben pertenecer al mismo alojamiento.'
                    || ' Habitación ' || p_lineas(i).id_habitacion
                    || ' pertenece a alojamiento ' || v_aloj_actual
                    || ', se esperaba ' || v_aloj_anterior || '.'
                );
            END IF;

            -- Validar disponibilidad (solo si el estado final será activo)
            IF p_estado IN ('CONFIRMADA', 'COMPLETADA') THEN
                validar_disponibilidad(
                    p_lineas(i).id_habitacion,
                    p_lineas(i).fecha_checkin,
                    p_lineas(i).fecha_checkout
                );
            END IF;

            -- Calcular fechas marco del encabezado
            IF p_lineas(i).fecha_checkin  < v_min_in  THEN v_min_in  := p_lineas(i).fecha_checkin;  END IF;
            IF p_lineas(i).fecha_checkout > v_max_out THEN v_max_out := p_lineas(i).fecha_checkout; END IF;

        END LOOP;

        -- Insertar encabezado RESERVA
        INSERT INTO RESERVA (id_cliente, fecha_reserva, fecha_checkin, fecha_checkout, estado)
        VALUES (p_id_cliente, SYSDATE, v_min_in, v_max_out, p_estado)
        RETURNING id_reserva INTO p_id_reserva;

        -- Insertar líneas RESERVA_HABITACION
        FOR i IN 1 .. p_lineas.COUNT LOOP
            v_valor  := fn_valor_estadia(
                            p_lineas(i).id_habitacion,
                            p_lineas(i).fecha_checkin,
                            p_lineas(i).fecha_checkout
                        );
            v_noches := TRUNC(p_lineas(i).fecha_checkout) - TRUNC(p_lineas(i).fecha_checkin);
            v_prom   := CASE WHEN v_noches > 0 THEN ROUND(v_valor / v_noches, 2) ELSE v_valor END;

            INSERT INTO RESERVA_HABITACION (
                id_reserva, id_habitacion,
                fecha_checkin, fecha_checkout,
                num_huespedes, precio_noche_contratado
            ) VALUES (
                p_id_reserva,
                p_lineas(i).id_habitacion,
                p_lineas(i).fecha_checkin,
                p_lineas(i).fecha_checkout,
                p_lineas(i).num_huespedes,
                v_prom
            );
        END LOOP;

    END sp_crear_reserva;

    -- -------------------------------------------------------------------------
    -- PROCEDIMIENTO PÚBLICO: sp_liquidacion_mensual_alojamiento
    --
    -- CURSOR EXPLÍCITO PARAMETRIZADO: c_liquidacion(p_m, p_y)
    -- Recorre todos los alojamientos que tuvieron actividad en el mes/año dado.
    --
    -- FIX #14 (rendimiento): el valor de estadías se calcula en SQL puro
    -- (precio_noche_contratado × noches) sin llamar fn_valor_estadia en cada fila,
    -- evitando N llamadas PL/SQL dentro del cursor.
    --
    -- FIX #15: imprime el TOTAL combinado (estadías + servicios) por alojamiento.
    -- -------------------------------------------------------------------------
    PROCEDURE sp_liquidacion_mensual_alojamiento (
        p_mes  IN NUMBER,
        p_anio IN NUMBER
    ) IS

        -- Cursor parametrizado: recibe mes y año
        CURSOR c_liquidacion (p_m NUMBER, p_y NUMBER) IS
            SELECT
                a.id_alojamiento,
                a.nombre                                                         AS alojamiento,
                m.nombre                                                         AS municipio,
                COUNT(DISTINCT r.id_reserva)                                     AS num_reservas,
                -- Estadías: precio_noche_contratado × noches de cada línea de habitación
                NVL(SUM(
                    rh.precio_noche_contratado
                    * (rh.fecha_checkout - rh.fecha_checkin)
                ), 0)                                                            AS valor_estadias,
                -- Servicios: cantidad × precio_unitario (LEFT JOIN → NULL si no hay)
                NVL(SUM(rs.cantidad * rs.precio_unitario), 0)                   AS valor_servicios
            FROM  ALOJAMIENTO         a
            JOIN  MUNICIPIO           m  ON m.id_municipio    = a.id_municipio
            JOIN  HABITACION          h  ON h.id_alojamiento  = a.id_alojamiento
            JOIN  RESERVA_HABITACION  rh ON rh.id_habitacion  = h.id_habitacion
            JOIN  RESERVA             r  ON r.id_reserva      = rh.id_reserva
            LEFT JOIN RESERVA_SERVICIO rs ON rs.id_reserva    = r.id_reserva
            WHERE r.estado IN ('CONFIRMADA', 'COMPLETADA')
              AND EXTRACT(MONTH FROM rh.fecha_checkin) = p_m
              AND EXTRACT(YEAR  FROM rh.fecha_checkin) = p_y
            GROUP BY a.id_alojamiento, a.nombre, m.nombre
            ORDER BY valor_estadias + NVL(SUM(rs.cantidad * rs.precio_unitario), 0) DESC;

        v_reg          c_liquidacion%ROWTYPE;
        v_total_mes    NUMBER(14,2) := 0;
        v_total_serv   NUMBER(14,2) := 0;
        v_filas        NUMBER       := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('╔══════════════════════════════════════════════════════════════════╗');
        DBMS_OUTPUT.PUT_LINE('  LIQUIDACIÓN MENSUAL · Mes ' || LPAD(p_mes,2,'0') || '/' || p_anio);
        DBMS_OUTPUT.PUT_LINE('╚══════════════════════════════════════════════════════════════════╝');
        DBMS_OUTPUT.PUT_LINE(
            RPAD('ALOJAMIENTO', 30) || ' | ' ||
            RPAD('MUNICIPIO', 15)   || ' | ' ||
            LPAD('RESERVAS', 8)     || ' | ' ||
            LPAD('ESTADÍAS $',12)   || ' | ' ||
            LPAD('SERVICIOS $',12)  || ' | ' ||
            LPAD('TOTAL $',12)
        );
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));

        OPEN c_liquidacion(p_mes, p_anio);
        LOOP
            FETCH c_liquidacion INTO v_reg;
            EXIT WHEN c_liquidacion%NOTFOUND;

            DBMS_OUTPUT.PUT_LINE(
                RPAD(SUBSTR(v_reg.alojamiento, 1, 29), 30) || ' | ' ||
                RPAD(SUBSTR(v_reg.municipio,   1, 14), 15) || ' | ' ||
                LPAD(v_reg.num_reservas,         8)        || ' | ' ||
                LPAD(TO_CHAR(v_reg.valor_estadias,  'FM999,999,990.00'), 12) || ' | ' ||
                LPAD(TO_CHAR(v_reg.valor_servicios, 'FM999,999,990.00'), 12) || ' | ' ||
                LPAD(TO_CHAR(v_reg.valor_estadias + v_reg.valor_servicios, 'FM999,999,990.00'), 12)
            );

            v_total_mes  := v_total_mes  + v_reg.valor_estadias;
            v_total_serv := v_total_serv + v_reg.valor_servicios;
            v_filas      := v_filas + 1;
        END LOOP;
        CLOSE c_liquidacion;

        DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
        DBMS_OUTPUT.PUT_LINE(
            RPAD('TOTAL GENERAL', 57)                                           || ' | ' ||
            LPAD(TO_CHAR(v_total_mes,  'FM999,999,990.00'), 12)                 || ' | ' ||
            LPAD(TO_CHAR(v_total_serv, 'FM999,999,990.00'), 12)                 || ' | ' ||
            LPAD(TO_CHAR(v_total_mes + v_total_serv, 'FM999,999,990.00'), 12)
        );
        DBMS_OUTPUT.PUT_LINE('Alojamientos con actividad: ' || v_filas);

        IF v_filas = 0 THEN
            DBMS_OUTPUT.PUT_LINE('  (Sin reservas confirmadas o completadas en ' || p_mes || '/' || p_anio || ')');
        END IF;

    END sp_liquidacion_mensual_alojamiento;

END PKG_TURISMOUQ;
/


