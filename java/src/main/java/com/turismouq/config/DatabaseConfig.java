package com.turismouq.config;

import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

public final class DatabaseConfig {
    private static final Properties PROPS = new Properties();

    static {
        try (InputStream in = DatabaseConfig.class.getResourceAsStream("/application.properties")) {
            if (in != null) {
                PROPS.load(in);
            }
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo cargar application.properties", e);
        }
    }

    private DatabaseConfig() {
    }

    public static Connection getConnection() throws SQLException {
        return DriverManager.getConnection(
                PROPS.getProperty("db.url", "jdbc:oracle:thin:@localhost:1521:XE"),
                PROPS.getProperty("db.user", "turismouq"),
                PROPS.getProperty("db.password", "turismouq")
        );
    }
}
