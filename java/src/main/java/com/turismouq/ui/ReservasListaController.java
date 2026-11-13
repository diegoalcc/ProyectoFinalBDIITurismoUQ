package com.turismouq.ui;

import com.turismouq.dao.ReservaDAO;
import com.turismouq.dto.ReservaDTO;
import javafx.beans.property.SimpleObjectProperty;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;

import java.time.LocalDate;
import java.util.List;

/**
 * Controlador de la pestaña "Consultar Reservas".
 * Permite buscar reservas con filtros opcionales de cliente, estado y alojamiento.
 */
public class ReservasListaController {

    @FXML private TextField tfFiltroCliente;
    @FXML private TextField tfFiltroAlojamiento;
    @FXML private ComboBox<String> cbFiltroEstado;
    @FXML private Label lblResultado;

    @FXML private TableView<ReservaDTO> tblReservas;
    @FXML private TableColumn<ReservaDTO, Long>      colId;
    @FXML private TableColumn<ReservaDTO, String>    colCliente;
    @FXML private TableColumn<ReservaDTO, LocalDate> colCheckin;
    @FXML private TableColumn<ReservaDTO, LocalDate> colCheckout;
    @FXML private TableColumn<ReservaDTO, String>    colEstado;
    @FXML private TableColumn<ReservaDTO, Long>      colIdCliente;

    private final ReservaDAO reservaDAO = new ReservaDAO();

    @FXML
    public void initialize() {
        cbFiltroEstado.setItems(FXCollections.observableArrayList(
                "TODOS", "PENDIENTE", "CONFIRMADA", "CANCELADA", "COMPLETADA"
        ));
        cbFiltroEstado.setValue("TODOS");

        // Vincular columnas al record ReservaDTO
        colId.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().id()));
        colIdCliente.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().idCliente()));
        colCliente.setCellValueFactory(c ->
                new SimpleStringProperty(c.getValue().cliente()));
        colCheckin.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().checkin()));
        colCheckout.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().checkout()));
        colEstado.setCellValueFactory(c ->
                new SimpleStringProperty(c.getValue().estado()));

        // Colorear filas según estado
        tblReservas.setRowFactory(tv -> new TableRow<>() {
            @Override
            protected void updateItem(ReservaDTO item, boolean empty) {
                super.updateItem(item, empty);
                if (item == null || empty) {
                    setStyle("");
                } else {
                    setStyle(switch (item.estado()) {
                        case "CONFIRMADA"  -> "-fx-background-color: #e6f4ea;";
                        case "COMPLETADA"  -> "-fx-background-color: #e8f0fe;";
                        case "CANCELADA"   -> "-fx-background-color: #fce8e6;";
                        case "PENDIENTE"   -> "-fx-background-color: #fef9e7;";
                        default -> "";
                    });
                }
            }
        });

        // Cargar todas las reservas al inicio
        buscar();
    }

    @FXML
    private void onBuscar() {
        buscar();
    }

    @FXML
    private void onLimpiar() {
        tfFiltroCliente.clear();
        tfFiltroAlojamiento.clear();
        cbFiltroEstado.setValue("TODOS");
        buscar();
    }

    private void buscar() {
        try {
            String cliente     = tfFiltroCliente.getText();
            String estado      = cbFiltroEstado.getValue();
            String alojamiento = tfFiltroAlojamiento.getText();

            List<ReservaDTO> lista = reservaDAO.listarReservas(cliente, estado, alojamiento);
            tblReservas.setItems(FXCollections.observableArrayList(lista));
            lblResultado.setText("Mostrando " + lista.size() + " reservas"
                    + (lista.size() == 300 ? " (límite 300 — refine el filtro)" : "."));
        } catch (Exception ex) {
            lblResultado.setText("Error al consultar: " + ex.getMessage());
        }
    }
}
