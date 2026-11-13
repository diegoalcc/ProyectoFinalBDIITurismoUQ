package com.turismouq.dao;

import com.turismouq.config.DatabaseConfig;
import com.turismouq.dto.AlojamientoDTO;
import com.turismouq.dto.ClienteDTO;
import com.turismouq.dto.HabitacionDTO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public class CatalogoDAO {

    public List<String> listarMunicipios() throws SQLException {
        String sql = "SELECT nombre FROM MUNICIPIO ORDER BY nombre";
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            List<String> out = new ArrayList<>();
            while (rs.next()) {
                out.add(rs.getString(1));
            }
            return out;
        }
    }

    public List<AlojamientoDTO> listarAlojamientosPorMunicipio(String municipio) throws SQLException {
        String sql = """
                SELECT a.id_alojamiento, a.nombre, m.id_municipio, m.nombre, ta.nombre
                FROM ALOJAMIENTO a
                JOIN MUNICIPIO m ON m.id_municipio = a.id_municipio
                JOIN TIPO_ALOJAMIENTO ta ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
                WHERE m.nombre = ?
                ORDER BY a.nombre
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setString(1, municipio);
            try (ResultSet rs = ps.executeQuery()) {
                List<AlojamientoDTO> out = new ArrayList<>();
                while (rs.next()) {
                    out.add(new AlojamientoDTO(
                            rs.getLong(1), rs.getString(2), rs.getLong(3), rs.getString(4), rs.getString(5)
                    ));
                }
                return out;
            }
        }
    }

    public List<HabitacionDTO> listarHabitaciones(long idAlojamiento) throws SQLException {
        String sql = """
                SELECT id_habitacion, id_alojamiento, numero_habitacion, capacidad, tipo
                FROM HABITACION
                WHERE id_alojamiento = ?
                ORDER BY numero_habitacion
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setLong(1, idAlojamiento);
            try (ResultSet rs = ps.executeQuery()) {
                List<HabitacionDTO> out = new ArrayList<>();
                while (rs.next()) {
                    out.add(new HabitacionDTO(
                            rs.getLong(1), rs.getLong(2), rs.getString(3), rs.getInt(4), rs.getString(5)
                    ));
                }
                return out;
            }
        }
    }

    public List<ClienteDTO> listarClientes(int limite) throws SQLException {
        String sql = """
                SELECT id_cliente, nombre, documento_identidad, email, ciudad_origen
                FROM CLIENTE
                WHERE ROWNUM <= ?
                ORDER BY id_cliente
                """;
        try (Connection cn = DatabaseConfig.getConnection();
             PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setInt(1, limite);
            try (ResultSet rs = ps.executeQuery()) {
                List<ClienteDTO> out = new ArrayList<>();
                while (rs.next()) {
                    out.add(new ClienteDTO(
                            rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4), rs.getString(5)
                    ));
                }
                return out;
            }
        }
    }
}
