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
Descripción: Creacion de un SP para informar fechas de pagos ordinarios por UF y días entre pagos.
*/

USE [Com5600G14];
GO

CREATE OR ALTER PROCEDURE Reportes.sp_reporte_pagos_intervalo_por_uf
    @FechaDesde             date,
    @FechaHasta             date,
    @IdConsorcio            int          = NULL,
    @EstadoPago             varchar(20)  = 'Asociado',    -- por defecto solo asociados
    @FormatoPeriodo         varchar(10)  = 'YYYY-MM',
    @SoloOrdinariasAsumidas bit          = 1,
    @Salida                 varchar(10)  = 'TABLA'        -- 'TABLA' | 'XML'
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaDesde IS NULL OR @FechaHasta IS NULL
    BEGIN
        RAISERROR('Debe indicar @FechaDesde y @FechaHasta.',16,1);
        RETURN;
    END;

    IF @FechaHasta < @FechaDesde
    BEGIN
        DECLARE @swap date = @FechaDesde;
        SET @FechaDesde = @FechaHasta;
        SET @FechaHasta = @swap;
    END;

    ;WITH Base AS (
        /* Pagos mapeados a UF a través de Persona -> UF_Persona -> UnidadFuncional */
        SELECT
            c.id_consorcio,
            c.nombre                      AS Consorcio,
            uf.id_uf,
            uf.numero                     AS UF_Numero,
            uf.piso,
            uf.departamento,
            CAST(p.fecha_de_pago AS date) AS fecha_pago,
            p.importe,
            CASE @FormatoPeriodo
              WHEN 'MesES' THEN CONCAT(
                    CASE MONTH(p.fecha_de_pago)
                        WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
                        WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo'    WHEN 6 THEN 'junio'
                        WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto'  WHEN 9 THEN 'septiembre'
                        WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
                    END, ' ', YEAR(p.fecha_de_pago))
              ELSE CONVERT(char(7), p.fecha_de_pago, 126)  -- 'YYYY-MM'
            END AS PeriodoEtiqueta
        FROM Tesoreria.Pago p
        LEFT JOIN Tesoreria.Persona_CuentaBancaria pcb ON p.id_persona_cuenta = pcb.id_persona_cuenta
        LEFT JOIN Propiedades.UF_Persona ufp           ON ufp.id_persona      = pcb.id_persona
        LEFT JOIN Propiedades.UnidadFuncional uf       ON uf.id_uf            = ufp.id_uf
        LEFT JOIN General.Consorcio c                  ON c.id_consorcio      = uf.id_consorcio
        WHERE p.fecha_de_pago BETWEEN @FechaDesde AND @FechaHasta
          AND (@EstadoPago  IS NULL OR p.estado = @EstadoPago)
          AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
          AND uf.id_uf IS NOT NULL  -- solo pagos que lograron mapear a una UF
    ),
    Ordenados AS (
        /* Orden por UF y fecha, para calcular el siguiente pago */
        SELECT
            id_consorcio, Consorcio, id_uf, UF_Numero, piso, departamento,
            PeriodoEtiqueta,
            fecha_pago,
            importe,
            LEAD(fecha_pago) OVER (
                PARTITION BY id_uf ORDER BY fecha_pago, importe, id_uf
            ) AS prox_fecha_pago
        FROM Base
    ),
    Resultado AS (
        SELECT
            Consorcio,
            id_uf,
            UF = CONCAT(COALESCE(CAST(piso AS varchar(10)),'?'), '-', COALESCE(departamento,'?'), ' (#', UF_Numero, ')'),
            fecha_pago      AS FechaPago,
            prox_fecha_pago AS ProximoPago,
            CASE WHEN prox_fecha_pago IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, fecha_pago, prox_fecha_pago)
            END             AS DiasHastaSiguiente,
            importe         AS Importe
        FROM Ordenados
    )
    SELECT *
    INTO #ResultadoPagosUF
    FROM Resultado;

    IF UPPER(@Salida) = 'XML'
    BEGIN
        SELECT
            Consorcio,
            id_uf,
            UF,
            FechaPago,
            ProximoPago,
            DiasHastaSiguiente,
            Importe
        FROM #ResultadoPagosUF
        ORDER BY Consorcio, id_uf, FechaPago
        FOR XML PATH('PagoUF'), ROOT('PagosIntervalos'), TYPE;
        RETURN;
    END
    ELSE
    BEGIN
        SELECT
            Consorcio,
            id_uf,
            UF,
            FechaPago,
            ProximoPago,
            DiasHastaSiguiente,
            Importe
        FROM #ResultadoPagosUF
        ORDER BY Consorcio, id_uf, FechaPago;
    END
END
GO