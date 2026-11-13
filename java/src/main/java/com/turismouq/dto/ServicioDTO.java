package com.turismouq.dto;

import java.math.BigDecimal;

/** Servicio complementario de un alojamiento (SERVICIO). */
public record ServicioDTO(
        long       id,
        long       idAlojamiento,
        String     alojamiento,
        String     nombre,
        String     descripcion,
        BigDecimal precio
) {}
