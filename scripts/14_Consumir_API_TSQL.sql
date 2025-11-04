USE [Com5600_Grupo14_DB];
GO


/* Habilitar (según entorno) */
-- EXEC sys.sp_configure 'polybase enabled', 1; RECONFIGURE; -- si aplica
-- EXEC sys.sp_configure 'external scripts enabled', 1; RECONFIGURE; -- si aplica

/* Tabla para cachear cotizaciones (opcional) */
IF OBJECT_ID('REP.CotizacionDolar') IS NULL
CREATE TABLE REP.CotizacionDolar(
    Id int IDENTITY PRIMARY KEY,
    Fuente varchar(50),
    Moneda varchar(10),
    Tipo varchar(50),          -- blue, oficial, mep, ccl, etc. según API elegida
    ValorCompra decimal(18,4) NULL,
    ValorVenta  decimal(18,4) NULL,
    FechaHora   datetime2      DEFAULT SYSUTCDATETIME()
);

/* Ejemplo: DolarApi - todos los tipos AR */
DECLARE @url nvarchar(4000) = N'https://dolarapi.com/v1/dolares';
DECLARE @res nvarchar(max);

EXEC sp_invoke_external_rest_endpoint
    @method = 'GET',
    @url    = @url,
    @response = @res OUTPUT;  -- requiere permisos/entorno compatibles
SELECT @res AS JsonRespuesta;  -- para inspección

-- Parseo (depende del shape exacto devuelto por la API)
-- Ejemplo genérico: OPENJSON con esquema (ajustar a campos reales)
-- INSERT INTO REP.CotizacionDolar(Fuente, Moneda, Tipo, ValorCompra, ValorVenta)
-- SELECT 'DolarApi','ARS', j.[tipo], j.[compra], j.[venta]
-- FROM OPENJSON(@res) WITH (
--     [tipo]   nvarchar(50) '$.casa',
--     [compra] decimal(18,4) '$.compra',
--     [venta]  decimal(18,4) '$.venta'
-- ) j;

/* Ejemplo: ArgentinaDatos – feriados del año */
DECLARE @anio int = YEAR(GETDATE());
DECLARE @urlF nvarchar(4000) = N'https://argentinadatos.com/v1/feriados/' + CAST(@anio as nvarchar(10));
DECLARE @resF nvarchar(max);

EXEC sp_invoke_external_rest_endpoint
    @method = 'GET',
    @url    = @urlF,
    @response = @resF OUTPUT;

SELECT @resF AS JsonFeriados;

-- Ejemplo de uso: marcar vencimientos que caen feriado (JOIN con tabla de Vencimientos)
-- SELECT v.IdExpensa, v.FechaVenc,
--        CASE WHEN EXISTS (
--             SELECT 1 FROM OPENJSON(@resF) WITH ([fecha] date '$.fecha') f
--             WHERE f.[fecha] = v.FechaVenc
--        ) THEN 1 ELSE 0 END AS EsFeriado
-- FROM dbo.Vencimiento v;
