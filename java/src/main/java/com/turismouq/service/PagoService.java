package com.turismouq.service;

import com.turismouq.dao.PagoDAO;
import com.turismouq.dto.PagoDTO;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Capa de servicio para pagos y cancelaciones.
 *
 * REGLA DE REEMBOLSO (única fuente de verdad — FIX duplicación):
 *   - Cancelación con más de 5 días de anticipación al check-in → 80 % de lo pagado.
 *   - Cancelación con 5 días o menos → sin reembolso.
 */
public class PagoService {

    private final PagoDAO pagoDAO = new PagoDAO();

    /** Calcula el monto de reembolso según la política de cancelación. */
    public BigDecimal calcularReembolso(long idReserva) throws SQLException {
        LocalDate checkin = pagoDAO.obtenerCheckin(idReserva);
        long diasRestantes = ChronoUnit.DAYS.between(LocalDate.now(), checkin);
        BigDecimal pagado  = pagoDAO.totalPagadoExitoso(idReserva);
        return diasRestantes > 5
                ? pagado.multiply(new BigDecimal("0.80"))
                : BigDecimal.ZERO;
    }

    /** Registra un abono exitoso sobre la reserva. */
    public void registrarAbono(long idReserva, BigDecimal monto, String metodo)
            throws SQLException {
        if (monto == null || monto.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("El monto del abono debe ser mayor a cero.");
        }
        pagoDAO.registrarPago(idReserva, monto, metodo);
    }

    /** Lista todos los pagos de una reserva. */
    public List<PagoDTO> listar(long idReserva) throws SQLException {
        return pagoDAO.listarPagos(idReserva);
    }

    /** Saldo pendiente = total reserva − total pagado exitoso. */
    public BigDecimal saldoPendiente(long idReserva) throws SQLException {
        return pagoDAO.totalReserva(idReserva)
                      .subtract(pagoDAO.totalPagadoExitoso(idReserva));
    }

    /**
     * Cancela la reserva aplicando la regla de reembolso.
     * El DAO recibe el monto ya calculado — no repite la lógica de negocio.
     */
    public void cancelar(long idReserva) throws SQLException {
        BigDecimal reembolso = calcularReembolso(idReserva);
        pagoDAO.cancelarConReembolso(idReserva, reembolso);
    }
}
