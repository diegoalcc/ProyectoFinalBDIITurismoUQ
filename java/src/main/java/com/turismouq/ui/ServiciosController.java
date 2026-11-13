package com.turismouq.ui;

import com.turismouq.dao.ReservaDAO;
import com.turismouq.dao.ServicioDAO;
import com.turismouq.dto.ReservaDTO;
import com.turismouq.dto.ServicioDTO;
import javafx.beans.property.SimpleObjectProperty;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;

import java.math.BigDecimal;
import java.util.List;

/**
 * Gestión de servicios complementarios en una reserva.
 * Permite ver servicios disponibles del alojamiento, agregarlos a la reserva
 * y consultar los ya contratados.
 */
public class ServiciosController {

    /* ---- Controles de búsqueda de reserva ---- */
    @FXML private TextField  tfIdReserva;
    @FXML private Label      lblInfoReserva;

    /* ---- Tabla: servicios disponibles del alojamiento ---- */
    @FXML private TableView<ServicioDTO>              tblDisponibles;
    @FXML private TableColumn<ServicioDTO, Long>      colDispId;
    @FXML private TableColumn<ServicioDTO, String>    colDispNombre;
    @FXML private TableColumn<ServicioDTO, String>    colDispDesc;
    @FXML private TableColumn<ServicioDTO, BigDecimal> colDispPrecio;

    /* ---- Cantidad a agregar ---- */
    @FXML private Spinner<Integer> spCantidad;

    /* ---- Tabla: servicios ya contratados ---- */
    @FXML private TableView<ServicioDTO>              tblContratados;
    @FXML private TableColumn<ServicioDTO, Long>      colContId;
    @FXML private TableColumn<ServicioDTO, String>    colContNombre;
    @FXML private TableColumn<ServicioDTO, String>    colContDetalle;
    @FXML private TableColumn<ServicioDTO, BigDecimal> colContTotal;

    @FXML private Label lblMensaje;

    private final ServicioDAO servicioDAO = new ServicioDAO();
    private final ReservaDAO  reservaDAO  = new ReservaDAO();

    /** Alojamiento asociado a la reserva actual (para filtrar servicios). */
    private long idAlojamientoActual = -1;

    @FXML
    public void initialize() {
        spCantidad.setValueFactory(new SpinnerValueFactory.IntegerSpinnerValueFactory(1, 99, 1));

        // Columnas de disponibles
        colDispId.setCellValueFactory(c -> new SimpleObjectProperty<>(c.getValue().id()));
        colDispNombre.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().nombre()));
        colDispDesc.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().descripcion()));
        colDispPrecio.setCellValueFactory(c -> new SimpleObjectProperty<>(c.getValue().precio()));

        // Columnas de contratados
        colContId.setCellValueFactory(c -> new SimpleObjectProperty<>(c.getValue().id()));
        colContNombre.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().nombre()));
        colContDetalle.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().descripcion()));
        colContTotal.setCellValueFactory(c -> new SimpleObjectProperty<>(c.getValue().precio()));
    }

    @FXML
    private void onConsultarReserva() {
        String raw = tfIdReserva.getText().trim();
        if (raw.isBlank()) { lblMensaje.setText("Ingrese el ID de la reserva."); return; }

        long idReserva;
        try { idReserva = Long.parseLong(raw); }
        catch (NumberFormatException e) { lblMensaje.setText("ID debe ser numérico."); return; }

        try {
            // Obtener alojamiento de la primera habitación de la reserva
            idAlojamientoActual = reservaDAO.obtenerIdAlojamiento(idReserva);
            if (idAlojamientoActual < 0) {
                lblMensaje.setText("Reserva no encontrada o sin habitaciones asignadas.");
                return;
            }

            List<ServicioDTO> disponibles = servicioDAO.listarPorAlojamiento(idAlojamientoActual);
            tblDisponibles.setItems(FXCollections.observableArrayList(disponibles));

            List<ServicioDTO> contratados = servicioDAO.listarPorReserva(idReserva);
            tblContratados.setItems(FXCollections.observableArrayList(contratados));

            lblInfoReserva.setText("Reserva " + idReserva
                    + " · Alojamiento ID " + idAlojamientoActual
                    + " · " + disponibles.size() + " servicio(s) disponible(s)"
                    + " · " + contratados.size() + " contratado(s)");
            lblMensaje.setText("");
        } catch (Exception ex) {
            lblMensaje.setText("Error: " + ex.getMessage());
        }
    }

    @FXML
    private void onAgregarServicio() {
        ServicioDTO sel = tblDisponibles.getSelectionModel().getSelectedItem();
        if (sel == null) { lblMensaje.setText("Seleccione un servicio de la lista superior."); return; }

        String raw = tfIdReserva.getText().trim();
        long idReserva;
        try { idReserva = Long.parseLong(raw); }
        catch (NumberFormatException e) { lblMensaje.setText("ID de reserva inválido."); return; }

        int cantidad = spCantidad.getValue();
        try {
            servicioDAO.agregarServicio(idReserva, sel.id(), cantidad, sel.precio());
            lblMensaje.setText("Servicio '" + sel.nombre() + "' × " + cantidad + " agregado.");
            // Refrescar contratados
            tblContratados.setItems(FXCollections.observableArrayList(
                    servicioDAO.listarPorReserva(idReserva)));
        } catch (Exception ex) {
            lblMensaje.setText("Error al agregar: " + ex.getMessage());
        }
    }

    @FXML
    private void onQuitarServicio() {
        ServicioDTO sel = tblContratados.getSelectionModel().getSelectedItem();
        if (sel == null) { lblMensaje.setText("Seleccione un servicio de la lista inferior."); return; }

        String raw = tfIdReserva.getText().trim();
        long idReserva;
        try { idReserva = Long.parseLong(raw); }
        catch (NumberFormatException e) { lblMensaje.setText("ID de reserva inválido."); return; }

        try {
            servicioDAO.quitarServicio(idReserva, sel.id());
            lblMensaje.setText("Servicio '" + sel.nombre() + "' eliminado de la reserva.");
            tblContratados.setItems(FXCollections.observableArrayList(
                    servicioDAO.listarPorReserva(idReserva)));
        } catch (Exception ex) {
            lblMensaje.setText("Error al quitar: " + ex.getMessage());
        }
    }
}
