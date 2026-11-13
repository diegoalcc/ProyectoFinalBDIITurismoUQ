package com.turismouq.dao;

import com.turismouq.config.DatabaseConfig;
import com.turismouq.dto.ServicioDTO;

import java.math.BigDecimal;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class ServicioDAO {

    // ------------------------------------------------------------------
    // Listar servicios disponibles en un alojamiento
    // ------------------------------------------------------------------
    public List<ServicioDTO> listarPorAlojamiento(long idAlojamiento) throws SQLException {
        String sql = """
                SELECT s.id_servicio, s.id_alojamiento, a.nombre AS alojamiento,
                       s.nombre, s.descripcion, s.precio
                FROM   SERVICIO s
                JOIN   ALOJAMIENTO a ON a.id_alojamiento = s.id_alojamiento
                WHERE  s.id_alojamiento = ?
                ORDER BY s.nombre
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idAlojamiento);
            return mapear(ps.executeQuery());
        }
    }

    // ------------------------------------------------------------------
    // Listar servicios ya contratados en una reserva
    // ------------------------------------------------------------------
    public List<ServicioDTO> listarPorReserva(long idReserva) throws SQLException {
        String sql = """
                SELECT s.id_servicio, s.id_alojamiento, a.nombre AS alojamiento,
                       s.nombre,
                       rs.cantidad || ' unidad(es) × $' ||
                           TO_CHAR(rs.precio_unitario,'FM999,999,990') AS descripcion,
                       rs.cantidad * rs.precio_unitario AS precio
                FROM   RESERVA_SERVICIO rs
                JOIN   SERVICIO     s ON s.id_servicio    = rs.id_servicio
                JOIN   ALOJAMIENTO  a ON a.id_alojamiento = s.id_alojamiento
                WHERE  rs.id_reserva = ?
                ORDER BY s.nombre
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idReserva);
            return mapear(ps.executeQuery());
        }
    }

    // ------------------------------------------------------------------
    // Agregar (o aumentar cantidad de) un servicio a una reserva.
    // Respeta UNIQUE(id_reserva, id_servicio): hace UPSERT con MERGE.
    // ------------------------------------------------------------------
    public void agregarServicio(long idReserva, long idServicio,
                                int cantidad, BigDecimal precioUnitario) throws SQLException {
        String sql = """
                MERGE INTO RESERVA_SERVICIO rs
                USING (SELECT ? id_reserva, ? id_servicio FROM DUAL) src
                ON (rs.id_reserva = src.id_reserva AND rs.id_servicio = src.id_servicio)
                WHEN MATCHED THEN
                    UPDATE SET rs.cantidad        = rs.cantidad + ?,
                               rs.precio_unitario = ?
                WHEN NOT MATCHED THEN
                    INSERT (id_reserva, id_servicio, cantidad, precio_unitario)
                    VALUES (?, ?, ?, ?)
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idReserva);
            ps.setLong(2, idServicio);
            ps.setInt(3, cantidad);
            ps.setBigDecimal(4, precioUnitario);
            ps.setLong(5, idReserva);
            ps.setLong(6, idServicio);
            ps.setInt(7, cantidad);
            ps.setBigDecimal(8, precioUnitario);
            ps.executeUpdate();
        }
    }

    // ------------------------------------------------------------------
    // Eliminar un servicio de una reserva
    // ------------------------------------------------------------------
    public void quitarServicio(long idReserva, long idServicio) throws SQLException {
        String sql = "DELETE FROM RESERVA_SERVICIO WHERE id_reserva = ? AND id_servicio = ?";
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idReserva);
            ps.setLong(2, idServicio);
            ps.executeUpdate();
        }
    }

    // ------------------------------------------------------------------
    // Obtener el precio unitario vigente de un servicio
    // ------------------------------------------------------------------
    public BigDecimal obtenerPrecio(long idServicio) throws SQLException {
        String sql = "SELECT precio FROM SERVICIO WHERE id_servicio = ?";
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idServicio);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) throw new SQLException("Servicio no encontrado: " + idServicio);
                return rs.getBigDecimal(1);
            }
        }
    }

    // ------------------------------------------------------------------
    // Utilidad interna
    // ------------------------------------------------------------------
    private List<ServicioDTO> mapear(ResultSet rs) throws SQLException {
        List<ServicioDTO> out = new ArrayList<>();
        while (rs.next()) {
            out.add(new ServicioDTO(
                    rs.getLong("id_servicio"),
                    rs.getLong("id_alojamiento"),
                    rs.getString("alojamiento"),
                    rs.getString("nombre"),
                    rs.getString("descripcion"),
                    rs.getBigDecimal("precio")
            ));
        }
        rs.close();
        return out;
    }
}
