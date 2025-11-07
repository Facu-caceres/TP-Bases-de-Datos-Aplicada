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
Descripción: Script de testing para el consumo de API con xp_cmdshell.
*/
USE [Com5600_Grupo14_DB];
GO

PRINT '--- INICIO SCRIPT DE TESTING DE API (ENTREGA 6 - xp_cmdshell) ---';
GO

-- 1. Definir la ruta donde se guardará el JSON
-- Esta ruta debe ser accesible por la cuenta de servicio de SQL Server
-- 'C:\Temp' o 'C:\SQL' suelen ser opciones seguras.
DECLARE @ruta_api_dir NVARCHAR(260) = 'C:\SQL\api_temp';

PRINT 'Se usará la carpeta: ' + @ruta_api_dir;
PRINT 'Asegúrate de que el servicio de SQL Server tenga permisos de escritura allí.';
GO

PRINT 'Ejecutando SP [Importacion.sp_actualizar_cotizaciones_dolar]...';
EXEC Importacion.sp_actualizar_cotizaciones_dolar 
    @ruta_directorio = 'C:\SQL\api_temp'; -- Pasamos la ruta como parámetro
GO

PRINT 'Verificando los datos cargados en [General.CotizacionDolar] (TOP 20):';
SELECT TOP 20 *
FROM General.CotizacionDolar
ORDER BY FechaConsulta DESC;
GO

PRINT 'Verificando la vista [General.v_UltimaCotizacionDolar]:';
SELECT Casa, Venta, FechaActualizacion
FROM General.v_UltimaCotizacionDolar
ORDER BY Casa;
GO

PRINT 'Probando las funciones con $100.000 ARS:';
SELECT
  Reportes.fn_PesosAUSD(100000,'oficial') AS USD_Oficial,
  Reportes.fn_PesosAUSD(100000,'blue')    AS USD_Blue;
GO

PRINT '--- FIN SCRIPT DE TESTING (API) ---';
GO