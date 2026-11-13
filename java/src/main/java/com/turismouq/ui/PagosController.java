package com.turismouq.ui;

import com.turismouq.dto.PagoDTO;
import com.turismouq.service.PagoService;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;

import java.math.BigDecimal;

public class PagosController {
    @FXML private TextField tfReserva;
    @FXML private TextField tfMonto;
    @FXML private ComboBox<String> cbMetodo;
    @FXML private Label lblInfo;
    @FXML private TableView<PagoDTO> tblPagos;
    @FXML private TableColumn<PagoDTO, Long> colId;
    @FXML private TableColumn<PagoDTO, String> colFecha;
    @FXML private TableColumn<PagoDTO, BigDecimal> colMonto;
    @FXML private TableColumn<PagoDTO, String> colMetodo;
    @FXML private TableColumn<PagoDTO, String> colEstado;

    private final PagoService pagoService = new PagoService();

    @FXML
    public void initialize() {
        cbMetodo.setItems(FXCollections.observableArrayList(
                "PSE", "TARJETA_CREDITO", "TARJETA_DEBITO", "TRANSFERENCIA", "EFECTIVO"
        ));
        colId.setCellValueFactory(c -> new javafx.beans.property.SimpleObjectProperty<>(c.getValue().id()));
        colFecha.setCellValueFactory(c -> new javafx.beans.property.SimpleStringProperty(c.getValue().fecha().toString()));
        colMonto.setCellValueFactory(c -> new javafx.beans.property.SimpleObjectProperty<>(c.getValue().monto()));
        colMetodo.setCellValueFactory(c -> new javafx.beans.property.SimpleStringProperty(c.getValue().metodo()));
        colEstado.setCellValueFactory(c -> new javafx.beans.property.SimpleStringProperty(c.getValue().estado()));
    }

    private long idReserva() {
        return Long.parseLong(tfReserva.getText().trim());
    }

    @FXML
    private void onConsultar() {
        try {
            long id = idReserva();
            BigDecimal saldo = pagoService.saldoPendiente(id);
            BigDecimal reembolso = pagoService.calcularReembolso(id);
            tblPagos.setItems(FXCollections.observableArrayList(pagoService.listar(id)));
            lblInfo.setText("Saldo pendiente: $" + saldo + " | Reembolso estimado si cancela hoy: $" + reembolso);
        } catch (Exception ex) {
            lblInfo.setText(ex.getMessage());
        }
    }

    @FXML
    private void onAbonar() {
        try {
            pagoService.registrarAbono(idReserva(), new BigDecimal(tfMonto.getText().trim()), cbMetodo.getValue());
            onConsultar();
        } catch (Exception ex) {
            lblInfo.setText(ex.getMessage());
        }
    }

    @FXML
    private void onCancelar() {
        try {
            pagoService.cancelar(idReserva());
            onConsultar();
            lblInfo.setText(lblInfo.getText() + " | Reserva cancelada.");
        } catch (Exception ex) {
            lblInfo.setText(ex.getMessage());
        }
    }
}
