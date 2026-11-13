-- =============================================================================
-- TURISMOUQ - CREAR USUARIO DE BASE DE DATOS
-- Ejecutar COMO SYSTEM (una sola vez, antes del resto de scripts).
-- Si el usuario ya existe, el script lo recrea limpio.
-- =============================================================================

-- Eliminar usuario si ya existe (borra todos sus objetos)
BEGIN
    EXECUTE IMMEDIATE 'DROP USER turismouq CASCADE';
    DBMS_OUTPUT.PUT_LINE('Usuario turismouq eliminado.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -1918 THEN
            DBMS_OUTPUT.PUT_LINE('Usuario turismouq no existía, se crea nuevo.');
        ELSE
            RAISE;
        END IF;
END;
/

-- Crear usuario con la contraseña del application.properties
CREATE USER turismouq
    IDENTIFIED BY "1097032932"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

-- Privilegios de sistema necesarios
GRANT CONNECT, RESOURCE TO turismouq;
GRANT CREATE SESSION        TO turismouq;
GRANT CREATE TABLE          TO turismouq;
GRANT CREATE VIEW           TO turismouq;
GRANT CREATE MATERIALIZED VIEW TO turismouq;
GRANT CREATE PROCEDURE      TO turismouq;
GRANT CREATE TRIGGER        TO turismouq;
GRANT CREATE SEQUENCE       TO turismouq;
GRANT CREATE TYPE           TO turismouq;
GRANT CREATE TABLESPACE     TO turismouq;   -- para TBS_TURISMOUQ_HIST
GRANT UNLIMITED TABLESPACE  TO turismouq;

-- Para que el usuario pueda usar DBMS_MVIEW y DBMS_OUTPUT
GRANT EXECUTE ON DBMS_MVIEW    TO turismouq;
GRANT EXECUTE ON DBMS_OUTPUT   TO turismouq;

