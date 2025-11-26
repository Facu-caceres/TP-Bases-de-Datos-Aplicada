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
    
    PRINT 'Iniciando reprocesamiento de pagos no asociados (Modo Texto Plano)...';

    DECLARE @PagosActualizados INT = 0;

    -- Actualización directa haciendo JOIN por las columnas de texto plano
    UPDATE P
    SET 
        P.id_persona_cuenta = PCB.id_persona_cuenta,
        P.estado = 'Asociado'
    FROM Tesoreria.Pago P
    INNER JOIN Tesoreria.Persona_CuentaBancaria PCB 
        ON P.cbu_origen = PCB.cbu_cvu
    WHERE P.estado = 'No Asociado' 
      AND PCB.activa = 1;

    SET @PagosActualizados = @@ROWCOUNT;

    PRINT 'Proceso finalizado. Se asociaron ' + CAST(@PagosActualizados AS VARCHAR) + ' pagos que estaban pendientes.';
END
GO