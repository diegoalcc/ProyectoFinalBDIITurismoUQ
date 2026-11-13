package com.turismouq.dao;

import com.turismouq.config.DatabaseConfig;
import com.turismouq.dto.AuditoriaDTO;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/** Acceso de solo lectura a AUDITORIA_TARIFA. */
public class AuditoriaDAO {

    public List<AuditoriaDTO> listar(String filtroUsuario,
                                     String filtroOperacion,
                                     Long   filtroHabitacion) throws SQLException {
        StringBuilder sql = new StringBuilder("""
                SELECT id_auditoria, usuario_bd, fecha_evento, tipo_operacion,
                       NVL(id_tarifa,    0) id_tarifa,
                       NVL(id_habitacion,0) id_habitacion,
                       NVL(id_temporada, 0) id_temporada,
                       precio_anterior, precio_nuevo
                FROM AUDITORIA_TARIFA
                WHERE 1=1
                """);
        List<Object> params = new ArrayList<>();

        if (filtroUsuario != null && !filtroUsuario.isBlank()) {
            sql.append(" AND UPPER(usuario_bd) LIKE UPPER(?)");
            params.add("%" + filtroUsuario.trim() + "%");
        }
        if (filtroOperacion != null && !filtroOperacion.isBlank()
                && !filtroOperacion.equals("TODAS")) {
            sql.append(" AND tipo_operacion = ?");
            params.add(filtroOperacion.trim());
        }
        if (filtroHabitacion != null && filtroHabitacion > 0) {
            sql.append(" AND id_habitacion = ?");
            params.add(filtroHabitacion);
        }
        sql.append(" ORDER BY fecha_evento DESC FETCH FIRST 500 ROWS ONLY");

        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            try (ResultSet rs = ps.executeQuery()) {
                List<AuditoriaDTO> out = new ArrayList<>();
                while (rs.next()) {
                    Timestamp ts = rs.getTimestamp("fecha_evento");
                    out.add(new AuditoriaDTO(
                            rs.getLong("id_auditoria"),
                            rs.getString("usuario_bd"),
                            ts == null ? null : ts.toLocalDateTime(),
                            rs.getString("tipo_operacion"),
                            rs.getLong("id_tarifa"),
                            rs.getLong("id_habitacion"),
                            rs.getLong("id_temporada"),
                            rs.getBigDecimal("precio_anterior"),
                            rs.getBigDecimal("precio_nuevo")
                    ));
                }
                return out;
            }
        }
    }

    /** Total de registros en la tabla de auditoría. */
    public long contarTotal() throws SQLException {
        String sql = "SELECT COUNT(*) FROM AUDITORIA_TARIFA";
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            rs.next();
            return rs.getLong(1);
        }
    }
}
