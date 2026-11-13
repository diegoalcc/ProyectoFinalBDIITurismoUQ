package com.turismouq.ui;

import com.turismouq.dao.CatalogoDAO;
import com.turismouq.dto.AlojamientoDTO;
import com.turismouq.dto.ClienteDTO;
import com.turismouq.dto.HabitacionDTO;
import com.turismouq.dto.LineaHabitacionReservaDTO;
import com.turismouq.service.ReservaService;
import javafx.collections.FXCollections;
import javafx.fxml.FXML;
import javafx.scene.control.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class ReservasController {

    @FXML private ComboBox<String>         cbMunicipio;
    @FXML private ComboBox<AlojamientoDTO> cbAlojamiento;
    @FXML private ComboBox<ClienteDTO>     cbCliente;
    @FXML private ComboBox<HabitacionDTO>  cbHabitacion;
    @FXML private DatePicker               dpIn;
    @FXML private DatePicker               dpOut;
    @FXML private TextField                tfHuespedes;
    @FXML private ListView<String>         lvLineas;
    @FXML private Label                    lblValor;
    @FXML private Label                    lblMensaje;

    private final CatalogoDAO   catalogoDAO   = new CatalogoDAO();
    private final ReservaService reservaService = new ReservaService();
    private final List<LineaHabitacionReservaDTO> lineas = new ArrayList<>();

    @FXML
    public void initialize() {
        dpIn.setValue(LocalDate.now().plusDays(7));
        dpOut.setValue(LocalDate.now().plusDays(10));

        cbAlojamiento.setConverter(new javafx.util.StringConverter<>() {
            @Override public String toString(AlojamientoDTO a) {
                return a == null ? "" : a.nombre();
            }
            @Override public AlojamientoDTO fromString(String s) { return null; }
        });
        cbCliente.setConverter(new javafx.util.StringConverter<>() {
            @Override public String toString(ClienteDTO c) {
                return c == null ? "" : c.id() + " — " + c.nombre();
            }
            @Override public ClienteDTO fromString(String s) { return null; }
        });
        cbHabitacion.setConverter(new javafx.util.StringConverter<>() {
            @Override public String toString(HabitacionDTO h) {
                return h == null ? "" :
                        "Hab " + h.numero() + " (" + h.tipo() + ", cap " + h.capacidad() + ")";
            }
            @Override public HabitacionDTO fromString(String s) { return null; }
        });

        try {
            cbMunicipio.setItems(FXCollections.observableArrayList(catalogoDAO.listarMunicipios()));
            cbCliente.setItems(FXCollections.observableArrayList(catalogoDAO.listarClientes(200)));
        } catch (Exception ex) {
            mostrarError("Error de conexión: " + ex.getMessage());
        }
    }

    // FIX: throws Exception → try/catch local para mostrar error en lblMensaje
    @FXML
    private void onMunicipio() {
        String mun = cbMunicipio.getValue();
        if (mun == null) return;
        try {
            cbAlojamiento.setItems(
                    FXCollections.observableArrayList(
                            catalogoDAO.listarAlojamientosPorMunicipio(mun)));
            cbHabitacion.getItems().clear();
        } catch (Exception ex) {
            mostrarError("Error al cargar alojamientos: " + ex.getMessage());
        }
    }

    // FIX: throws Exception → try/catch local
    @FXML
    private void onAlojamiento() {
        AlojamientoDTO a = cbAlojamiento.getValue();
        if (a == null) return;
        try {
            cbHabitacion.setItems(
                    FXCollections.observableArrayList(
                            catalogoDAO.listarHabitaciones(a.id())));
        } catch (Exception ex) {
            mostrarError("Error al cargar habitaciones: " + ex.getMessage());
        }
    }

    // FIX: NumberFormatException capturada con mensaje amigable
    @FXML
    private void onAgregarHabitacion() {
        HabitacionDTO h = cbHabitacion.getValue();
        if (h == null || dpIn.getValue() == null || dpOut.getValue() == null) {
            mostrarError("Seleccione habitación y fechas.");
            return;
        }

        // FIX: parseInt puede lanzar NumberFormatException — capturar aquí
        int huespedes;
        try {
            huespedes = Integer.parseInt(tfHuespedes.getText().trim());
            if (huespedes < 1) throw new NumberFormatException();
        } catch (NumberFormatException e) {
            mostrarError("Ingrese un número válido de huéspedes (≥ 1).");
            return;
        }

        if (dpOut.getValue().compareTo(dpIn.getValue()) <= 0) {
            mostrarError("La fecha de check-out debe ser posterior al check-in.");
            return;
        }

        LineaHabitacionReservaDTO linea = new LineaHabitacionReservaDTO(
                h.id(), dpIn.getValue(), dpOut.getValue(), huespedes);
        lineas.add(linea);
        lvLineas.getItems().add(
                "Hab " + h.id() + " | " + linea.checkin()
                + " → " + linea.checkout()
                + " | " + huespedes + " hués.");
        lblMensaje.setStyle("-fx-text-fill: green;");
        lblMensaje.setText("Habitación agregada. Total líneas: " + lineas.size());
    }

    @FXML
    private void onCalcular() {
        try {
            // FIX: si aún no se agregó línea pero hay habitación seleccionada,
            // calcular sobre la selección actual (mantenemos el comportamiento)
            // pero aclaramos al usuario que debe agregar la línea para reservar.
            if (lineas.isEmpty()) {
                HabitacionDTO h = cbHabitacion.getValue();
                if (h == null || dpIn.getValue() == null || dpOut.getValue() == null) {
                    mostrarError("Seleccione habitación y fechas para calcular.");
                    return;
                }
                BigDecimal total = reservaService.calcularEstadia(
                        h.id(), dpIn.getValue(), dpOut.getValue());
                lblValor.setText("Valor estimado: $" + String.format("%,.0f", total)
                        + " (pulse 'Agregar habitación' para incluirla en la reserva)");
            } else {
                BigDecimal total = BigDecimal.ZERO;
                for (LineaHabitacionReservaDTO l : lineas) {
                    total = total.add(
                            reservaService.calcularEstadia(
                                    l.idHabitacion(), l.checkin(), l.checkout()));
                }
                lblValor.setText("Valor estimado: $" + String.format("%,.0f", total));
            }
            lblMensaje.setStyle("");
            lblMensaje.setText("");
        } catch (Exception ex) {
            mostrarError(ex.getMessage());
        }
    }

    @FXML
    private void onCrearReserva() {
        try {
            if (cbCliente.getValue() == null) {
                mostrarError("Seleccione un cliente.");
                return;
            }
            if (lineas.isEmpty()) {
                mostrarError("Agregue al menos una habitación antes de crear la reserva.");
                return;
            }
            long id = reservaService.crearReserva(cbCliente.getValue().id(), lineas);
            lblMensaje.setStyle("-fx-text-fill: green; -fx-font-weight: bold;");
            lblMensaje.setText("✓ Reserva creada con ID: " + id);
            lblValor.setText("Valor estimado: $0");
            lineas.clear();
            lvLineas.getItems().clear();
        } catch (Exception ex) {
            mostrarError(ex.getMessage());
        }
    }

    /** Muestra un mensaje de error en rojo en lblMensaje. */
    private void mostrarError(String msg) {
        lblMensaje.setStyle("-fx-text-fill: red;");
        lblMensaje.setText(msg);
    }
}
