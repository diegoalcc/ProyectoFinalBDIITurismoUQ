-- =============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - SCRIPT DE CARGA DE DATOS (PL/SQL)
-- Equipo: Sebastián Torres - Jorge William Montoya Toro - Diego Alejandro Carvajal Camargo
-- =============================================================================

SET SERVEROUTPUT ON;

DECLARE
    v_count NUMBER;
BEGIN
    -- 1. MUNICIPIOS (12)
    INSERT INTO MUNICIPIO (nombre) VALUES ('Armenia');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Salento');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Filandia');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Calarcá');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Montenegro');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Quimbaya');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Circasia');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Tebada');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Pijao');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Génova');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Córdoba');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Buenavista');

    -- 2. TIPO_ALOJAMIENTO (4)
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Finca cafetera');
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Hotel');
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Glamping');
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Hostal');

    -- 3. ALOJAMIENTO (60) - Distribucion Asimetrica
    FOR i IN 1..60 LOOP
        INSERT INTO ALOJAMIENTO (id_municipio, id_tipo_alojamiento, nombre, direccion, estrellas, telefono, email)
        VALUES (
            -- Asimetria: Mas alojamientos en Salento(2), Armenia(1) y Filandia(3)
            CASE 
                WHEN i <= 15 THEN 2 -- Salento
                WHEN i <= 28 THEN 1 -- Armenia
                WHEN i <= 40 THEN 3 -- Filandia
                ELSE TRUNC(DBMS_RANDOM.VALUE(4, 13)) -- Resto de municipios
            END,
            CASE 
                WHEN i <= 20 THEN 1 -- Finca Cafetera
                WHEN i <= 40 THEN 2 -- Hotel
                WHEN i <= 50 THEN 3 -- Glamping
                ELSE 4             -- Hostal
            END,
            'Alojamiento Turístico ' || i,
            'Calle ' || TRUNC(DBMS_RANDOM.VALUE(1, 30)) || ' # ' || TRUNC(DBMS_RANDOM.VALUE(1, 50)),
            TRUNC(DBMS_RANDOM.VALUE(1, 6)),
            '300' || TRUNC(DBMS_RANDOM.VALUE(1000000, 9999999)),
            'contacto@alojamiento' || i || '.com'
        );
    END LOOP;

    -- 4. HABITACION (400+) - Asimetria: Hoteles tienen muchas, Fincas pocas
    FOR r_aloj IN (SELECT id_alojamiento, id_tipo_alojamiento FROM ALOJAMIENTO) LOOP
        -- Determinacion del numero de habitaciones segun el tipo
        v_count := CASE r_aloj.id_tipo_alojamiento
                        WHEN 2 THEN TRUNC(DBMS_RANDOM.VALUE(25, 41)) -- Hoteles: 25-40 habs
                        WHEN 1 THEN TRUNC(DBMS_RANDOM.VALUE(3, 8))   -- Fincas: 3-7 habs
                        WHEN 3 THEN TRUNC(DBMS_RANDOM.VALUE(2, 6))   -- Glamping: 2-5 habs
                        ELSE TRUNC(DBMS_RANDOM.VALUE(5, 12))         -- Hostal: 5-11 habs
                   END;
                   
        FOR h IN 1..v_count LOOP
            INSERT INTO HABITACION (id_alojamiento, numero_habitacion, capacidad, tipo, descripcion)
            VALUES (
                r_aloj.id_alojamiento,
                TO_CHAR(h),
                TRUNC(DBMS_RANDOM.VALUE(1, 6)),
                CASE TRUNC(DBMS_RANDOM.VALUE(1, 5))
                    WHEN 1 THEN 'SENCILLA'
                    WHEN 2 THEN 'DOBLE'
                    WHEN 3 THEN 'SUITE'
                    ELSE 'CABAÑA'
                END,
                'Habitación cómoda con vista a la cordillera'
            );
        END LOOP;
    END LOOP;

    -- 5. TEMPORADA (6) - 2025 y 2026
    -- 2025
    INSERT INTO TEMPORADA (nombre, tipo_temporada, fecha_inicio, fecha_fin, anio)
    VALUES ('Semana Santa 2025', 'ALTA', TO_DATE('2025-04-13', 'YYYY-MM-DD'), TO_DATE('2025-04-20', 'YYYY-MM-DD'), 2025);
    INSERT INTO TEMPORADA (nombre, tipo_temporada, fecha_inicio, fecha_fin, anio)
    VALUES ('Mitad de Año y Diciembre 2025', 'ALTA', TO_DATE('2025-12-01', 'YYYY-MM-DD'), TO_DATE('2025-12-31', 'YYYY-MM-DD'), 2025);
    INSERT INTO TEMPORADA (nombre, tipo_temporada, fecha_inicio, fecha_fin, anio)
    VALUES ('Temporada Regular 2025', 'BAJA', TO_DATE('2025-01-01', 'YYYY-MM-DD'), TO_DATE('2025-04-12', 'YYYY-MM-DD'), 2025);

    -- 2026
    INSERT INTO TEMPORADA (nombre, tipo_temporada, fecha_inicio, fecha_fin, anio)
    VALUES ('Semana Santa 2026', 'ALTA', TO_DATE('2026-03-29', 'YYYY-MM-DD'), TO_DATE('2026-04-05', 'YYYY-MM-DD'), 2026);
    INSERT INTO TEMPORADA (nombre, tipo_temporada, fecha_inicio, fecha_fin, anio)
    VALUES ('Mitad de Año 2026', 'MEDIA', TO_DATE('2026-06-01', 'YYYY-MM-DD'), TO_DATE('2026-07-15', 'YYYY-MM-DD'), 2026);
    INSERT INTO TEMPORADA (nombre, tipo_temporada, fecha_inicio, fecha_fin, anio)
    VALUES ('Temporada Regular 2026', 'BAJA', TO_DATE('2026-01-01', 'YYYY-MM-DD'), TO_DATE('2026-03-28', 'YYYY-MM-DD'), 2026);

    -- 6. TARIFA (Poblado masivo por cruce Habitación x Temporada)
    INSERT INTO TARIFA (id_habitacion, id_temporada, precio_noche)
    SELECT h.id_habitacion, t.id_temporada,
           CASE t.tipo_temporada
               WHEN 'ALTA'  THEN TRUNC(DBMS_RANDOM.VALUE(180000, 350000))
               WHEN 'MEDIA' THEN TRUNC(DBMS_RANDOM.VALUE(120000, 180000))
               ELSE              TRUNC(DBMS_RANDOM.VALUE(70000, 120000))
           END
    FROM HABITACION h
    CROSS JOIN TEMPORADA t;

    -- 7. CLIENTE (3,000)
    FOR c IN 1..3000 LOOP
        INSERT INTO CLIENTE (nombre, documento_identidad, email, telefono, ciudad_origen)
        VALUES (
            'Cliente ' || c,
            TO_CHAR(10000000 + c),
            'cliente' || c || '@mail.com',
            '310' || TRUNC(DBMS_RANDOM.VALUE(1000000, 9999999)),
            CASE TRUNC(DBMS_RANDOM.VALUE(1, 6))
                WHEN 1 THEN 'Bogotá'
                WHEN 2 THEN 'Medellín'
                WHEN 3 THEN 'Cali'
                WHEN 4 THEN 'Pereira'
                ELSE 'Manizales'
            END
        );
    END LOOP;

    -- 8. SERVICIO (30+)
    FOR a IN 1..60 LOOP
        IF MOD(a, 2) = 0 THEN
            INSERT INTO SERVICIO (id_alojamiento, nombre, descripcion, precio)
            VALUES (a, 'Desayuno Tipo Buffet', 'Incluye opciones típicas de la región', 25000);
            INSERT INTO SERVICIO (id_alojamiento, nombre, descripcion, precio)
            VALUES (a, 'Tour del Café Guiado', 'Recorrido por los cafetales con catación', 45000);
        END IF;
    END LOOP;

    -- 9. USUARIO_SISTEMA (10)
    INSERT INTO USUARIO_SISTEMA (id_alojamiento, username, password_hash, rol) VALUES (NULL, 'admin_general', 'hash_admin_123', 'ADMINISTRADOR');
    FOR u IN 1..9 LOOP
        INSERT INTO USUARIO_SISTEMA (id_alojamiento, username, password_hash, rol)
        VALUES (u, 'encargado_' || u, 'hash_pass_' || u, 'ENCARGADO');
    END LOOP;

    COMMIT;
END;
/

-- 10. CARGA MASIVA DE RESERVAS, HABITACIONES_RESERVA, PAGOS Y SERVICIOS
-- Carga iterativa para asegurar estacionalidad alta en Abril/Diciembre y volumen (25,000+)
DECLARE
    v_fecha_in DATE;
    v_dias NUMBER;
    v_fecha_out DATE;
    v_res_id NUMBER;
    v_hab_id NUMBER;
    v_monto NUMBER;
    v_est VARCHAR2(15);
BEGIN
    FOR i IN 1..25000 LOOP
        -- Generar estacionalidad concentrada en meses clave
        IF MOD(i, 3) = 0 THEN
            -- Abril (Semana Santa) o Diciembre
            v_fecha_in := TO_DATE('2025-04-01', 'YYYY-MM-DD') + TRUNC(DBMS_RANDOM.VALUE(0, 25));
        ELSIF MOD(i, 5) = 0 THEN
            v_fecha_in := TO_DATE('2025-12-01', 'YYYY-MM-DD') + TRUNC(DBMS_RANDOM.VALUE(0, 30));
        ELSE
            -- Resto del año aleatorio entre 2024 y 2026
            v_fecha_in := TO_DATE('2024-01-01', 'YYYY-MM-DD') + TRUNC(DBMS_RANDOM.VALUE(0, 900));
        END IF;
        
        v_dias := TRUNC(DBMS_RANDOM.VALUE(1, 6));
        v_fecha_out := v_fecha_in + v_dias;
        
        v_est := CASE 
                    WHEN v_fecha_out < SYSDATE THEN 'COMPLETADA'
                    WHEN MOD(i, 10) = 0 THEN 'CANCELADA'
                    ELSE 'CONFIRMADA'
                 END;

        INSERT INTO RESERVA (id_cliente, fecha_reserva, fecha_checkin, fecha_checkout, estado)
        VALUES (
            TRUNC(DBMS_RANDOM.VALUE(1, 3001)),
            v_fecha_in - 5,
            v_fecha_in,
            v_fecha_out,
            v_est
        ) RETURNING id_reserva INTO v_res_id;

        -- Seleccionar una habitacion aleatoria
        v_hab_id := TRUNC(DBMS_RANDOM.VALUE(1, 400));
        v_monto := v_dias * 120000;

        -- Detalle Reserva-Habitación
        INSERT INTO RESERVA_HABITACION (id_reserva, id_habitacion, fecha_checkin, fecha_checkout, precio_noche_contratado)
        VALUES (v_res_id, v_hab_id, v_fecha_in, v_fecha_out, 120000);

        -- Pago asociado
        INSERT INTO PAGO (id_reserva, fecha_pago, monto, metodo, estado)
        VALUES (v_res_id, v_fecha_in - 5, v_monto, 'PSE', 'EXITOSO');

        -- Servicios contratados alternados (40,000+ lineas agregadas)
        INSERT INTO RESERVA_SERVICIO (id_reserva, id_servicio, cantidad, precio_unitario)
        VALUES (v_res_id, 1, TRUNC(DBMS_RANDOM.VALUE(1, 4)), 25000);
        
        IF MOD(i, 2) = 0 THEN
            INSERT INTO RESERVA_SERVICIO (id_reserva, id_servicio, cantidad, precio_unitario)
            VALUES (v_res_id, 2, TRUNC(DBMS_RANDOM.VALUE(1, 3)), 45000);
        END IF;

    END LOOP;
    COMMIT;
END;
/

-- 11. CARGA DE RESEÑAS (≥ 40% sobre reservas completadas)
INSERT INTO RESENA (id_alojamiento, id_cliente, id_reserva, calificacion, comentario, fecha_resena)
SELECT h.id_alojamiento, r.id_cliente, r.id_reserva, 
       TRUNC(DBMS_RANDOM.VALUE(1, 6)),
       'Excelente servicio y gran experiencia en el Quindío.',
       r.fecha_checkout + 1
FROM RESERVA r
JOIN RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
JOIN HABITACION h ON rh.id_habitacion = h.id_habitacion
WHERE r.estado = 'COMPLETADA'
  AND ROWNUM <= (SELECT COUNT(*) * 0.45 FROM RESERVA WHERE estado = 'COMPLETADA');
  
COMMIT;