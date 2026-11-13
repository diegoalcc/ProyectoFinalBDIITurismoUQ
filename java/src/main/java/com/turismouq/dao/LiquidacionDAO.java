package com.turismouq.dao;

import com.turismouq.config.DatabaseConfig;
import com.turismouq.dto.LiquidacionDTO;

import java.math.BigDecimal;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Ejecuta la liquidación mensual por alojamiento.
 * Replica en JDBC la lógica del cursor c_liquidacion del paquete PKG_TURISMOUQ,
 * devolviendo datos estructurados que la UI puede mostrar en una TableView.
 *
 * Se usa SQL puro (precio_noche_contratado × noches) para evitar llamar
 * fn_valor_estadia N veces dentro de la consulta, igual que en el paquete.
 */
public class LiquidacionDAO {

    public List<LiquidacionDTO> liquidar(int mes, int anio) throws SQLException {
        String sql = """
                SELECT a.id_alojamiento,
                       a.nombre                                          AS alojamiento,
                       m.nombre                                          AS municipio,
                       COUNT(DISTINCT r.id_reserva)                     AS num_reservas,
                       NVL(SUM(
                           rh.precio_noche_contratado
                           * (rh.fecha_checkout - rh.fecha_checkin)
                       ), 0)                                             AS valor_estadias,
                       NVL(SUM(rs.cantidad * rs.precio_unitario), 0)    AS valor_servicios
                FROM  ALOJAMIENTO         a
                JOIN  MUNICIPIO           m  ON m.id_municipio    = a.id_municipio
                JOIN  HABITACION          h  ON h.id_alojamiento  = a.id_alojamiento
                JOIN  RESERVA_HABITACION  rh ON rh.id_habitacion  = h.id_habitacion
                JOIN  RESERVA             r  ON r.id_reserva      = rh.id_reserva
                LEFT JOIN RESERVA_SERVICIO rs ON rs.id_reserva    = r.id_reserva
                WHERE r.estado IN ('CONFIRMADA','COMPLETADA')
                  AND EXTRACT(MONTH FROM rh.fecha_checkin) = ?
                  AND EXTRACT(YEAR  FROM rh.fecha_checkin) = ?
                GROUP BY a.id_alojamiento, a.nombre, m.nombre
                ORDER BY (NVL(SUM(rh.precio_noche_contratado
                              * (rh.fecha_checkout - rh.fecha_checkin)), 0)
                          + NVL(SUM(rs.cantidad * rs.precio_unitario), 0)) DESC
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setInt(1, mes);
            ps.setInt(2, anio);
            try (ResultSet rs = ps.executeQuery()) {
                List<LiquidacionDTO> out = new ArrayList<>();
                while (rs.next()) {
                    BigDecimal estadias  = rs.getBigDecimal("valor_estadias");
                    BigDecimal servicios = rs.getBigDecimal("valor_servicios");
                    out.add(new LiquidacionDTO(
                            rs.getLong("id_alojamiento"),
                            rs.getString("alojamiento"),
                            rs.getString("municipio"),
                            rs.getLong("num_reservas"),
                            estadias,
                            servicios,
                            estadias.add(servicios)
                    ));
                }
                return out;
            }
        }
    }
}
