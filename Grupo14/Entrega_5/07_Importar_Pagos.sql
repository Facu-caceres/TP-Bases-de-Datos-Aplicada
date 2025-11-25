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
Descripción: SP para importar los pagos desde el archivo pagos_consorcios.csv a la tabla Tesoreria.Pago.
*/
USE [Com5600G14];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_importar_pagos
    @ruta_archivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tabla temporal para la carga masiva de pagos.
    IF OBJECT_ID('tempdb..#TempPagos') IS NOT NULL DROP TABLE #TempPagos;
    CREATE TABLE #TempPagos (
        id_pago VARCHAR(50), 
        fecha VARCHAR(50),
        cbu_cvu VARCHAR(22),
        valor VARCHAR(100)
    );

    -- 2. Carga masiva desde el archivo CSV.
    BEGIN TRY
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = N'
            BULK INSERT #TempPagos
            FROM ''' + @ruta_archivo + N'''
            WITH (
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\n'',
                FIRSTROW = 2,
                CODEPAGE = ''ACP''
            );';
        EXEC sp_executesql @sql;
        DELETE FROM #TempPagos WHERE id_pago IS NULL OR LTRIM(RTRIM(id_pago)) = '';
    END TRY
    BEGIN CATCH
        PRINT 'Error al intentar cargar el archivo CSV de Pagos: ' + @ruta_archivo;
        PRINT ERROR_MESSAGE();
        RETURN;
    END CATCH

    -- 3. Tabla temporal para datos limpios y procesados.
    IF OBJECT_ID('tempdb..#TempPagosClean') IS NOT NULL DROP TABLE #TempPagosClean;
    SELECT
        TRY_CAST(tp.id_pago AS INT) AS id_pago,
        pcb.id_persona_cuenta,
        TRY_CONVERT(DATE, tp.fecha, 103) AS fecha_de_pago,
        TRY_CAST(LTRIM(REPLACE(tp.valor, '$', '')) AS DECIMAL(18, 2)) AS importe, 
        tp.cbu_cvu AS cbu_origen,
        CASE WHEN pcb.id_persona_cuenta IS NOT NULL THEN 'Asociado' ELSE 'No Asociado' END AS estado
    INTO #TempPagosClean
    FROM #TempPagos tp
    LEFT JOIN Tesoreria.Persona_CuentaBancaria pcb ON tp.cbu_cvu = pcb.cbu_cvu;

    -- 4. Actualizar registros existentes en Tesoreria.Pago
    UPDATE Tpag
    SET
        Tpag.id_persona_cuenta = TPC.id_persona_cuenta,
        Tpag.fecha_de_pago = TPC.fecha_de_pago,
        Tpag.importe = TPC.importe,
        Tpag.cbu_origen = TPC.cbu_origen,
        Tpag.estado = TPC.estado
    FROM Tesoreria.Pago AS Tpag
    JOIN #TempPagosClean AS TPC ON Tpag.id_pago = TPC.id_pago;

    -- 5. Insertar nuevos registros en Tesoreria.Pago
    INSERT INTO Tesoreria.Pago (id_pago, id_persona_cuenta, fecha_de_pago, importe, cbu_origen, estado)
    SELECT
        TPC.id_pago,
        TPC.id_persona_cuenta,
        TPC.fecha_de_pago,
        TPC.importe,
        TPC.cbu_origen,
        TPC.estado
    FROM #TempPagosClean AS TPC
    WHERE NOT EXISTS (
        SELECT 1
        FROM Tesoreria.Pago AS Target
        WHERE Target.id_pago = TPC.id_pago
    );

    PRINT 'Proceso de importación de Pagos finalizado.';

    DROP TABLE #TempPagos;
    DROP TABLE #TempPagosClean;
    SET NOCOUNT OFF;
END;
GO