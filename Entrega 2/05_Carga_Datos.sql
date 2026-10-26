-- =============================================================================
-- TURISMOUQ - CARGA DE DATOS
-- Equipo: Sebastián Torres Morales · Jorge William Montoya Toro · Diego Alejandro Carvajal Camargo
--
-- Ejecutar DESPUÉS de 03_Paquete_PKG_TURISMOUQ.sql y ANTES de 04_Triggers.sql.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- BLOQUE 1: Catálogos + Habitaciones + Temporadas + Tarifas + Clientes + Servicios
-- =============================================================================
DECLARE
    v_count    NUMBER;
    v_mun_id   NUMBER;
BEGIN
    -- -------------------------------------------------------------------------
    -- 1. MUNICIPIOS (12 oficiales del Quindío)
    -- -------------------------------------------------------------------------
    INSERT INTO MUNICIPIO (nombre) VALUES ('Armenia');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Salento');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Filandia');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Calarcá');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Montenegro');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Quimbaya');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Circasia');
    INSERT INTO MUNICIPIO (nombre) VALUES ('La Tebaida');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Pijao');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Génova');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Córdoba');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Buenavista');

    -- -------------------------------------------------------------------------
    -- 2. TIPOS DE ALOJAMIENTO
    -- -------------------------------------------------------------------------
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Finca cafetera');
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Hotel');
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Glamping');
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Hostal');

    -- -------------------------------------------------------------------------
    -- 3. ALOJAMIENTOS (60) — asimetría por municipio + nombres realistas (#26)
    -- Distribución: Salento (8) Armenia (6) Filandia (5) Calarcá (5) Montenegro (5)
    --               Quimbaya (4) Circasia (4) La Tebaida (4) Pijao (4)
    --               Génova (4)  Córdoba (5)  Buenavista (6)
    -- -------------------------------------------------------------------------
    DECLARE
        TYPE t_nombres IS TABLE OF VARCHAR2(100);
        v_nom t_nombres := t_nombres(
            -- Fincas cafeteras (tipo 1) — i 1..18
            'Finca La Esperanza','Finca El Paraíso','Finca Villa Café','Finca Los Samanes',
            'Finca El Edén','Finca La Montaña Verde','Finca Café y Vida','Finca El Pórtico',
            'Finca Los Helechos','Finca Cantalicio','Finca El Rancho','Finca Villa Aurora',
            'Finca La Primavera','Finca Tucumán','Finca Los Guaduales','Finca El Descanso',
            'Finca El Bambusal','Finca Villa Alegría',
            -- Hoteles (tipo 2) — i 19..38
            'Hotel Quindío Plaza','Hotel Bosques de Armenia','Hotel La Serranía',
            'Hotel El Camino Real','Hotel Villa Boutique','Hotel Real Cafetero',
            'Hotel Las Palmas','Hotel El Mirador','Hotel Zentro','Hotel La Ceiba',
            'Hotel Araucaria','Hotel Los Patios','Hotel Tambo Real','Hotel Sierra Nevada',
            'Hotel El Peñol','Hotel Centenario','Hotel Gran Colombia','Hotel Santa Teresita',
            'Hotel Los Nevados','Hotel El Roble',
            -- Glampings (tipo 3) — i 39..48
            'Glamping Nido del Cóndor','Glamping Bajo las Estrellas','Glamping Tierra Viva',
            'Glamping El Susurro','Glamping Lluvia de Café','Glamping Cumbres del Quindío',
            'Glamping Selva Mágica','Glamping Altavista','Glamping Cielo Abierto',
            'Glamping La Colina',
            -- Hostales (tipo 4) — i 49..60
            'Hostal El Viajero','Hostal Casa del Café','Hostal La Trova',
            'Hostal Rincón Quindiano','Hostal Los Fundadores','Hostal El Camino',
            'Hostal Tierra Quindía','Hostal Buena Ventura','Hostal El Retorno',
            'Hostal La Brisa','Hostal Villa Nueva','Hostal Cafetal'
        );
    BEGIN
        FOR i IN 1..60 LOOP
            v_mun_id := CASE
                WHEN i <=  8 THEN 2   -- Salento       (8 aloj)
                WHEN i <= 14 THEN 1   -- Armenia        (6 aloj)
                WHEN i <= 19 THEN 3   -- Filandia       (5 aloj)
                WHEN i <= 24 THEN 4   -- Calarcá        (5 aloj)
                WHEN i <= 29 THEN 5   -- Montenegro     (5 aloj)
                WHEN i <= 33 THEN 6   -- Quimbaya       (4 aloj)
                WHEN i <= 37 THEN 7   -- Circasia       (4 aloj)
                WHEN i <= 41 THEN 8   -- La Tebaida     (4 aloj)
                WHEN i <= 45 THEN 9   -- Pijao          (4 aloj)
                WHEN i <= 49 THEN 10  -- Génova         (4 aloj)
                WHEN i <= 54 THEN 11  -- Córdoba        (5 aloj)
                ELSE               12  -- Buenavista    (6 aloj)
            END;

            INSERT INTO ALOJAMIENTO (
                id_municipio, id_tipo_alojamiento,
                nombre, direccion, estrellas, telefono, email
            ) VALUES (
                v_mun_id,
                CASE
                    WHEN i <= 18 THEN 1  -- Finca cafetera
                    WHEN i <= 38 THEN 2  -- Hotel
                    WHEN i <= 48 THEN 3  -- Glamping
                    ELSE              4  -- Hostal
                END,
                v_nom(i),
                'Vereda ' || TRUNC(DBMS_RANDOM.VALUE(1,20)) || ' Km ' || TRUNC(DBMS_RANDOM.VALUE(1,30)),
                TRUNC(DBMS_RANDOM.VALUE(2,6)),
                '3' || TRUNC(DBMS_RANDOM.VALUE(100000000,999999999)),
                LOWER(REPLACE(v_nom(i),' ','_')) || '@turismouq.co'
            );
        END LOOP;
    END;

    -- -------------------------------------------------------------------------
    -- 4. HABITACIONES (≥400) — asimetría real por tipo de alojamiento
    --    Hoteles: 25-40  |  Fincas: 3-7  |  Glampings: 4-8  |  Hostales: 6-14
    -- -------------------------------------------------------------------------
    FOR r IN (SELECT id_alojamiento, id_tipo_alojamiento FROM ALOJAMIENTO) LOOP
        v_count := CASE r.id_tipo_alojamiento
            WHEN 2 THEN TRUNC(DBMS_RANDOM.VALUE(25, 41))  -- Hotel
            WHEN 1 THEN TRUNC(DBMS_RANDOM.VALUE( 3,  8))  -- Finca cafetera
            WHEN 3 THEN TRUNC(DBMS_RANDOM.VALUE( 4,  9))  -- Glamping
            ELSE        TRUNC(DBMS_RANDOM.VALUE( 6, 15))  -- Hostal
        END;

        FOR h IN 1 .. v_count LOOP
            INSERT INTO HABITACION (
                id_alojamiento, numero_habitacion, capacidad, tipo, descripcion
            ) VALUES (
                r.id_alojamiento,
                TO_CHAR(h),
                TRUNC(DBMS_RANDOM.VALUE(1, 6)),
                CASE r.id_tipo_alojamiento
                    WHEN 1 THEN
                        CASE TRUNC(DBMS_RANDOM.VALUE(1,3)) WHEN 1 THEN 'CABAÑA' ELSE 'DOBLE' END
                    WHEN 2 THEN
                        CASE TRUNC(DBMS_RANDOM.VALUE(1,5))
                            WHEN 1 THEN 'SENCILLA' WHEN 2 THEN 'DOBLE'
                            WHEN 3 THEN 'SUITE'    ELSE 'DOBLE' END
                    WHEN 3 THEN 'GLAMPING'
                    ELSE
                        CASE TRUNC(DBMS_RANDOM.VALUE(1,3)) WHEN 1 THEN 'SENCILLA' ELSE 'COMPARTIDA' END
                END,
                'Vista al paisaje cafetero · piso ' || CEIL(h/10)
            );
        END LOOP;
    END LOOP;

    SELECT COUNT(*) INTO v_count FROM HABITACION;
    DBMS_OUTPUT.PUT_LINE('Habitaciones creadas: ' || v_count);

    -- -------------------------------------------------------------------------
    -- 5. TEMPORADAS — cobertura completa 2024-2026 con asimetría estacional (#25)
    --
    -- FIX: 2024 ya no es una sola temporada MEDIA; tiene ALTA/MEDIA/BAJA reales.
    -- -------------------------------------------------------------------------
    -- 2024
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Semana Santa 2024','ALTA', DATE'2024-03-24',DATE'2024-03-31',2024);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Mitad de año 2024','ALTA', DATE'2024-06-15',DATE'2024-07-14',2024);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Puentes oct 2024', 'ALTA', DATE'2024-10-12',DATE'2024-10-14',2024);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Diciembre 2024',   'ALTA', DATE'2024-12-15',DATE'2024-12-31',2024);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Transición 2024',  'MEDIA',DATE'2024-04-01',DATE'2024-06-14',2024);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Temporada media 2024-2','MEDIA',DATE'2024-07-15',DATE'2024-10-11',2024);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Baja 2024',        'BAJA', DATE'2024-01-01',DATE'2024-03-23',2024);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Baja tardía 2024', 'BAJA', DATE'2024-10-15',DATE'2024-12-14',2024);
    -- 2025
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Semana Santa 2025','ALTA', DATE'2025-04-13',DATE'2025-04-20',2025);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Mitad de año 2025','ALTA', DATE'2025-06-20',DATE'2025-07-15',2025);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Puentes ago 2025', 'ALTA', DATE'2025-08-04',DATE'2025-08-10',2025);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Diciembre 2025',   'ALTA', DATE'2025-12-15',DATE'2026-01-05',2025);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Transición 2025',  'MEDIA',DATE'2025-04-21',DATE'2025-06-19',2025);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Media 2025-2',     'MEDIA',DATE'2025-07-16',DATE'2025-08-03',2025);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Media 2025-3',     'MEDIA',DATE'2025-08-11',DATE'2025-12-14',2025);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Baja 2025',        'BAJA', DATE'2025-01-01',DATE'2025-04-12',2025);
    -- 2026
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Semana Santa 2026','ALTA', DATE'2026-03-29',DATE'2026-04-05',2026);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Mitad de año 2026','ALTA', DATE'2026-06-20',DATE'2026-07-14',2026);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Puentes oct 2026', 'ALTA', DATE'2026-10-12',DATE'2026-10-13',2026);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Media 2026',       'MEDIA',DATE'2026-04-06',DATE'2026-06-19',2026);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Media 2026-2',     'MEDIA',DATE'2026-07-15',DATE'2026-10-11',2026);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Media 2026-3',     'MEDIA',DATE'2026-10-14',DATE'2026-12-31',2026);
    INSERT INTO TEMPORADA VALUES (DEFAULT,'Baja 2026',        'BAJA', DATE'2026-01-01',DATE'2026-03-28',2026);

    -- -------------------------------------------------------------------------
    -- 6. TARIFAS (cruce habitación × temporada)
    --    Precio autónomo por habitación, NO porcentaje fijo.
    --    Hoteles cobran más; fincas y glampings tienen rango medio; hostales bajo.
    -- -------------------------------------------------------------------------
    INSERT INTO TARIFA (id_habitacion, id_temporada, precio_noche)
    SELECT
        h.id_habitacion,
        t.id_temporada,
        CASE ta.nombre
            WHEN 'Hotel' THEN
                CASE t.tipo_temporada
                    WHEN 'ALTA'  THEN TRUNC(DBMS_RANDOM.VALUE(220000, 420000))
                    WHEN 'MEDIA' THEN TRUNC(DBMS_RANDOM.VALUE(150000, 220000))
                    ELSE              TRUNC(DBMS_RANDOM.VALUE( 90000, 150000))
                END
            WHEN 'Glamping' THEN
                CASE t.tipo_temporada
                    WHEN 'ALTA'  THEN TRUNC(DBMS_RANDOM.VALUE(200000, 380000))
                    WHEN 'MEDIA' THEN TRUNC(DBMS_RANDOM.VALUE(140000, 200000))
                    ELSE              TRUNC(DBMS_RANDOM.VALUE( 80000, 140000))
                END
            WHEN 'Finca cafetera' THEN
                CASE t.tipo_temporada
                    WHEN 'ALTA'  THEN TRUNC(DBMS_RANDOM.VALUE(160000, 300000))
                    WHEN 'MEDIA' THEN TRUNC(DBMS_RANDOM.VALUE(110000, 160000))
                    ELSE              TRUNC(DBMS_RANDOM.VALUE( 60000, 110000))
                END
            ELSE  -- Hostal
                CASE t.tipo_temporada
                    WHEN 'ALTA'  THEN TRUNC(DBMS_RANDOM.VALUE( 80000, 150000))
                    WHEN 'MEDIA' THEN TRUNC(DBMS_RANDOM.VALUE( 55000,  80000))
                    ELSE              TRUNC(DBMS_RANDOM.VALUE( 35000,  55000))
                END
        END AS precio_noche
    FROM HABITACION  h
    JOIN ALOJAMIENTO a  ON a.id_alojamiento    = h.id_alojamiento
    JOIN TIPO_ALOJAMIENTO ta ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
    CROSS JOIN TEMPORADA t;

    -- -------------------------------------------------------------------------
    -- 7. CLIENTES (3.000) — ciudades variadas, no solo del Quindío
    -- -------------------------------------------------------------------------
    FOR c IN 1 .. 3000 LOOP
        INSERT INTO CLIENTE (nombre, documento_identidad, email, telefono, ciudad_origen)
        VALUES (
            CASE TRUNC(DBMS_RANDOM.VALUE(0,10))
                WHEN 0 THEN 'Carlos' WHEN 1 THEN 'Andrés' WHEN 2 THEN 'María'
                WHEN 3 THEN 'Laura'  WHEN 4 THEN 'Felipe' WHEN 5 THEN 'Valentina'
                WHEN 6 THEN 'Diego'  WHEN 7 THEN 'Juliana' WHEN 8 THEN 'Sebastián'
                ELSE 'Daniela'
            END || ' ' ||
            CASE TRUNC(DBMS_RANDOM.VALUE(0,10))
                WHEN 0 THEN 'García'   WHEN 1 THEN 'López'   WHEN 2 THEN 'Martínez'
                WHEN 3 THEN 'Rodríguez' WHEN 4 THEN 'Hernández' WHEN 5 THEN 'Gómez'
                WHEN 6 THEN 'Torres'   WHEN 7 THEN 'Vargas'  WHEN 8 THEN 'Castro'
                ELSE 'Morales'
            END || ' ' || c,
            TO_CHAR(10000000 + c),
            'cliente' || c || '@correo.co',
            '3' || TRUNC(DBMS_RANDOM.VALUE(100000000, 999999999)),
            CASE TRUNC(DBMS_RANDOM.VALUE(0, 12))
                WHEN 0  THEN 'Bogotá'       WHEN 1  THEN 'Medellín'
                WHEN 2  THEN 'Cali'         WHEN 3  THEN 'Pereira'
                WHEN 4  THEN 'Manizales'    WHEN 5  THEN 'Cartagena'
                WHEN 6  THEN 'Barranquilla' WHEN 7  THEN 'Bucaramanga'
                WHEN 8  THEN 'Ibagué'       WHEN 9  THEN 'Cúcuta'
                WHEN 10 THEN 'Armenia'      WHEN 11 THEN 'Villavicencio'
                ELSE         'Pasto'
            END
        );
    END LOOP;

    -- -------------------------------------------------------------------------
    -- 8. SERVICIOS (≥30 registros, varios por alojamiento)
    -- -------------------------------------------------------------------------
    FOR a IN (SELECT id_alojamiento, id_tipo_alojamiento FROM ALOJAMIENTO) LOOP
        -- Todos los alojamientos ofrecen desayuno
        INSERT INTO SERVICIO (id_alojamiento, nombre, descripcion, precio)
        VALUES (a.id_alojamiento, 'Desayuno típico', 'Bandeja paisa o tamal quindiano', 22000);

        -- Hoteles y fincas tienen tour del café
        IF a.id_tipo_alojamiento IN (1, 2) THEN
            INSERT INTO SERVICIO (id_alojamiento, nombre, descripcion, precio)
            VALUES (a.id_alojamiento, 'Tour del café', 'Recorrido y catación en el cafetal', 45000);
        END IF;

        -- Glampings y hoteles grandes tienen spa
        IF a.id_tipo_alojamiento IN (2, 3) THEN
            INSERT INTO SERVICIO (id_alojamiento, nombre, descripcion, precio)
            VALUES (a.id_alojamiento, 'Acceso spa y piscina', 'Incluye sauna y jacuzzi', 60000);
        END IF;

        -- Uno de cada 3 ofrece transporte aeropuerto
        IF MOD(a.id_alojamiento, 3) = 0 THEN
            INSERT INTO SERVICIO (id_alojamiento, nombre, descripcion, precio)
            VALUES (a.id_alojamiento, 'Transporte aeropuerto', 'Traslado Armenia ida y vuelta', 55000);
        END IF;

        -- Fincas y glampings ofrecen alquiler de bicicletas
        IF a.id_tipo_alojamiento IN (1, 3) THEN
            INSERT INTO SERVICIO (id_alojamiento, nombre, descripcion, precio)
            VALUES (a.id_alojamiento, 'Alquiler bicicletas', 'Bicicleta de montaña por día', 30000);
        END IF;
    END LOOP;

    -- -------------------------------------------------------------------------
    -- 9. USUARIOS DEL SISTEMA (10 mínimo)
    -- -------------------------------------------------------------------------
    INSERT INTO USUARIO_SISTEMA (id_alojamiento, username, password_hash, rol)
    VALUES (NULL, 'admin_general',   'sha256$TurismoUQ2026$admin',   'ADMINISTRADOR');
    INSERT INTO USUARIO_SISTEMA (id_alojamiento, username, password_hash, rol)
    VALUES (NULL, 'gerente_plataforma', 'sha256$TurismoUQ2026$ger', 'GERENTE');

    FOR u IN 1..8 LOOP
        INSERT INTO USUARIO_SISTEMA (id_alojamiento, username, password_hash, rol)
        VALUES (
            u,
            'encargado_aloj' || u,
            'sha256$TurismoUQ2026$enc' || u,
            'ENCARGADO'
        );
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('=== Catálogos, temporadas, tarifas, clientes y servicios cargados ===');

END;
/

-- =============================================================================
-- BLOQUE 2: RESERVAS + RESERVA_HABITACION + PAGOS
-- =============================================================================
DECLARE
    TYPE t_fecha_map IS TABLE OF DATE INDEX BY PLS_INTEGER;
    v_sig         t_fecha_map;
    v_fin         DATE;
    v_fout        DATE;
    v_dias        NUMBER;
    v_res_id      NUMBER;
    v_hab_id      NUMBER;
    v_hab2        NUMBER;
    v_est         VARCHAR2(15);
    v_val         NUMBER(12,2);
    v_prom        NUMBER(12,2);
    v_total       NUMBER(12,2);
    v_nhab        NUMBER;
    v_aloj        NUMBER;
    v_cli         NUMBER;

    -- Devuelve id_habitacion según posición ordinal (round-robin)
    FUNCTION hrn(p NUMBER) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT id_habitacion INTO v
        FROM (SELECT id_habitacion,
                     ROW_NUMBER() OVER (ORDER BY id_habitacion) rn
              FROM HABITACION)
        WHERE rn = p;
        RETURN v;
    END;

    -- Procedimiento local para INSERT de pagos (evita ambigüedad de columnas)
    PROCEDURE ins_pago(
        p_res   NUMBER,
        p_fecha DATE,
        p_monto NUMBER,
        p_met   VARCHAR2
    ) IS
    BEGIN
        INSERT INTO PAGO (id_reserva, fecha_pago, monto, metodo, estado)
        VALUES (p_res, p_fecha, p_monto, p_met, 'EXITOSO');
    END;

BEGIN
    SELECT COUNT(*) INTO v_nhab FROM HABITACION;
    DBMS_OUTPUT.PUT_LINE('Habitaciones disponibles: ' || v_nhab);

    -- Inicializar slot libre por habitación (fechas escalonadas)
    FOR h IN (SELECT id_habitacion FROM HABITACION) LOOP
        v_sig(h.id_habitacion) :=
            DATE '2024-01-01' + TRUNC(DBMS_RANDOM.VALUE(0, 60));
    END LOOP;

    FOR i IN 1 .. 25000 LOOP

        v_hab_id := hrn(MOD(i - 1, v_nhab) + 1);

        -- Distribución estacional
        IF    MOD(i, 3)  = 0 THEN v_fin := DATE '2025-04-13' + TRUNC(DBMS_RANDOM.VALUE(0,  7));
        ELSIF MOD(i, 5)  = 0 THEN v_fin := DATE '2025-06-20' + TRUNC(DBMS_RANDOM.VALUE(0, 25));
        ELSIF MOD(i, 7)  = 0 THEN v_fin := DATE '2025-12-15' + TRUNC(DBMS_RANDOM.VALUE(0, 21));
        ELSIF MOD(i, 11) = 0 THEN v_fin := DATE '2024-06-15' + TRUNC(DBMS_RANDOM.VALUE(0, 29));
        ELSE  v_fin := v_sig(v_hab_id);
        END IF;

        v_dias := TRUNC(DBMS_RANDOM.VALUE(1, 7));
        v_fout := v_fin + v_dias;

        v_est := CASE
            WHEN v_fout < TRUNC(SYSDATE) - 60 THEN 'COMPLETADA'
            WHEN v_fout < TRUNC(SYSDATE) THEN
                CASE WHEN MOD(i, 15) = 0 THEN 'CANCELADA' ELSE 'COMPLETADA' END
            WHEN MOD(i, 12) = 0 THEN 'CANCELADA'
            WHEN MOD(i,  8) = 0 THEN 'PENDIENTE'
            ELSE 'CONFIRMADA'
        END;

        IF v_est <> 'CANCELADA' THEN
            v_sig(v_hab_id) := v_fout + TRUNC(DBMS_RANDOM.VALUE(1, 5));
        END IF;

        v_cli := TRUNC(DBMS_RANDOM.VALUE(1, 3001));

        INSERT INTO RESERVA (id_cliente, fecha_reserva, fecha_checkin, fecha_checkout, estado)
        VALUES (v_cli, v_fin - TRUNC(DBMS_RANDOM.VALUE(3, 20)), v_fin, v_fout, v_est)
        RETURNING id_reserva INTO v_res_id;

        v_val  := PKG_TURISMOUQ.fn_valor_estadia(v_hab_id, v_fin, v_fout);
        v_prom := CASE WHEN v_dias > 0 THEN ROUND(v_val / v_dias, 2) ELSE v_val END;

        SELECT id_alojamiento INTO v_aloj
        FROM HABITACION WHERE id_habitacion = v_hab_id;

        INSERT INTO RESERVA_HABITACION
            (id_reserva, id_habitacion, fecha_checkin, fecha_checkout,
             num_huespedes, precio_noche_contratado)
        VALUES (v_res_id, v_hab_id, v_fin, v_fout,
                TRUNC(DBMS_RANDOM.VALUE(1, 4)), v_prom);

        -- Segunda habitación en ~8% de reservas activas (mismo alojamiento)
        IF MOD(i, 12) = 1 AND v_est IN ('CONFIRMADA', 'COMPLETADA') THEN
            BEGIN
                -- Busca otra habitación del mismo alojamiento (sin .EXISTS en SQL)
                SELECT id_habitacion INTO v_hab2
                FROM (
                    SELECT h2.id_habitacion
                    FROM HABITACION h2
                    WHERE h2.id_alojamiento = v_aloj
                      AND h2.id_habitacion <> v_hab_id
                    ORDER BY DBMS_RANDOM.VALUE
                )
                WHERE ROWNUM = 1;

                v_val  := PKG_TURISMOUQ.fn_valor_estadia(v_hab2, v_fin, v_fout);
                v_prom := CASE WHEN v_dias > 0 THEN ROUND(v_val / v_dias, 2) ELSE v_val END;

                INSERT INTO RESERVA_HABITACION
                    (id_reserva, id_habitacion, fecha_checkin, fecha_checkout,
                     num_huespedes, precio_noche_contratado)
                VALUES (v_res_id, v_hab2, v_fin, v_fout,
                        TRUNC(DBMS_RANDOM.VALUE(1, 4)), v_prom);

                v_sig(v_hab2) := v_fout + TRUNC(DBMS_RANDOM.VALUE(1, 5));
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
            END;
        END IF;

        -- Total de la reserva para calcular pagos
        SELECT NVL(SUM(rh.precio_noche_contratado * (rh.fecha_checkout - rh.fecha_checkin)), 0)
        INTO v_total
        FROM RESERVA_HABITACION rh
        WHERE rh.id_reserva = v_res_id;

        IF v_est IN ('CONFIRMADA', 'COMPLETADA', 'PENDIENTE') THEN
            IF MOD(i, 4) = 0 THEN
                ins_pago(v_res_id, v_fin - 10, ROUND(v_total * 0.4, 2), 'PSE');
                ins_pago(v_res_id, v_fin - 1,  ROUND(v_total * 0.6, 2), 'TARJETA_CREDITO');
            ELSIF MOD(i, 5) = 0 THEN
                ins_pago(v_res_id, v_fin - 15, ROUND(v_total * 0.3, 2), 'TRANSFERENCIA');
                ins_pago(v_res_id, v_fin - 7,  ROUND(v_total * 0.4, 2), 'PSE');
                ins_pago(v_res_id, v_fin,       ROUND(v_total * 0.3, 2), 'EFECTIVO');
            ELSE
                ins_pago(v_res_id,
                         v_fin - TRUNC(DBMS_RANDOM.VALUE(1, 10)),
                         v_total,
                         CASE TRUNC(DBMS_RANDOM.VALUE(0, 5))
                             WHEN 0 THEN 'TARJETA_CREDITO'
                             WHEN 1 THEN 'TARJETA_DEBITO'
                             WHEN 2 THEN 'PSE'
                             WHEN 3 THEN 'TRANSFERENCIA'
                             ELSE        'EFECTIVO'
                         END);
            END IF;
        END IF;

        -- Commit parcial cada 1000 filas
        IF MOD(i, 1000) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('  Procesadas ' || i || ' reservas...');
        END IF;

    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('=== Reservas, habitaciones y pagos cargados ===');
END;
/


-- =============================================================================
-- BLOQUE 3: RESERVA_SERVICIO
-- FIX #21: usa IDs reales de RESERVA y SERVICIO (no hardcoded ni random puro).
-- Relaciona servicios del alojamiento correcto con reservas de ese alojamiento.
-- Respeta UNIQUE(id_reserva, id_servicio) con MERGE para evitar duplicados.
-- =============================================================================
DECLARE
    v_count NUMBER := 0;
BEGIN
    -- Generar ~40.000 líneas cruzando reservas con servicios del mismo alojamiento
    FOR rec IN (
        SELECT id_reserva, id_servicio, precio
        FROM (
            SELECT DISTINCT
                   r.id_reserva,
                   s.id_servicio,
                   s.precio
            FROM   RESERVA            r
            JOIN   RESERVA_HABITACION rh ON rh.id_reserva    = r.id_reserva
            JOIN   HABITACION         h  ON h.id_habitacion  = rh.id_habitacion
            JOIN   SERVICIO           s  ON s.id_alojamiento = h.id_alojamiento
            WHERE  r.estado IN ('CONFIRMADA', 'COMPLETADA')
              AND  DBMS_RANDOM.VALUE(0,1) < 0.30
        )
        ORDER BY DBMS_RANDOM.VALUE
        FETCH FIRST 42000 ROWS ONLY
    ) LOOP
        BEGIN
            INSERT INTO RESERVA_SERVICIO (id_reserva, id_servicio, cantidad, precio_unitario)
            VALUES (
                rec.id_reserva,
                rec.id_servicio,
                TRUNC(DBMS_RANDOM.VALUE(1, 4)),
                rec.precio
            );
            v_count := v_count + 1;

            IF MOD(v_count, 5000) = 0 THEN
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('  Servicios insertados: ' || v_count);
            END IF;
        EXCEPTION
            -- UNIQUE constraint: ya existe esa combinación reserva/servicio → ignorar
            WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('=== RESERVA_SERVICIO: ' || v_count || ' líneas cargadas ===');
END;
/

-- =============================================================================
-- BLOQUE 4: RESEÑAS
-- FIX #24: INSERT con GROUP BY garantiza máximo UNA fila por (id_cliente, id_alojamiento).
-- Esto respeta el UNIQUE uk_resena_cli_aloj del DDL.
-- Solo de reservas COMPLETADAS (regla de negocio sección 1.6).
-- =============================================================================
INSERT INTO RESENA (id_alojamiento, id_cliente, id_reserva, calificacion, comentario, fecha_resena)
SELECT
    sub.id_alojamiento,
    sub.id_cliente,
    sub.id_reserva,    -- reserva más reciente completada en ese alojamiento
    sub.calificacion,
    sub.comentario,
    sub.fecha_resena
FROM (
    SELECT
        h.id_alojamiento,
        r.id_cliente,
        -- En caso de múltiples reservas completadas en el mismo alojamiento,
        -- tomamos la más reciente (MAX id_reserva) para la reseña.
        MAX(r.id_reserva) KEEP (DENSE_RANK LAST ORDER BY r.id_reserva) AS id_reserva,
        TRUNC(DBMS_RANDOM.VALUE(1, 6))                                  AS calificacion,
        CASE TRUNC(DBMS_RANDOM.VALUE(0, 5))
            WHEN 0 THEN 'Excelente experiencia, el paisaje cafetero es único.'
            WHEN 1 THEN 'Muy buena atención, volvería sin dudarlo.'
            WHEN 2 THEN 'Las instalaciones son cómodas y limpias.'
            WHEN 3 THEN 'Buena relación calidad-precio para el Quindío.'
            ELSE        'Lugar tranquilo, ideal para desconectarse.'
        END                                                             AS comentario,
        MAX(r.fecha_checkout) + TRUNC(DBMS_RANDOM.VALUE(1, 5))        AS fecha_resena
    FROM  RESERVA            r
    JOIN  RESERVA_HABITACION rh ON rh.id_reserva   = r.id_reserva
    JOIN  HABITACION         h  ON h.id_habitacion = rh.id_habitacion
    WHERE r.estado = 'COMPLETADA'
      AND DBMS_RANDOM.VALUE(0,1) < 0.50   -- ~50% de estadías completadas dejan reseña
    GROUP BY h.id_alojamiento, r.id_cliente
) sub;

COMMIT;

-- =============================================================================
-- BLOQUE 5: Refresco de vista materializada
-- =============================================================================
BEGIN
    DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL_MUNICIPIO', 'C');
    DBMS_OUTPUT.PUT_LINE('Vista materializada refrescada correctamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('AVISO: No se pudo refrescar MV - ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Ejecutar manualmente: EXEC DBMS_MVIEW.REFRESH(''MV_OCUPACION_MENSUAL_MUNICIPIO'',''C'');');
END;
/

-- =============================================================================
-- VERIFICACIÓN FINAL
-- =============================================================================
PROMPT
PROMPT ╔══════════════════════════════════════╗
PROMPT   CONTEOS FINALES DE VERIFICACIÓN
PROMPT ╚══════════════════════════════════════╝

SELECT 'MUNICIPIO'          AS nombre_tabla, COUNT(*) AS filas FROM MUNICIPIO
UNION ALL SELECT 'TIPO_ALOJAMIENTO',   COUNT(*) FROM TIPO_ALOJAMIENTO
UNION ALL SELECT 'ALOJAMIENTO',        COUNT(*) FROM ALOJAMIENTO
UNION ALL SELECT 'HABITACION',         COUNT(*) FROM HABITACION
UNION ALL SELECT 'TEMPORADA',          COUNT(*) FROM TEMPORADA
UNION ALL SELECT 'TARIFA',             COUNT(*) FROM TARIFA
UNION ALL SELECT 'CLIENTE',            COUNT(*) FROM CLIENTE
UNION ALL SELECT 'SERVICIO',           COUNT(*) FROM SERVICIO
UNION ALL SELECT 'RESERVA',            COUNT(*) FROM RESERVA
UNION ALL SELECT 'RESERVA_HABITACION', COUNT(*) FROM RESERVA_HABITACION
UNION ALL SELECT 'PAGO',               COUNT(*) FROM PAGO
UNION ALL SELECT 'RESERVA_SERVICIO',   COUNT(*) FROM RESERVA_SERVICIO
UNION ALL SELECT 'RESENA',             COUNT(*) FROM RESENA
UNION ALL SELECT 'USUARIO_SISTEMA',    COUNT(*) FROM USUARIO_SISTEMA
ORDER BY 1;

-- Verificar mínimos del enunciado
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM HABITACION)         >= 400   THEN 'OK' ELSE 'FALTA' END AS hab_400,
    CASE
        WHEN (SELECT COUNT(*) FROM RESERVA)            >= 25000 THEN 'OK' ELSE 'FALTA' END AS res_25k,
    CASE
        WHEN (SELECT COUNT(*) FROM RESERVA_HABITACION) >= 25000 THEN 'OK' ELSE 'FALTA' END AS reshab_25k,
    CASE
        WHEN (SELECT COUNT(*) FROM PAGO)               >= 25000 THEN 'OK' ELSE 'FALTA' END AS pago_25k,
    CASE
        WHEN (SELECT COUNT(*) FROM RESERVA_SERVICIO)   >= 40000 THEN 'OK' ELSE 'FALTA' END AS resserv_40k,
    CASE
        WHEN (SELECT COUNT(*) FROM CLIENTE)            >= 3000  THEN 'OK' ELSE 'FALTA' END AS cli_3k
FROM DUAL;

