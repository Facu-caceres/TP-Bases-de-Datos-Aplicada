/* ============================================================
   IMPORTS TP - Com5600_Grupo14_DB
   Autor: Sebastian
   Objetivo: Ejecutar los SP de importación desde archivos fuente
   ============================================================ */

USE Com5600_Grupo14_DB;
GO

/* =========================
   Parámetros de ejecución
   ========================= */
DECLARE 
    @provider    NVARCHAR(100) = N'Microsoft.ACE.OLEDB.16.0',   -- usar 12.0 si corresponde
    @excelPath   NVARCHAR(4000) = N'C:\Users\Seba\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\datos varios.xlsx',
    @ufPath      NVARCHAR(4000) = N'C:\Users\Seba\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\UF por consorcio.txt',
    @personasCsv NVARCHAR(4000) = N'C:\Users\Seba\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\Inquilino-propietarios-datos.csv';
-- Si preferís forzar 12.0: SET @provider = N'Microsoft.ACE.OLEDB.12.0';

PRINT '--- INICIO DE IMPORTS ---';

/* ========================================
   1) Importar Consorcios (desde Excel)
   ======================================== */
PRINT 'Importando Consorcios...';
EXEC Importacion.sp_importar_consorcios @ruta_archivo = @excelPath;


/* ========================================
   2) Importar Proveedores (desde Excel)
   - Reemplazo/Upsert según tu SP elegido
   ======================================== */
PRINT 'Importando Proveedores...';
EXEC Importacion.sp_importar_proveedores_reemplazo @ruta_archivo = 'C:\Users\Seba\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\datos varios.xlsx';


/* ========================================
   3) Importar Unidades Funcionales (TXT)
   ======================================== */
PRINT 'Importando Unidades Funcionales...';
EXEC Importacion.sp_importar_uf @ruta_archivo = @ufPath;


/* ========================================
   4) Importar Personas y Cuentas (CSV)
   ======================================== */
PRINT 'Importando Personas y Cuentas Bancarias...';
EXEC Importacion.sp_importar_personas @ruta_archivo = @personasCsv;


/* ========================================
   5) Verificaciones rápidas
   ======================================== */
PRINT 'Verificando datos...';

SELECT TOP (10) * FROM General.Consorcio;
SELECT TOP (10) * FROM General.Proveedor;
SELECT TOP (10) * FROM Propiedades.UnidadFuncional;
SELECT TOP (10) * FROM Propiedades.Persona;
SELECT TOP (10) * FROM Tesoreria.Persona_CuentaBancaria;

-- Consultas puntuales de control (opcional)
SELECT * FROM Propiedades.Persona WHERE dni = 29364139;
-- SELECT * FROM Propiedades.Persona;  -- descomentar si necesitás listar todo

PRINT '--- FIN DE IMPORTS ---';
GO


/* ============================================================
   UTILIDADES / PRUEBAS (OPCIONAL) 
   Ejecutar solo si lo necesitás. Dejar comentado normalmente.
   ============================================================ */

-- -- Info de versión
-- SELECT @@VERSION;

-- -- Ver proveedores OLE DB disponibles
-- EXEC sp_enum_oledb_providers;

-- -- Habilitar Ad Hoc (una sola vez por servidor)
-- EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
-- EXEC sp_configure 'Ad Hoc Distributed Queries', 1; RECONFIGURE;

-- -- Activar propiedades del proveedor ACE (una sola vez)
-- EXEC sys.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1;
-- EXEC sys.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'DynamicParameters', 1;
-- -- Si usás 12.0, repetir con '12.0'.

-- -- Smoke test de OPENROWSET: Consorcios (HDR=YES)
-- SELECT TOP (5) *
-- FROM OPENROWSET(@provider,
--                 'Excel 12.0;HDR=YES;IMEX=1;Database=' + @excelPath,
--                 'SELECT * FROM [Consorcios$]');

-- -- Smoke test de OPENROWSET: Proveedores (HDR=NO)
-- SELECT TOP (5) *
-- FROM OPENROWSET(@provider,
--                 'Excel 12.0;HDR=NO;IMEX=1;Database=' + @excelPath,
--                 'SELECT * FROM [Proveedores$]');



