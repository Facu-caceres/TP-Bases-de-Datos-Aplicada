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
Descripción: Entrega 6 - Creación de SP para consumir API externa (DolarAPI)
*/

USE [Com5600G14];
GO

-- Habilita xp_cmdshell (usaremos curl/PowerShell para bajar la API)

PRINT 'Habilitando xp_cmdshell (requerido para curl/powershell)...';
EXEC sp_configure 'show advanced options', 1;  RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;           RECONFIGURE;
GO

PRINT 'Creando tabla General.CotizacionDolar...';
IF OBJECT_ID('Reportes.CotizacionDolar','U') IS NOT NULL
    DROP TABLE Reportes.CotizacionDolar; 

IF OBJECT_ID('General.CotizacionDolar','U') IS NULL
BEGIN
  CREATE TABLE General.CotizacionDolar(
    IdCotizacion       INT IDENTITY(1,1) PRIMARY KEY,
    Casa               VARCHAR(40)   NOT NULL,
    Nombre             NVARCHAR(60)  NOT NULL,
    Moneda             CHAR(3)       NOT NULL,
    Compra             DECIMAL(18,4) NOT NULL,
    Venta              DECIMAL(18,4) NOT NULL,
    FechaActualizacion DATETIME2(0)  NOT NULL,
    FechaConsulta      DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    Fuente             NVARCHAR(200) NOT NULL DEFAULT 'https://dolarapi.com/v1/dolares'
  );
  CREATE UNIQUE INDEX UX_Cotiz_Casa_Fecha ON General.CotizacionDolar(Casa, FechaActualizacion);
END
GO

PRINT 'Creando SP Importacion.sp_actualizar_cotizaciones_dolar...';
GO

CREATE OR ALTER PROCEDURE Importacion.sp_actualizar_cotizaciones_dolar
    @ruta_directorio NVARCHAR(260) -- Parámetro para la ruta
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @cmd      NVARCHAR(4000),
          @file     NVARCHAR(400),
          @json     NVARCHAR(MAX),
          @sql_bulk NVARCHAR(1000);

  SET @file = @ruta_directorio + '\dolares.json';
  PRINT 'Ruta de archivo JSON de destino: ' + @file;

  SET @cmd = N'mkdir "' + @ruta_directorio + N'"';
  EXEC xp_cmdshell @cmd, NO_OUTPUT;

  SET @cmd = N'del /Q "' + @file + N'"';
  EXEC xp_cmdshell @cmd, NO_OUTPUT;

  -- -s silencioso, -k tolera inspección SSL, -o salida a archivo
  SET @cmd = N'curl "https://dolarapi.com/v1/dolares" -s -k -o "' + @file + N'"';
  PRINT 'Ejecutando: ' + @cmd;
  EXEC xp_cmdshell @cmd, NO_OUTPUT;

  BEGIN TRY
    SET @sql_bulk = N'SELECT @json = BulkColumn FROM OPENROWSET(BULK ''' + @file + N''', SINGLE_CLOB) AS J;';
    EXEC sp_executesql @sql_bulk, N'@json NVARCHAR(MAX) OUTPUT', @json OUTPUT;
  END TRY
  BEGIN CATCH
      PRINT 'Error fatal al leer el archivo JSON (SINGLE_CLOB).';
      PRINT ERROR_MESSAGE();
      THROW 50022, 'No se pudo leer el JSON descargado. Verifique la ruta, permisos o si el archivo está vacío.', 1;
  END CATCH;

  IF (@json IS NULL OR LEN(@json) <= 2) -- Check para NULL o '[]'
  BEGIN
      PRINT 'ADVERTENCIA: La descarga (curl) no recuperó contenido o el archivo está vacío. No se insertarán datos.';
      RETURN; 
  END

  PRINT 'Archivo descargado y leído. Parseando JSON...';
  
  ;WITH J AS (
      SELECT *
      FROM OPENJSON(@json)
      WITH (
          compra             DECIMAL(18,4) '$.compra',
          venta              DECIMAL(18,4) '$.venta',
          casa               VARCHAR(40)   '$.casa',
          nombre             NVARCHAR(60)  '$.nombre',
          moneda             CHAR(3)       '$.moneda',
          fechaActualizacion DATETIME2(0)  '$.fechaActualizacion'
      )
  )
  INSERT INTO General.CotizacionDolar (Casa, Nombre, Moneda, Compra, Venta, FechaActualizacion)
  SELECT j.casa, j.nombre, j.moneda, j.compra, j.venta, j.fechaActualizacion
  FROM J
  WHERE NOT EXISTS (
      SELECT 1
      FROM General.CotizacionDolar g
      WHERE g.Casa = j.casa
        AND g.FechaActualizacion = j.fechaActualizacion
  );
  
  PRINT 'SP finalizado. Filas insertadas/actualizadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
END
GO

PRINT 'Creando Vista y Funciones auxiliares...';
GO

CREATE OR ALTER VIEW General.v_UltimaCotizacionDolar
AS
-- Esta vista nos da la cotización MÁS RECIENTE para cada "casa" (oficial, blue, etc)
SELECT c.*
FROM General.CotizacionDolar c
JOIN (
  SELECT Casa, MAX(FechaActualizacion) AS MaxFecha
  FROM General.CotizacionDolar
  GROUP BY Casa
) q ON q.Casa = c.Casa AND q.MaxFecha = c.FechaActualizacion;
GO

CREATE OR ALTER FUNCTION Reportes.fn_PesosAUSD(@importeARS DECIMAL(18,4), @casa VARCHAR(40)='oficial')
RETURNS DECIMAL(18,4)
AS
BEGIN
  DECLARE @venta DECIMAL(18,4);
  SELECT TOP 1 @venta = Venta FROM General.v_UltimaCotizacionDolar WHERE Casa = @casa;
  RETURN CASE WHEN @venta IS NULL OR @venta = 0 THEN NULL ELSE @importeARS / @venta END;
END
GO

CREATE OR ALTER FUNCTION Reportes.fn_USDApesos(@importeUSD DECIMAL(18,4), @casa VARCHAR(40)='oficial')
RETURNS DECIMAL(18,4)
AS
BEGIN
  DECLARE @venta DECIMAL(18,4);
  SELECT TOP 1 @venta = Venta FROM General.v_UltimaCotizacionDolar WHERE Casa = @casa;
  RETURN CASE WHEN @venta IS NULL THEN NULL ELSE @importeUSD * @venta END;
END
GO

PRINT '--- FIN SCRIPT API (Creación) ---';
GO