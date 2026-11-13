package com.turismouq.dto;

import java.math.BigDecimal;

/** Fila del reporte de liquidación mensual por alojamiento. */
public record LiquidacionDTO(
        long       idAlojamiento,
        String     alojamiento,
        String     municipio,
        long       numReservas,
        BigDecimal valorEstadias,
        BigDecimal valorServicios,
        BigDecimal total          // valorEstadias + valorServicios
) {}
