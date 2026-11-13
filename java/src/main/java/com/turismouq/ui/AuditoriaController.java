package com.turismouq.ui;

import com.turismouq.dao.AuditoriaDAO;
import com.turismouq.dto.AuditoriaDTO;
import javafx.beans.property.SimpleObjectProperty;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Pestaña de auditoría de tarifas.
 * Muestra el historial de cambios registrados por trg_tarifa_auditoria
 * con filtros opcionales de usuario, operación e ID de habitación.
 */
public class AuditoriaController {

    @FXML private TextField            tfFiltroUsuario;
    @FXML private ComboBox<String>     cbFiltroOperacion;
    @FXML private TextField            tfFiltroHabitacion;
    @FXML private Label                lblConteo;

    @FXML private TableView<AuditoriaDTO>                    tblAuditoria;
    @FXML private TableColumn<AuditoriaDTO, Long>            colId;
    @FXML private TableColumn<AuditoriaDTO, String>          colUsuario;
    @FXML private TableColumn<AuditoriaDTO, LocalDateTime>   colFecha;
    @FXML private TableColumn<AuditoriaDTO, String>          colOperacion;
    @FXML private TableColumn<AuditoriaDTO, Long>            colTarifa;
    @FXML private TableColumn<AuditoriaDTO, Long>            colHabitacion;
    @FXML private TableColumn<AuditoriaDTO, Long>            colTemporada;
    @FXML private TableColumn<AuditoriaDTO, BigDecimal>      colAnterior;
    @FXML private TableColumn<AuditoriaDTO, BigDecimal>      colNuevo;

    private final AuditoriaDAO auditoriaDAO = new AuditoriaDAO();

    @FXML
    public void initialize() {
        cbFiltroOperacion.setItems(FXCollections.observableArrayList(
                "TODAS", "INSERT", "UPDATE", "DELETE"));
        cbFiltroOperacion.setValue("TODAS");

        // Vincular columnas
        colId.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().id()));
        colUsuario.setCellValueFactory(c ->
                new SimpleStringProperty(c.getValue().usuarioBd()));
        colFecha.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().fechaEvento()));
        colOperacion.setCellValueFactory(c ->
                new SimpleStringProperty(c.getValue().tipoOperacion()));
        colTarifa.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().idTarifa()));
        colHabitacion.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().idHabitacion()));
        colTemporada.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().idTemporada()));
        colAnterior.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().precioAnterior()));
        colNuevo.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().precioNuevo()));

        // Formato moneda en columnas de precio
        formatearMoneda(colAnterior);
        formatearMoneda(colNuevo);

        // Colorear filas: INSERT=verde suave, UPDATE=azul suave, DELETE=rojo suave
        tblAuditoria.setRowFactory(tv -> new TableRow<>() {
            @Override
            protected void updateItem(AuditoriaDTO item, boolean empty) {
                super.updateItem(item, empty);
                if (item == null || empty) {
                    setStyle("");
                } else {
                    setStyle(switch (item.tipoOperacion()) {
                        case "INSERT" -> "-fx-background-color:#e6f4ea;";
                        case "UPDATE" -> "-fx-background-color:#e8f0fe;";
                        case "DELETE" -> "-fx-background-color:#fce8e6;";
                        default -> "";
                    });
                }
            }
        });

        // Cargar todos los registros al abrir la pestaña
        buscar();
    }

    @FXML
    private void onBuscar() {
        buscar();
    }

    @FXML
    private void onLimpiar() {
        tfFiltroUsuario.clear();
        cbFiltroOperacion.setValue("TODAS");
        tfFiltroHabitacion.clear();
        buscar();
    }

    private void buscar() {
        String usuario    = tfFiltroUsuario.getText();
        String operacion  = cbFiltroOperacion.getValue();
        Long   habitacion = null;

        String rawHab = tfFiltroHabitacion.getText().trim();
        if (!rawHab.isBlank()) {
            try {
                habitacion = Long.parseLong(rawHab);
            } catch (NumberFormatException e) {
                lblConteo.setText("ID de habitación inválido — debe ser numérico.");
                return;
            }
        }

        try {
            List<AuditoriaDTO> lista = auditoriaDAO.listar(usuario, operacion, habitacion);
            tblAuditoria.setItems(FXCollections.observableArrayList(lista));

            long total = auditoriaDAO.contarTotal();
            lblConteo.setText(lista.size() + " registro(s) mostrado(s) "
                    + "(total en tabla: " + total + ")"
                    + (lista.size() == 500 ? " — límite 500, refine el filtro" : ""));
        } catch (Exception ex) {
            lblConteo.setText("Error al consultar: " + ex.getMessage());
        }
    }

    private void formatearMoneda(TableColumn<AuditoriaDTO, BigDecimal> col) {
        col.setCellFactory(tc -> new TableCell<>() {
            @Override
            protected void updateItem(BigDecimal item, boolean empty) {
                super.updateItem(item, empty);
                if (empty || item == null) {
                    setText("—");
                } else {
                    setText(String.format("$%,.0f", item));
                }
            }
        });
    }
}
