package com.turismouq.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** Registro de cambio de tarifa desde AUDITORIA_TARIFA. */
public record AuditoriaDTO(
        long           id,
        String         usuarioBd,
        LocalDateTime  fechaEvento,
        String         tipoOperacion,
        long           idTarifa,
        long           idHabitacion,
        long           idTemporada,
        BigDecimal     precioAnterior,
        BigDecimal     precioNuevo
) {}
