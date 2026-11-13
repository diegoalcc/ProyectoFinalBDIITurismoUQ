package com.turismouq.ui;

import com.turismouq.dao.AnalyticsDAO;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;

import java.time.LocalDate;
import java.util.*;

public class DashboardController {

    // Tabla dinámica compartida por todas las consultas
    @FXML private TableView<Map<String, String>> tblDatos;
    @FXML private Label lblDash;

    // Controles exclusivos de C5 (parametrizada por fechas)
    @FXML private DatePicker dpDesde;
    @FXML private DatePicker dpHasta;

    private final AnalyticsDAO analyticsDAO = new AnalyticsDAO();

    @FXML
    public void initialize() {
        // Valores por defecto para el filtro de fechas de C5
        dpDesde.setValue(LocalDate.of(2025, 1, 1));
        dpHasta.setValue(LocalDate.of(2025, 12, 31));
    }

    // ---------------------------------------------------------------
    // C1: Ocupación por municipio y mes (PIVOT)
    // ---------------------------------------------------------------
    @FXML
    private void onC1() {
        cargar(AnalyticsDAO.C1_PIVOT,
               "C1 — Ocupación por municipio y mes (PIVOT)");
    }

    // ---------------------------------------------------------------
    // C2: Ingresos por municipio/tipo/temporada (ROLLUP + GROUPING)
    // ---------------------------------------------------------------
    @FXML
    private void onC2() {
        cargar(AnalyticsDAO.C2_ROLLUP,
               "C2 — Ingresos por municipio / tipo / temporada (ROLLUP)");
    }

    // ---------------------------------------------------------------
    // C3: Top 3 alojamientos por ingreso dentro de cada municipio (RANK)
    // ---------------------------------------------------------------
    @FXML
    private void onC3() {
        cargar(AnalyticsDAO.C3_RANK,
               "C3 — Top 3 alojamientos por municipio (RANK + PARTITION BY)");
    }

    // ---------------------------------------------------------------
    // C4: Variación de ingresos mes contra mes (LAG)
    // ---------------------------------------------------------------
    @FXML
    private void onC4() {
        cargar(AnalyticsDAO.C4_LAG,
               "C4 — Variación mensual de ingresos (LAG)");
    }

    // ---------------------------------------------------------------
    // C5: Reservas en rango de fechas — consulta parametrizada
    // Usa PreparedStatement con bind parameters (equivalente a las
    // VARIABLE de SQL*Plus, sección 1.3 del enunciado).
    // ---------------------------------------------------------------
    @FXML
    private void onC5() {
        LocalDate desde = dpDesde.getValue();
        LocalDate hasta = dpHasta.getValue();
        if (desde == null || hasta == null) {
            lblDash.setText("Seleccione ambas fechas para C5.");
            return;
        }
        if (hasta.isBefore(desde)) {
            lblDash.setText("La fecha 'hasta' debe ser posterior a 'desde'.");
            return;
        }
        try {
            List<Map<String, String>> rows = analyticsDAO.c5ReservasPorRango(desde, hasta);
            poblarTabla(rows);
            lblDash.setText("C5 — Reservas del " + desde + " al " + hasta
                    + " (parámetros bind) — " + rows.size() + " filas");
        } catch (Exception ex) {
            lblDash.setText("Error C5: " + ex.getMessage());
        }
    }

    // ---------------------------------------------------------------
    // C6: UNPIVOT — ingresos mensuales normalizados
    // ---------------------------------------------------------------
    @FXML
    private void onC6() {
        cargar(AnalyticsDAO.C6_UNPIVOT,
               "C6 — Ingresos mensuales por municipio (UNPIVOT)");
    }

    // ---------------------------------------------------------------
    // C7: Consulta libre — demanda + ingresos + reseñas por alojamiento
    // ---------------------------------------------------------------
    @FXML
    private void onC7() {
        try {
            List<Map<String, String>> rows = analyticsDAO.c7ResumenAlojamientos();
            poblarTabla(rows);
            lblDash.setText("C7 — Alojamientos: demanda + ingresos + calificación — "
                    + rows.size() + " filas");
        } catch (Exception ex) {
            lblDash.setText("Error C7: " + ex.getMessage());
        }
    }

    // ---------------------------------------------------------------
    // Utilidad: ejecuta SQL estático y puebla la tabla
    // ---------------------------------------------------------------
    private void cargar(String sql, String titulo) {
        try {
            List<Map<String, String>> rows = analyticsDAO.ejecutarConsulta(sql);
            poblarTabla(rows);
            lblDash.setText(titulo + " — " + rows.size() + " filas");
        } catch (Exception ex) {
            lblDash.setText("Error: " + ex.getMessage());
        }
    }

    // ---------------------------------------------------------------
    // Reconstruye las columnas de tblDatos dinámicamente
    // ---------------------------------------------------------------
    private void poblarTabla(List<Map<String, String>> rows) {
        tblDatos.getColumns().clear();
        tblDatos.getItems().clear();
        if (rows.isEmpty()) return;

        for (String key : rows.get(0).keySet()) {
            TableColumn<Map<String, String>, String> col = new TableColumn<>(key);
            col.setCellValueFactory(cell -> {
                String val = cell.getValue().get(key);
                return new SimpleStringProperty(val == null ? "" : val);
            });
            col.setPrefWidth(130);
            tblDatos.getColumns().add(col);
        }
        tblDatos.setItems(FXCollections.observableArrayList(rows));
    }
}
