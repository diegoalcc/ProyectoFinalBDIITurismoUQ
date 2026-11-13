-- =============================================================================
-- TURISMOUQ - ORDEN DE EJECUCIÓN COMPLETO
-- Equipo: Sebastián Torres Morales · Jorge William Montoya Toro · Diego Alejandro Carvajal Camargo
--
-- INSTRUCCIONES:
--   1. Abrir SQL Developer
--   2. Conectarse como SYSTEM (ver Paso 0)
--   3. Ejecutar Paso 0 para crear el usuario
--   4. Cambiar la conexión a turismouq (ver Paso 1 en adelante)
--   5. Ejecutar los pasos en orden
--
-- TIEMPO ESTIMADO: 10-20 minutos (la carga de 25.000 reservas tarda)
-- =============================================================================

-- ============================================================
-- PASO 0: CREAR USUARIO (conectado como SYSTEM)
-- ¡Ejecutar SOLO este bloque primero con conexión SYSTEM!
-- ============================================================
-- @07_Crear_Usuario.sql

-- ============================================================
-- A PARTIR DE AQUÍ: conectado como turismouq / 1097032932
-- ============================================================

PROMPT ========================================
PROMPT  PASO 1: DDL - Tablas, índices, tipos
PROMPT ========================================
@01_DDL_TurismoUQ.sql

PROMPT ========================================
PROMPT  PASO 2: Infraestructura - Tablespace + Vista Materializada
PROMPT ========================================
@02_Infraestructura.sql

PROMPT ========================================
PROMPT  PASO 3: Paquete PL/SQL
PROMPT ========================================
@03_Paquete_PKG_TURISMOUQ.sql

PROMPT ========================================
PROMPT  PASO 4: Carga de datos (tarda varios minutos)
PROMPT ========================================
SET SERVEROUTPUT ON SIZE UNLIMITED;
@05_Carga_Datos.sql

PROMPT ========================================
PROMPT  PASO 5: Triggers (DESPUÉS de la carga)
PROMPT ========================================
@04_Triggers.sql

PROMPT ========================================
PROMPT  PASO 6 (OPCIONAL): Pruebas Entrega 2
PROMPT ========================================
-- @08_Pruebas_Entrega2.sql

PROMPT ========================================
PROMPT  VERIFICACIÓN RÁPIDA
PROMPT ========================================
SET SERVEROUTPUT ON SIZE UNLIMITED;
EXEC PKG_TURISMOUQ.sp_liquidacion_mensual_alojamiento(4, 2025);

PROMPT ===== EJECUCIÓN COMPLETA =====
