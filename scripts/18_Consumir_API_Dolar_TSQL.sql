/* =========================================================
   0) PRE-REQ (una sola vez en la instancia)
   ---------------------------------------------------------
   - Habilita xp_cmdshell (usaremos curl/PowerShell para bajar la API)
   - Habilita opciones avanzadas si no estaban
   ========================================================= */
EXEC sp_configure 'show advanced options', 1;  RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;           RECONFIGURE;
GO

/* Crea carpeta donde guardaremos el JSON */
EXEC xp_cmdshell 'mkdir C:\SQL\api', NO_OUTPUT;
GO

/* =========================================================
   1) ESQUEMAS Y TABLA
   ========================================================= */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='General')     EXEC('CREATE SCHEMA General');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='Importacion') EXEC('CREATE SCHEMA Importacion');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='Reportes')    EXEC('CREATE SCHEMA Reportes');
GO

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
    Fuente             NVARCHAR(200) NOT NULL DEFAULT N'https://dolarapi.com/v1/dolares'
  );
  CREATE UNIQUE INDEX UX_Cotiz_Casa_Fecha ON General.CotizacionDolar(Casa, FechaActualizacion);
END
GO

/* =========================================================
   2) SP ONLINE (descarga con curl + inserta; sin MERGE)
   ---------------------------------------------------------
   - Requiere curl (Windows 10/11 ya lo trae). Si no, ver bloque
     #5 para alternativa con PowerShell.
   ========================================================= */
CREATE OR ALTER PROCEDURE Importacion.sp_actualizar_cotizaciones_dolar
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @cmd  NVARCHAR(4000),
          @file NVARCHAR(260) = N'C:\SQL\api\dolares.json',
          @json NVARCHAR(MAX);

  -- 1) Limpiar archivo previo y descargar JSON
  EXEC xp_cmdshell 'del /Q "C:\SQL\api\dolares.json"', NO_OUTPUT;

  -- -s silencioso, -k tolera inspección SSL si existiera, -o salida a archivo
  SET @cmd = N'curl "https://dolarapi.com/v1/dolares" -s -k -o "C:\SQL\api\dolares.json"';
  EXEC xp_cmdshell @cmd, NO_OUTPUT;

  -- 2) Verificar que el archivo tenga contenido
  DECLARE @ok INT = 0;
  BEGIN TRY
      DECLARE @blob VARBINARY(MAX);
      SELECT @blob = BulkColumn
      FROM OPENROWSET(BULK 'C:\SQL\api\dolares.json', SINGLE_BLOB) AS B;
      IF @blob IS NOT NULL AND DATALENGTH(@blob) > 0 SET @ok = 1;
  END TRY
  BEGIN CATCH
      SET @ok = 0;
  END CATCH;

  IF (@ok = 0)
      THROW 50021, 'Descarga vacía: curl no recuperó contenido.', 1;

  -- 3) Leer como texto
  SELECT @json = BulkColumn
  FROM OPENROWSET(BULK 'C:\SQL\api\dolares.json', SINGLE_CLOB) AS J;

  IF (@json IS NULL OR LEN(@json)=0)
      THROW 50022, 'No se pudo leer el JSON descargado.', 1;

  -- 4) Parsear e insertar incremental
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
END
GO

/* =========================================================
   3) VISTA + FUNCIONES (para usar en reportes)
   ========================================================= */
CREATE OR ALTER VIEW General.v_UltimaCotizacionDolar
AS
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

/* =========================================================
   4) TEST
   ========================================================= */
EXEC Importacion.sp_actualizar_cotizaciones_dolar;

SELECT TOP 20 *
FROM General.CotizacionDolar
ORDER BY FechaConsulta DESC;

SELECT Casa, Venta, FechaActualizacion
FROM General.v_UltimaCotizacionDolar
ORDER BY Casa;

SELECT
  Reportes.fn_PesosAUSD(100000,'oficial') AS USD_Oficial,
  Reportes.fn_PesosAUSD(100000,'blue')    AS USD_Blue;
GO

/* =========================================================
   5) (OPCIONAL) Si no tuvieras curl, alternativa PowerShell:
   ---------------------------------------------------------
   Sustituí SOLO el bloque de descarga del SP por esto:

   DECLARE @ps NVARCHAR(4000) =
   N'powershell -NoProfile -Command ^
     "Invoke-WebRequest -Uri ''https://dolarapi.com/v1/dolares'' -UseBasicParsing -OutFile ''C:\SQL\api\dolares.json''"';
   EXEC xp_cmdshell 'del /Q "C:\SQL\api\dolares.json"', NO_OUTPUT;
   EXEC xp_cmdshell @ps, NO_OUTPUT;
   (el resto del SP queda igual)
   ========================================================= */
