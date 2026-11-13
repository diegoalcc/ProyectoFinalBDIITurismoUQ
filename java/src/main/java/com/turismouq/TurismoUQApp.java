package com.turismouq;

import javafx.application.Application;
import javafx.application.Platform;
import javafx.fxml.FXMLLoader;
import javafx.scene.Parent;
import javafx.scene.Scene;
import javafx.scene.control.Alert;
import javafx.scene.control.Alert.AlertType;
import javafx.stage.Stage;

public class TurismoUQApp extends Application {

    @Override
    public void start(Stage stage) throws Exception {
        // Capturar cualquier excepción no manejada en el hilo de JavaFX
        Thread.currentThread().setUncaughtExceptionHandler((t, ex) ->
                mostrarErrorCritico(ex));

        Parent root = FXMLLoader.load(getClass().getResource("/fxml/main.fxml"));

        Scene scene = new Scene(root, 1280, 780);
        scene.getStylesheets().add(
                getClass().getResource("/turismouq.css").toExternalForm());

        stage.setTitle("TurismoUQ — Sistema de Gestión Turística · UniQuindío 2026-2");
        stage.setScene(scene);
        stage.setMinWidth(1050);
        stage.setMinHeight(680);

        // Confirmar cierre si hay trabajo en curso (evita cierres accidentales)
        stage.setOnCloseRequest(e -> Platform.exit());

        stage.show();
    }

    /** Muestra un diálogo de error crítico sin cerrar la aplicación. */
    static void mostrarErrorCritico(Throwable ex) {
        Platform.runLater(() -> {
            Alert alert = new Alert(AlertType.ERROR);
            alert.setTitle("Error inesperado — TurismoUQ");
            alert.setHeaderText("Ocurrió un error inesperado en la aplicación.");
            alert.setContentText(ex.getClass().getSimpleName() + ": " + ex.getMessage()
                    + "\n\nLa aplicación seguirá funcionando. "
                    + "Si el problema persiste, verifique la conexión a la base de datos.");
            alert.showAndWait();
        });
    }

    public static void main(String[] args) {
        launch(args);
    }
}
