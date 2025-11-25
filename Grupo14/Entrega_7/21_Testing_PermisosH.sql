/*
Materia: 3641 - Bases de Datos Aplicada
Comisión: 02-5600
Grupo: 14
Integrantes: Aguirre Dario Ivan 44355010
             Caceres Olguin Facundo 45747823
             Ciriello Florencia Ailen 44833569
             Mangalaviti Sebastian 45233238
             Pedrol Ledesma Bianca Uriana 45012041
             Saladino Mauro Tomas 44531560
Fecha de Entrega: 21/11/2025
Descripción: Script de Testing de Seguridad (Entrega 7).
             Valida la Matriz de Permisos cruzando los 4 Roles contra 
             las 3 categorías de operaciones (Maestros, Bancaria, Reportes).
*/

USE [Com5600G14];
GO

SET NOCOUNT ON;

PRINT '===========================================================================';
PRINT '                 TESTING DE MATRIZ DE PERMISOS (ENTREGA 7)';
PRINT '===========================================================================';
PRINT 'Leyenda:';
PRINT ' - PERMITIDO: El usuario pudo ejecutar (o falló por lógica, no por seguridad).';
PRINT ' - DENEGADO:  SQL Server bloqueó el acceso (Error 229).';
PRINT '---------------------------------------------------------------------------';
GO

-----------------------------------------------------------------------------------
-- PROCEDIMIENTO AUXILIAR PARA TESTEAR (Evita repetir código)
-----------------------------------------------------------------------------------
-- No creamos un SP real para no ensuciar la base, usamos bloques dinámicos.
-- La lógica es: Intentamos ejecutar. 
-- Si sale error 229 (Permission Denied) -> DENEGADO.
-- Si sale cualquier otro error (ej: ruta vacía) o éxito -> PERMITIDO.

-----------------------------------------------------------------------------------
-- 1. USUARIO: ADMINISTRATIVO GENERAL (usr_adm_general)
--    Esperado: Maestros [SI], Bancaria [NO], Reportes [SI]
-----------------------------------------------------------------------------------
PRINT '';
PRINT '>>> USUARIO: [usr_adm_general] (Adm. General)';
EXECUTE AS USER = 'usr_adm_general';

    -- A. Prueba Maestros (Consorcios)
    BEGIN TRY
        EXEC Importacion.sp_importar_consorcios @ruta_archivo = '';
        PRINT '    1. Maestros (Importar Consorcios):  [PERMITIDO]  <-- OK';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    1. Maestros (Importar Consorcios):  [DENEGADO]   <-- ERROR (Debería poder)';
        ELSE PRINT '    1. Maestros (Importar Consorcios):  [PERMITIDO]  <-- OK';
    END CATCH

    -- B. Prueba Bancaria (Pagos)
    BEGIN TRY
        EXEC Importacion.sp_importar_pagos @ruta_archivo = '';
        PRINT '    2. Bancaria (Importar Pagos):       [PERMITIDO]  <-- ERROR (No debería poder)';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    2. Bancaria (Importar Pagos):       [DENEGADO]   <-- OK (Bloqueo correcto)';
        ELSE PRINT '    2. Bancaria (Importar Pagos):       [PERMITIDO]  <-- ERROR (No debería poder)';
    END CATCH

    -- C. Prueba Reportes
    BEGIN TRY
        EXEC Reportes.sp_reporte_flujo_caja_semanal @FechaDesde='2025-01-01', @FechaHasta='2025-01-01';
        PRINT '    3. Reportes (Flujo de Caja):        [PERMITIDO]  <-- OK';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    3. Reportes (Flujo de Caja):        [DENEGADO]   <-- ERROR (Debería poder)';
        ELSE PRINT '    3. Reportes (Flujo de Caja):        [PERMITIDO]  <-- OK';
    END CATCH

REVERT;

-----------------------------------------------------------------------------------
-- 2. USUARIO: ADMINISTRATIVO BANCARIO (usr_adm_bancario)
--    Esperado: Maestros [NO], Bancaria [SI], Reportes [SI]
-----------------------------------------------------------------------------------
PRINT '';
PRINT '>>> USUARIO: [usr_adm_bancario] (Adm. Bancario)';
EXECUTE AS USER = 'usr_adm_bancario';

    -- A. Prueba Maestros
    BEGIN TRY
        EXEC Importacion.sp_importar_consorcios @ruta_archivo = '';
        PRINT '    1. Maestros (Importar Consorcios):  [PERMITIDO]  <-- ERROR (No debería poder)';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    1. Maestros (Importar Consorcios):  [DENEGADO]   <-- OK (Bloqueo correcto)';
        ELSE PRINT '    1. Maestros (Importar Consorcios):  [PERMITIDO]  <-- ERROR (No debería poder)';
    END CATCH

    -- B. Prueba Bancaria
    BEGIN TRY
        EXEC Importacion.sp_importar_pagos @ruta_archivo = '';
        PRINT '    2. Bancaria (Importar Pagos):       [PERMITIDO]  <-- OK';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    2. Bancaria (Importar Pagos):       [DENEGADO]   <-- ERROR (Debería poder)';
        ELSE PRINT '    2. Bancaria (Importar Pagos):       [PERMITIDO]  <-- OK';
    END CATCH

    -- C. Prueba Reportes
    BEGIN TRY
        EXEC Reportes.sp_reporte_flujo_caja_semanal @FechaDesde='2025-01-01', @FechaHasta='2025-01-01';
        PRINT '    3. Reportes (Flujo de Caja):        [PERMITIDO]  <-- OK';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    3. Reportes (Flujo de Caja):        [DENEGADO]   <-- ERROR (Debería poder)';
        ELSE PRINT '    3. Reportes (Flujo de Caja):        [PERMITIDO]  <-- OK';
    END CATCH

REVERT;

-----------------------------------------------------------------------------------
-- 3. USUARIO: ADMINISTRATIVO OPERATIVO (usr_adm_operativo)
--    Esperado: Maestros [SI], Bancaria [NO], Reportes [SI]
-----------------------------------------------------------------------------------
PRINT '';
PRINT '>>> USUARIO: [usr_adm_operativo] (Adm. Operativo)';
EXECUTE AS USER = 'usr_adm_operativo';

    -- A. Prueba Maestros
    BEGIN TRY
        EXEC Importacion.sp_importar_consorcios @ruta_archivo = '';
        PRINT '    1. Maestros (Importar Consorcios):  [PERMITIDO]  <-- OK';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    1. Maestros (Importar Consorcios):  [DENEGADO]   <-- ERROR (Debería poder)';
        ELSE PRINT '    1. Maestros (Importar Consorcios):  [PERMITIDO]  <-- OK';
    END CATCH

    -- B. Prueba Bancaria
    BEGIN TRY
        EXEC Importacion.sp_importar_pagos @ruta_archivo = '';
        PRINT '    2. Bancaria (Importar Pagos):       [PERMITIDO]  <-- ERROR (No debería poder)';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    2. Bancaria (Importar Pagos):       [DENEGADO]   <-- OK (Bloqueo correcto)';
        ELSE PRINT '    2. Bancaria (Importar Pagos):       [PERMITIDO]  <-- ERROR (No debería poder)';
    END CATCH

    -- C. Prueba Reportes
    BEGIN TRY
        EXEC Reportes.sp_reporte_flujo_caja_semanal @FechaDesde='2025-01-01', @FechaHasta='2025-01-01';
        PRINT '    3. Reportes (Flujo de Caja):        [PERMITIDO]  <-- OK';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    3. Reportes (Flujo de Caja):        [DENEGADO]   <-- ERROR (Debería poder)';
        ELSE PRINT '    3. Reportes (Flujo de Caja):        [PERMITIDO]  <-- OK';
    END CATCH

REVERT;

-----------------------------------------------------------------------------------
-- 4. USUARIO: SISTEMAS (usr_sistemas)
--    Esperado: Maestros [NO], Bancaria [NO], Reportes [SI]
-----------------------------------------------------------------------------------
PRINT '';
PRINT '>>> USUARIO: [usr_sistemas] (Sistemas)';
EXECUTE AS USER = 'usr_sistemas';

    -- A. Prueba Maestros
    BEGIN TRY
        EXEC Importacion.sp_importar_consorcios @ruta_archivo = '';
        PRINT '    1. Maestros (Importar Consorcios):  [PERMITIDO]  <-- ERROR (No debería poder)';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    1. Maestros (Importar Consorcios):  [DENEGADO]   <-- OK (Bloqueo correcto)';
        ELSE PRINT '    1. Maestros (Importar Consorcios):  [PERMITIDO]  <-- ERROR (No debería poder)';
    END CATCH

    -- B. Prueba Bancaria
    BEGIN TRY
        EXEC Importacion.sp_importar_pagos @ruta_archivo = '';
        PRINT '    2. Bancaria (Importar Pagos):       [PERMITIDO]  <-- ERROR (No debería poder)';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    2. Bancaria (Importar Pagos):       [DENEGADO]   <-- OK (Bloqueo correcto)';
        ELSE PRINT '    2. Bancaria (Importar Pagos):       [PERMITIDO]  <-- ERROR (No debería poder)';
    END CATCH

    -- C. Prueba Reportes
    BEGIN TRY
        EXEC Reportes.sp_reporte_flujo_caja_semanal @FechaDesde='2025-01-01', @FechaHasta='2025-01-01';
        PRINT '    3. Reportes (Flujo de Caja):        [PERMITIDO]  <-- OK';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229 PRINT '    3. Reportes (Flujo de Caja):        [DENEGADO]   <-- ERROR (Debería poder)';
        ELSE PRINT '    3. Reportes (Flujo de Caja):        [PERMITIDO]  <-- OK';
    END CATCH

REVERT;
GO

PRINT '===========================================================================';
PRINT 'FIN DEL TESTING DE PERMISOS';
PRINT '===========================================================================';
