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
Descripción: Creacion de un SP para re-asociar pagos pendientes.

*/

USE [Com5600G14];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_reprocesar_pagos_no_asociados
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Iniciando reprocesamiento de pagos no asociados...';

    DECLARE @PagosActualizados INT = 0;

    -- 1. Tabla temporal para desencriptar CBUs una sola vez
    IF OBJECT_ID('tempdb..#CuentasDesencriptadas') IS NOT NULL DROP TABLE #CuentasDesencriptadas;

    SELECT 
        id_persona_cuenta,
        CAST(DecryptByPassPhrase('Grupo14_Secreto_2025', cbu_hash) AS VARCHAR(100)) AS cbu_plano
    INTO #CuentasDesencriptadas
    FROM Tesoreria.Persona_CuentaBancaria
    WHERE activa = 1;

    -- 2. Actualizamos los pagos cruzando el CBU plano del archivo con el CBU desencriptado de la base.
    UPDATE P
    SET 
        P.id_persona_cuenta = C.id_persona_cuenta,
        P.estado = 'Asociado'
    FROM Tesoreria.Pago P
    INNER JOIN #CuentasDesencriptadas C ON P.cbu_origen = C.cbu_plano
    WHERE P.estado = 'No Asociado';

    SET @PagosActualizados = @@ROWCOUNT;

    PRINT 'Proceso finalizado. Se asociaron ' + CAST(@PagosActualizados AS VARCHAR) + ' pagos que estaban pendientes.';
    
    DROP TABLE #CuentasDesencriptadas;
END
GO