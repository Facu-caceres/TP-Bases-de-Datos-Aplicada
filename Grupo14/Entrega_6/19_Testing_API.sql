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

PRINT '--- Test Integrado: Reporte de Pagos convertido a Dólar Blue y Oficial ---';

SELECT TOP 10 
    p.id_pago,
    p.fecha_de_pago,
    c.nombre AS Consorcio,
    -- Importe original en Pesos
    p.importe AS [Importe ARS],
    -- Conversión usando tu función API (Oficial)
    FORMAT(Reportes.fn_PesosAUSD(p.importe, 'oficial'), 'N2') AS [USD Oficial (Aprox)],
    -- Conversión usando tu función API (Blue)
    FORMAT(Reportes.fn_PesosAUSD(p.importe, 'blue'), 'N2')    AS [USD Blue (Aprox)]
FROM Tesoreria.Pago p
INNER JOIN Tesoreria.Persona_CuentaBancaria pcb ON p.id_persona_cuenta = pcb.id_persona_cuenta
INNER JOIN Propiedades.UF_Persona ufp ON pcb.id_persona = ufp.id_persona
INNER JOIN Propiedades.UnidadFuncional uf ON ufp.id_uf = uf.id_uf
INNER JOIN General.Consorcio c ON uf.id_consorcio = c.id_consorcio
ORDER BY p.fecha_de_pago DESC;
GO

PRINT '--- Test Integrado: Total Recaudado por Consorcio en USD (Blue) ---';

SELECT 
    c.nombre AS Consorcio,
    COUNT(p.id_pago) AS Cantidad_Pagos,
    -- Sumamos el resultado de la función para obtener el total en Dólares
    FORMAT(SUM(Reportes.fn_PesosAUSD(p.importe, 'blue')), 'N2') AS [Total Recaudado USD Blue]
FROM Tesoreria.Pago p
INNER JOIN Tesoreria.Persona_CuentaBancaria pcb ON p.id_persona_cuenta = pcb.id_persona_cuenta
INNER JOIN Propiedades.UF_Persona ufp ON pcb.id_persona = ufp.id_persona
INNER JOIN Propiedades.UnidadFuncional uf ON ufp.id_uf = uf.id_uf
INNER JOIN General.Consorcio c ON uf.id_consorcio = c.id_consorcio
GROUP BY c.nombre
ORDER BY SUM(p.importe) DESC;
GO



PRINT '--- FIN SCRIPT DE TESTING (API) ---';
GO