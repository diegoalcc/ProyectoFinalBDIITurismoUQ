package com.turismouq.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PagoDTO(long id, long idReserva, LocalDate fecha, BigDecimal monto, String metodo, String estado) {
}
