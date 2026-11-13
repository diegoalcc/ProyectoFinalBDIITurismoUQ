package com.turismouq.dao;

import com.turismouq.config.DatabaseConfig;
import com.turismouq.dto.LineaHabitacionReservaDTO;
import com.turismouq.dto.ReservaDTO;
import oracle.jdbc.OracleConnection;

import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class ReservaDAO {

    public BigDecimal calcularValorEstadia(long idHabitacion, LocalDate in, LocalDate out) throws SQLException {
        String sql = "{ ? = call PKG_TURISMOUQ.fn_valor_estadia(?, ?, ?) }";
        try (Connection cn = DatabaseConfig.getConnection();
             CallableStatement cs = cn.prepareCall(sql)) {
            cs.registerOutParameter(1, Types.NUMERIC);
            cs.setLong(2, idHabitacion);
            cs.setDate(3, Date.valueOf(in));
            cs.setDate(4, Date.valueOf(out));
            cs.execute();
            return cs.getBigDecimal(1);
        }
    }

    // ------------------------------------------------------------------
    // Listar reservas con filtros opcionales (cliente, estado, alojamiento)
    // ------------------------------------------------------------------
    public List<ReservaDTO> listarReservas(String filtroCliente, String filtroEstado,
                                           String filtroAlojamiento) throws SQLException {
        StringBuilder sql = new StringBuilder("""
                SELECT DISTINCT r.id_reserva, r.id_cliente, c.nombre AS cliente,
                       r.fecha_checkin, r.fecha_checkout, r.estado
                FROM RESERVA r
                JOIN CLIENTE c ON c.id_cliente = r.id_cliente
                JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
                JOIN HABITACION h ON h.id_habitacion = rh.id_habitacion
                JOIN ALOJAMIENTO a ON a.id_alojamiento = h.id_alojamiento
                WHERE 1=1
                """);
        List<Object> params = new ArrayList<>();

        if (filtroCliente != null && !filtroCliente.isBlank()) {
            sql.append(" AND (UPPER(c.nombre) LIKE UPPER(?) OR c.documento_identidad LIKE ?)");
            params.add("%" + filtroCliente.trim() + "%");
            params.add("%" + filtroCliente.trim() + "%");
        }
        if (filtroEstado != null && !filtroEstado.isBlank() && !filtroEstado.equals("TODOS")) {
            sql.append(" AND r.estado = ?");
            params.add(filtroEstado.trim());
        }
        if (filtroAlojamiento != null && !filtroAlojamiento.isBlank()) {
            sql.append(" AND UPPER(a.nombre) LIKE UPPER(?)");
            params.add("%" + filtroAlojamiento.trim() + "%");
        }
        sql.append(" ORDER BY r.id_reserva DESC FETCH FIRST 300 ROWS ONLY");

        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                List<ReservaDTO> out = new ArrayList<>();
                while (rs.next()) {
                    out.add(new ReservaDTO(
                            rs.getLong("id_reserva"),
                            rs.getLong("id_cliente"),
                            rs.getString("cliente"),
                            rs.getDate("fecha_checkin").toLocalDate(),
                            rs.getDate("fecha_checkout").toLocalDate(),
                            rs.getString("estado")
                    ));
                }
                return out;
            }
        }
    }

    // ------------------------------------------------------------------
    // Obtener el id_alojamiento de la primera habitación de una reserva
    // (usado por ServiciosController para filtrar servicios disponibles)
    // ------------------------------------------------------------------
    public long obtenerIdAlojamiento(long idReserva) throws SQLException {
        String sql = """
                SELECT h.id_alojamiento
                FROM   RESERVA_HABITACION rh
                JOIN   HABITACION h ON h.id_habitacion = rh.id_habitacion
                WHERE  rh.id_reserva = ?
                FETCH FIRST 1 ROW ONLY
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idReserva);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return -1L;
                return rs.getLong(1);
            }
        }
    }

    public long crearReserva(long idCliente, List<LineaHabitacionReservaDTO> lineas) throws SQLException {
        String sql = "{ call PKG_TURISMOUQ.sp_crear_reserva(?, ?, ?, ?) }";
        try (Connection cn = DatabaseConfig.getConnection()) {
            OracleConnection ocn = cn.unwrap(OracleConnection.class);
            Object[] structs = new Object[lineas.size()];
            for (int i = 0; i < lineas.size(); i++) {
                LineaHabitacionReservaDTO l = lineas.get(i);
                Object[] attrs = new Object[]{
                        l.idHabitacion(),
                        Date.valueOf(l.checkin()),
                        Date.valueOf(l.checkout()),
                        l.huespedes()
                };
                structs[i] = ocn.createStruct("T_LINEA_HABITACION_RESERVA", attrs);
            }
            try (CallableStatement cs = cn.prepareCall(sql)) {
                cs.setLong(1, idCliente);
                cs.setArray(2, ocn.createOracleArray("T_LISTA_LINEAS_HABITACION", structs));
                cs.setString(3, "CONFIRMADA");
                cs.registerOutParameter(4, Types.NUMERIC);
                cs.execute();
                return cs.getLong(4);
            }
        }
    }
}
