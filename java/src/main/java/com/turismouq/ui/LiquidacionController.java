package com.turismouq.ui;

import com.turismouq.dao.LiquidacionDAO;
import com.turismouq.dto.LiquidacionDTO;
import javafx.beans.property.SimpleObjectProperty;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Liquidación mensual por alojamiento.
 * Ejecuta el mismo cálculo que el cursor c_liquidacion de PKG_TURISMOUQ
 * y lo muestra en una tabla con totales.
 */
public class LiquidacionController {

    @FXML private Spinner<Integer>   spMes;
    @FXML private Spinner<Integer>   spAnio;
    @FXML private Label              lblResumen;

    @FXML private TableView<LiquidacionDTO>              tblLiquidacion;
    @FXML private TableColumn<LiquidacionDTO, Long>      colAlojId;
    @FXML private TableColumn<LiquidacionDTO, String>    colAlojNombre;
    @FXML private TableColumn<LiquidacionDTO, String>    colMunicipio;
    @FXML private TableColumn<LiquidacionDTO, Long>      colReservas;
    @FXML private TableColumn<LiquidacionDTO, BigDecimal> colEstadias;
    @FXML private TableColumn<LiquidacionDTO, BigDecimal> colServicios;
    @FXML private TableColumn<LiquidacionDTO, BigDecimal> colTotal;

    private final LiquidacionDAO liquidacionDAO = new LiquidacionDAO();

    @FXML
    public void initialize() {
        spMes.setValueFactory(
                new SpinnerValueFactory.IntegerSpinnerValueFactory(1, 12,
                        LocalDate.now().getMonthValue()));
        spAnio.setValueFactory(
                new SpinnerValueFactory.IntegerSpinnerValueFactory(2020, 2099,
                        LocalDate.now().getYear()));

        colAlojId.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().idAlojamiento()));
        colAlojNombre.setCellValueFactory(c ->
                new SimpleStringProperty(c.getValue().alojamiento()));
        colMunicipio.setCellValueFactory(c ->
                new SimpleStringProperty(c.getValue().municipio()));
        colReservas.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().numReservas()));
        colEstadias.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().valorEstadias()));
        colServicios.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().valorServicios()));
        colTotal.setCellValueFactory(c ->
                new SimpleObjectProperty<>(c.getValue().total()));

        // Formato moneda en columnas de dinero
        formatearMoneda(colEstadias);
        formatearMoneda(colServicios);
        formatearMoneda(colTotal);
    }

    @FXML
    private void onLiquidar() {
        int mes  = spMes.getValue();
        int anio = spAnio.getValue();
        try {
            List<LiquidacionDTO> lista = liquidacionDAO.liquidar(mes, anio);
            tblLiquidacion.setItems(FXCollections.observableArrayList(lista));

            BigDecimal totalEstadias  = lista.stream()
                    .map(LiquidacionDTO::valorEstadias)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal totalServicios = lista.stream()
                    .map(LiquidacionDTO::valorServicios)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal totalGeneral   = totalEstadias.add(totalServicios);

            lblResumen.setText(String.format(
                    "Mes %02d/%d · %d alojamiento(s) con actividad · "
                    + "Estadías: $%,.0f · Servicios: $%,.0f · TOTAL: $%,.0f",
                    mes, anio, lista.size(),
                    totalEstadias, totalServicios, totalGeneral));
        } catch (Exception ex) {
            lblResumen.setText("Error: " + ex.getMessage());
        }
    }

    /** Formatea BigDecimal como moneda en la celda. */
    private void formatearMoneda(TableColumn<LiquidacionDTO, BigDecimal> col) {
        col.setCellFactory(tc -> new TableCell<>() {
            @Override
            protected void updateItem(BigDecimal item, boolean empty) {
                super.updateItem(item, empty);
                setText((empty || item == null) ? "" :
                        String.format("$%,.0f", item));
            }
        });
    }
}
