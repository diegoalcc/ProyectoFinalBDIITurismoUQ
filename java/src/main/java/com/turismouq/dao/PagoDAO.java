package com.turismouq.dao;

import com.turismouq.config.DatabaseConfig;
import com.turismouq.dto.PagoDTO;

import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class PagoDAO {

    // ------------------------------------------------------------------
    // Total pagado con estado EXITOSO para una reserva
    // ------------------------------------------------------------------
    public BigDecimal totalPagadoExitoso(long idReserva) throws SQLException {
        String sql = """
                SELECT NVL(SUM(monto), 0)
                FROM   PAGO
                WHERE  id_reserva = ? AND estado = 'EXITOSO'
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idReserva);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getBigDecimal(1);
            }
        }
    }

    // ------------------------------------------------------------------
    // Valor total de la reserva (estadías por tarifa + servicios)
    // ------------------------------------------------------------------
    public BigDecimal totalReserva(long idReserva) throws SQLException {
        String sql = """
                SELECT
                    NVL((
                        SELECT SUM(
                            PKG_TURISMOUQ.fn_valor_estadia(
                                rh.id_habitacion,
                                rh.fecha_checkin,
                                rh.fecha_checkout)
                        )
                        FROM RESERVA_HABITACION rh
                        WHERE rh.id_reserva = ?
                    ), 0)
                    + NVL((
                        SELECT SUM(cantidad * precio_unitario)
                        FROM   RESERVA_SERVICIO
                        WHERE  id_reserva = ?
                    ), 0) AS total
                FROM DUAL
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idReserva);
            ps.setLong(2, idReserva);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getBigDecimal(1);
            }
        }
    }

    // ------------------------------------------------------------------
    // Registrar un pago exitoso
    // ------------------------------------------------------------------
    public void registrarPago(long idReserva, BigDecimal monto, String metodo)
            throws SQLException {
        String sql = """
                INSERT INTO PAGO (id_reserva, fecha_pago, monto, metodo, estado)
                VALUES (?, SYSDATE, ?, ?, 'EXITOSO')
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idReserva);
            ps.setBigDecimal(2, monto);
            ps.setString(3, metodo);
            ps.executeUpdate();
        }
    }

    // ------------------------------------------------------------------
    // Listar pagos de una reserva
    // ------------------------------------------------------------------
    public List<PagoDTO> listarPagos(long idReserva) throws SQLException {
        String sql = """
                SELECT id_pago, id_reserva, fecha_pago, monto, metodo, estado
                FROM   PAGO
                WHERE  id_reserva = ?
                ORDER BY fecha_pago
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idReserva);
            try (ResultSet rs = ps.executeQuery()) {
                List<PagoDTO> out = new ArrayList<>();
                while (rs.next()) {
                    out.add(new PagoDTO(
                            rs.getLong(1),
                            rs.getLong(2),
                            rs.getDate(3).toLocalDate(),
                            rs.getBigDecimal(4),
                            rs.getString(5),
                            rs.getString(6)
                    ));
                }
                return out;
            }
        }
    }

    // ------------------------------------------------------------------
    // Fecha de check-in de una reserva (para calcular reembolso)
    // ------------------------------------------------------------------
    public LocalDate obtenerCheckin(long idReserva) throws SQLException {
        String sql = "SELECT fecha_checkin FROM RESERVA WHERE id_reserva = ?";
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idReserva);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) throw new SQLException("Reserva no encontrada: " + idReserva);
                return rs.getDate(1).toLocalDate();
            }
        }
    }

    // ------------------------------------------------------------------
    // Cancelar reserva con reembolso.
    //
    // FIX (duplicación eliminada): la lógica "80 % si > 5 días" ya existe
    // en PagoService.calcularReembolso. Aquí solo recibe el monto ya
    // calculado por la capa de servicio y ejecuta la transacción JDBC.
    // ------------------------------------------------------------------
    public void cancelarConReembolso(long idReserva, BigDecimal montoReembolso)
            throws SQLException {
        try (Connection cn = DatabaseConfig.getConnection()) {
            cn.setAutoCommit(false);
            try {
                // 1) Cambiar estado de la reserva
                try (PreparedStatement ps = cn.prepareStatement(
                        "UPDATE RESERVA SET estado = 'CANCELADA' WHERE id_reserva = ?")) {
                    ps.setLong(1, idReserva);
                    ps.executeUpdate();
                }
                // 2) Registrar reembolso si aplica
                if (montoReembolso.compareTo(BigDecimal.ZERO) > 0) {
                    try (PreparedStatement ps = cn.prepareStatement("""
                            INSERT INTO PAGO (id_reserva, fecha_pago, monto, metodo, estado)
                            VALUES (?, SYSDATE, ?, 'TRANSFERENCIA', 'REEMBOLSADO')
                            """)) {
                        ps.setLong(1, idReserva);
                        ps.setBigDecimal(2, montoReembolso);
                        ps.executeUpdate();
                    }
                }
                cn.commit();
            } catch (SQLException ex) {
                cn.rollback();
                throw ex;
            }
        }
    }
}
