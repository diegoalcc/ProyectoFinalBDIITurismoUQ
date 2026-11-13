package com.turismouq.dto;

import java.time.LocalDate;

public record LineaHabitacionReservaDTO(
        long idHabitacion,
        LocalDate checkin,
        LocalDate checkout,
        int huespedes
) {
}
