package com.turismouq.service;

import com.turismouq.dao.ReservaDAO;
import com.turismouq.dto.LineaHabitacionReservaDTO;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.List;

public class ReservaService {
    private final ReservaDAO reservaDAO = new ReservaDAO();

    public BigDecimal calcularEstadia(long idHabitacion, LocalDate in, LocalDate out) throws SQLException {
        return reservaDAO.calcularValorEstadia(idHabitacion, in, out);
    }

    public long crearReserva(long idCliente, List<LineaHabitacionReservaDTO> lineas) throws SQLException {
        return reservaDAO.crearReserva(idCliente, lineas);
    }
}
