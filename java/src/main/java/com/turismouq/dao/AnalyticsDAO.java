package com.turismouq.dao;

import com.turismouq.config.DatabaseConfig;

import java.sql.*;
import java.time.LocalDate;
import java.util.*;

public class AnalyticsDAO {

    // ------------------------------------------------------------------
    // Consulta genérica sin parámetros (C1, C2, C3, C4, C6)
    // ------------------------------------------------------------------
    public List<Map<String, String>> ejecutarConsulta(String sql) throws SQLException {
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            return mapear(rs);
        }
    }

    // ------------------------------------------------------------------
    // C5: reservas en rango de fechas (parametrizada con PreparedStatement)
    // Equivale a la consulta con VARIABLE/BIND en SQL*Plus pero en JDBC.
    // ------------------------------------------------------------------
    public List<Map<String, String>> c5ReservasPorRango(LocalDate desde, LocalDate hasta)
            throws SQLException {
        String sql = """
                SELECT r.id_reserva,
                       c.nombre          AS cliente,
                       c.documento_identidad,
                       a.nombre          AS alojamiento,
                       m.nombre          AS municipio,
                       r.fecha_checkin,
                       r.fecha_checkout,
                       r.estado,
                       (r.fecha_checkout - r.fecha_checkin) AS noches
                FROM RESERVA r
                JOIN CLIENTE             c  ON c.id_cliente     = r.id_cliente
                JOIN RESERVA_HABITACION  rh ON rh.id_reserva    = r.id_reserva
                JOIN HABITACION          h  ON h.id_habitacion  = rh.id_habitacion
                JOIN ALOJAMIENTO         a  ON a.id_alojamiento = h.id_alojamiento
                JOIN MUNICIPIO           m  ON m.id_municipio   = a.id_municipio
                WHERE r.fecha_checkin >= ?
                  AND r.fecha_checkout <= ?
                ORDER BY r.fecha_checkin, r.id_reserva
                FETCH FIRST 500 ROWS ONLY
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setDate(1, java.sql.Date.valueOf(desde));
            ps.setDate(2, java.sql.Date.valueOf(hasta));
            try (ResultSet rs = ps.executeQuery()) {
                return mapear(rs);
            }
        }
    }

    // ------------------------------------------------------------------
    // C7: consulta libre — alojamientos con mayor demanda, ingresos
    //     y calificación promedio de reseñas (combina todo el modelo)
    // ------------------------------------------------------------------
    public List<Map<String, String>> c7ResumenAlojamientos() throws SQLException {
        String sql = """
                WITH prom_res AS (
                    SELECT id_alojamiento,
                           ROUND(AVG(calificacion), 2) AS promedio_estrellas,
                           COUNT(*)                    AS total_resenas
                    FROM RESENA
                    GROUP BY id_alojamiento
                ),
                ing_aloj AS (
                    SELECT h.id_alojamiento,
                           ROUND(SUM(p.monto), 0) AS ingresos_acumulados
                    FROM ALOJAMIENTO         a
                    JOIN HABITACION          h  ON h.id_alojamiento = a.id_alojamiento
                    JOIN RESERVA_HABITACION  rh ON rh.id_habitacion = h.id_habitacion
                    JOIN RESERVA             r  ON r.id_reserva     = rh.id_reserva
                    JOIN PAGO                p  ON p.id_reserva     = r.id_reserva
                                               AND p.estado         = 'EXITOSO'
                    WHERE r.estado IN ('CONFIRMADA', 'COMPLETADA')
                    GROUP BY h.id_alojamiento
                ),
                res_comp AS (
                    SELECT h.id_alojamiento,
                           COUNT(DISTINCT r.id_reserva) AS reservas_completadas
                    FROM HABITACION          h
                    JOIN RESERVA_HABITACION  rh ON rh.id_habitacion = h.id_habitacion
                    JOIN RESERVA             r  ON r.id_reserva     = rh.id_reserva
                    WHERE r.estado = 'COMPLETADA'
                    GROUP BY h.id_alojamiento
                )
                SELECT m.nombre                               AS municipio,
                       a.nombre                              AS alojamiento,
                       ta.nombre                             AS tipo,
                       NVL(rc.reservas_completadas, 0)       AS reservas_completadas,
                       NVL(pr.promedio_estrellas, 0)         AS promedio_estrellas,
                       NVL(pr.total_resenas, 0)              AS total_resenas,
                       NVL(ia.ingresos_acumulados, 0)        AS ingresos_acumulados
                FROM ALOJAMIENTO        a
                JOIN MUNICIPIO          m  ON m.id_municipio           = a.id_municipio
                JOIN TIPO_ALOJAMIENTO   ta ON ta.id_tipo_alojamiento   = a.id_tipo_alojamiento
                LEFT JOIN res_comp      rc ON rc.id_alojamiento        = a.id_alojamiento
                LEFT JOIN ing_aloj      ia ON ia.id_alojamiento        = a.id_alojamiento
                LEFT JOIN prom_res      pr ON pr.id_alojamiento        = a.id_alojamiento
                WHERE NVL(rc.reservas_completadas, 0) > 0
                ORDER BY NVL(pr.promedio_estrellas, 0) DESC,
                         NVL(ia.ingresos_acumulados, 0) DESC
                FETCH FIRST 200 ROWS ONLY
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            return mapear(rs);
        }
    }

    // ------------------------------------------------------------------
    // Utilidad: mapea ResultSet → List<LinkedHashMap<col, valor>>
    // ------------------------------------------------------------------
    private List<Map<String, String>> mapear(ResultSet rs) throws SQLException {
        int cols = rs.getMetaData().getColumnCount();
        List<Map<String, String>> rows = new ArrayList<>();
        while (rs.next()) {
            Map<String, String> row = new LinkedHashMap<>();
            for (int c = 1; c <= cols; c++) {
                String label = rs.getMetaData().getColumnLabel(c);
                Object val = rs.getObject(c);
                row.put(label, val == null ? "" : val.toString());
            }
            rows.add(row);
        }
        return rows;
    }

    // ------------------------------------------------------------------
    // Constantes SQL para consultas sin parámetros
    // ------------------------------------------------------------------

    /** C1: Ocupación por municipio y mes — PIVOT */
    public static final String C1_PIVOT = """
            SELECT * FROM (
                SELECT m.nombre municipio,
                       TO_CHAR(rh.fecha_checkin,'MM') mes,
                       (rh.fecha_checkout - rh.fecha_checkin) noches
                FROM RESERVA_HABITACION rh
                JOIN HABITACION  h ON h.id_habitacion  = rh.id_habitacion
                JOIN ALOJAMIENTO a ON a.id_alojamiento = h.id_alojamiento
                JOIN MUNICIPIO   m ON m.id_municipio   = a.id_municipio
                JOIN RESERVA     r ON r.id_reserva     = rh.id_reserva
                WHERE r.estado IN ('CONFIRMADA','COMPLETADA')
            ) PIVOT (
                SUM(noches)
                FOR mes IN (
                    '01' ene,'02' feb,'03' mar,'04' abr,
                    '05' may,'06' jun,'07' jul,'08' ago,
                    '09' sep,'10' oct,'11' nov,'12' dic
                )
            )
            ORDER BY municipio
            """;

    /** C2: Ingresos por municipio/tipo/temporada — ROLLUP + GROUPING */
    public static final String C2_ROLLUP = """
            WITH noches AS (
                SELECT rh.id_habitacion,
                       (TRUNC(rh.fecha_checkin) + (n.n - 1)) dia
                FROM RESERVA_HABITACION rh
                JOIN RESERVA r ON r.id_reserva = rh.id_reserva
                JOIN (SELECT LEVEL n FROM DUAL CONNECT BY LEVEL <= 60) n
                  ON n.n <= (rh.fecha_checkout - rh.fecha_checkin)
                WHERE r.estado IN ('CONFIRMADA','COMPLETADA')
            ),
            val AS (
                SELECT m.nombre municipio, ta.nombre tipo,
                       (SELECT t.tipo_temporada
                        FROM TARIFA tf JOIN TEMPORADA t ON t.id_temporada = tf.id_temporada
                        WHERE tf.id_habitacion = n.id_habitacion
                          AND n.dia BETWEEN t.fecha_inicio AND t.fecha_fin
                        ORDER BY CASE t.tipo_temporada WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END
                        FETCH FIRST 1 ROW ONLY) temporada,
                       (SELECT tf.precio_noche
                        FROM TARIFA tf JOIN TEMPORADA t ON t.id_temporada = tf.id_temporada
                        WHERE tf.id_habitacion = n.id_habitacion
                          AND n.dia BETWEEN t.fecha_inicio AND t.fecha_fin
                        ORDER BY CASE t.tipo_temporada WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END
                        FETCH FIRST 1 ROW ONLY) valor
                FROM noches n
                JOIN HABITACION       h  ON h.id_habitacion       = n.id_habitacion
                JOIN ALOJAMIENTO      a  ON a.id_alojamiento      = h.id_alojamiento
                JOIN MUNICIPIO        m  ON m.id_municipio        = a.id_municipio
                JOIN TIPO_ALOJAMIENTO ta ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
            )
            SELECT CASE WHEN GROUPING(municipio)  = 1 THEN '=== TOTAL GENERAL ===' ELSE municipio  END AS municipio,
                   CASE WHEN GROUPING(tipo)        = 1 THEN '--- Subtotal ---'       ELSE tipo        END AS tipo,
                   CASE WHEN GROUPING(temporada)   = 1 THEN '--- Subtotal ---'       ELSE temporada   END AS temporada,
                   SUM(NVL(valor, 0)) AS ingresos
            FROM val
            GROUP BY ROLLUP(municipio, tipo, temporada)
            ORDER BY GROUPING(municipio), municipio,
                     GROUPING(tipo), tipo,
                     GROUPING(temporada), temporada
            """;

    /** C3: Top 3 alojamientos por ingreso en cada municipio — RANK + PARTITION BY */
    public static final String C3_RANK = """
            WITH ing AS (
                SELECT m.nombre municipio, a.nombre alojamiento,
                       SUM(p.monto) total
                FROM PAGO p
                JOIN RESERVA             r  ON r.id_reserva     = p.id_reserva
                JOIN RESERVA_HABITACION  rh ON rh.id_reserva    = r.id_reserva
                JOIN HABITACION          h  ON h.id_habitacion  = rh.id_habitacion
                JOIN ALOJAMIENTO         a  ON a.id_alojamiento = h.id_alojamiento
                JOIN MUNICIPIO           m  ON m.id_municipio   = a.id_municipio
                WHERE p.estado = 'EXITOSO'
                GROUP BY m.nombre, a.nombre
            ),
            rk AS (
                SELECT municipio, alojamiento, total,
                       RANK() OVER (PARTITION BY municipio ORDER BY total DESC) pos
                FROM ing
            )
            SELECT municipio, pos, alojamiento,
                   TO_CHAR(total, 'FM$999,999,999,990') AS total_ingresos
            FROM rk
            WHERE pos <= 3
            ORDER BY municipio, pos
            """;

    /** C4: Variación mensual de ingresos — LAG */
    public static final String C4_LAG = """
            WITH m AS (
                SELECT TO_CHAR(fecha_pago, 'YYYY-MM') periodo,
                       SUM(monto) ingreso
                FROM PAGO
                WHERE estado = 'EXITOSO'
                GROUP BY TO_CHAR(fecha_pago, 'YYYY-MM')
            )
            SELECT periodo,
                   TO_CHAR(ingreso,   'FM$999,999,999,990') AS ingreso_actual,
                   TO_CHAR(LAG(ingreso, 1, 0) OVER (ORDER BY periodo), 'FM$999,999,999,990') AS ingreso_anterior,
                   TO_CHAR(ingreso - LAG(ingreso, 1, 0) OVER (ORDER BY periodo), 'FM$999,999,999,990') AS variacion,
                   ROUND(
                       (ingreso - LAG(ingreso, 1, 0) OVER (ORDER BY periodo))
                       / NULLIF(LAG(ingreso, 1, 0) OVER (ORDER BY periodo), 0) * 100,
                       2
                   ) AS variacion_pct
            FROM m
            ORDER BY periodo
            """;

    /** C6: UNPIVOT — ingresos mensuales normalizados por municipio */
    public static final String C6_UNPIVOT = """
            WITH c AS (
                SELECT * FROM (
                    SELECT m.nombre municipio, TO_CHAR(p.fecha_pago,'MM') mes, p.monto
                    FROM PAGO p
                    JOIN RESERVA             r  ON r.id_reserva     = p.id_reserva
                    JOIN RESERVA_HABITACION  rh ON rh.id_reserva    = r.id_reserva
                    JOIN HABITACION          h  ON h.id_habitacion  = rh.id_habitacion
                    JOIN ALOJAMIENTO         a  ON a.id_alojamiento = h.id_alojamiento
                    JOIN MUNICIPIO           m  ON m.id_municipio   = a.id_municipio
                    WHERE p.estado = 'EXITOSO'
                      AND EXTRACT(YEAR FROM p.fecha_pago) = 2025
                ) PIVOT (SUM(monto) FOR mes IN (
                    '01' ene, '02' feb, '03' mar, '04' abr,
                    '05' may, '06' jun
                ))
            )
            SELECT municipio, mes_nombre,
                   TO_CHAR(NVL(total_ingreso, 0), 'FM$999,999,999,990') AS total_ingreso
            FROM c
            UNPIVOT (total_ingreso FOR mes_nombre IN (
                ene AS 'Enero', feb AS 'Febrero', mar AS 'Marzo',
                abr AS 'Abril', may AS 'Mayo', jun AS 'Junio'
            ))
            ORDER BY municipio, mes_nombre
            """;
}
