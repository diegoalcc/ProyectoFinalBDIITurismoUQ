package com.turismouq.dto;

import java.time.LocalDate;

public record ReservaDTO(
        long id,
        long idCliente,
        String cliente,
        LocalDate checkin,
        LocalDate checkout,
        String estado
) {
}
