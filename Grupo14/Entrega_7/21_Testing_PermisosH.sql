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
Descripción: Entrega 7 - Reporte Top Morosidad con hash

*/

USE Com5600_Grupo14_DB;
GO

PRINT '--- reporte como AdmGeneral ---';
EXECUTE AS USER = 'usr_adm_general';
    --SELECT USER_NAME() AS usuario_actual;  -- acá vas a ver usr_adm_general
    EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte     = '2025-12-31',
        @IdConsorcio    = NULL,
        @IncluirExtra   = 0,
        @MesesFiltroCSV = NULL,
        @TopN           = 3;
REVERT;
GO

PRINT '--- reporte como Sitenas ---';
EXECUTE AS USER = 'usr_sistema';
    --SELECT USER_NAME() AS usuario_actual;  -- acá vas a ver usr_sistemas
    EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte     = '2025-12-31',
        @IdConsorcio    = NULL,
        @IncluirExtra   = 0,
        @MesesFiltroCSV = NULL,
        @TopN           = 3;
REVERT;
GO

PRINT '--- reporte como AdmOperativo ---';
EXECUTE AS USER = 'usr_adm_operativo';
    --SELECT USER_NAME() AS usuario_actual;  -- usr_adm_operativo
    EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte     = '2025-12-31',
        @IdConsorcio    = NULL,
        @IncluirExtra   = 0,
        @MesesFiltroCSV = NULL,
        @TopN           = 3;
REVERT;
GO

PRINT '--- reporte como bancario ---';
EXECUTE AS USER = 'usr_adm_bancario';
    --SELECT USER_NAME() AS usuario_actual;  -- acá vas a ver usr_bancario
    EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte     = '2025-12-31',
        @IdConsorcio    = NULL,
        @IncluirExtra   = 0,
        @MesesFiltroCSV = NULL,
        @TopN           = 3;
REVERT;
GO

------------------------------------------------------------
-- PRUEBA COMO ADMINISTRATIVO GENERAL
------------------------------------------------------------
PRINT '=== TEST 2: usr_adm_general (NO debe tener permisos) ===';
EXECUTE AS USER = 'usr_adm_general';
    --SELECT 'Usuario actual:' AS info, USER_NAME() AS usuario;

    PRINT '2.1) sp_importar_pagos (ESPERADO: ERROR DE PERMISO EN ROJO)';
    EXEC Importacion.sp_importar_pagos 
        @ruta_archivo = N'';

    -- Si llegó hasta acá (no debería), probamos también el otro:
    PRINT '2.2) sp_actualizar_cotizaciones_dolar (ESPERADO: ERROR DE PERMISO EN ROJO)';
    EXEC Importacion.sp_actualizar_cotizaciones_dolar 
        @ruta_directorio = N'';
REVERT;
GO


------------------------------------------------------------
-- PRUEBA COMO ADMINISTRATIVO OPERATIVO
------------------------------------------------------------
PRINT '=== TEST 3: usr_adm_operativo (NO debe tener permisos) ===';
EXECUTE AS USER = 'usr_adm_operativo';
    --SELECT 'Usuario actual:' AS info, USER_NAME() AS usuario;

    PRINT '3.1) sp_importar_pagos (ESPERADO: ERROR DE PERMISO EN ROJO)';
    EXEC Importacion.sp_importar_pagos 
        @ruta_archivo = N'';

    PRINT '3.2) sp_actualizar_cotizaciones_dolar (ESPERADO: ERROR DE PERMISO EN ROJO)';
    EXEC Importacion.sp_actualizar_cotizaciones_dolar 
        @ruta_directorio = N'';
REVERT;
GO


------------------------------------------------------------
-- PRUEBA COMO SISTEMAS
------------------------------------------------------------
PRINT '=== TEST 4: usr_sistemas (NO debe tener permisos) ===';
EXECUTE AS USER = 'usr_sistemas';
    --SELECT 'Usuario actual:' AS info, USER_NAME() AS usuario;

    PRINT '4.1) sp_importar_pagos (ESPERADO: ERROR DE PERMISO EN ROJO)';
    EXEC Importacion.sp_importar_pagos 
        @ruta_archivo = N'';

    PRINT '4.2) sp_actualizar_cotizaciones_dolar (ESPERADO: ERROR DE PERMISO EN ROJO)';
    EXEC Importacion.sp_actualizar_cotizaciones_dolar 
        @ruta_directorio = N'';
REVERT;
GO