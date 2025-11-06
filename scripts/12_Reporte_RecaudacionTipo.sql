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
Descripción: Creacion de un SP para informar la recaudación por procedencia (ordinario/extraordinario) según período.
*/

USE [Com5600_Grupo14_DB];
GO

CREATE OR ALTER PROCEDURE Reportes.sp_reporte_recaudacion_tipo_periodo
    @FechaDesde      date,
    @FechaHasta      date,
    @IdConsorcio     int          = NULL,            -- NULL = todos
    @EstadoPago      varchar(20)  = NULL,            -- 'Asociado' | 'No Asociado' | NULL
    @FormatoPeriodo  varchar(10)  = 'YYYY-MM',       -- 'YYYY-MM' | 'MesES'
    @ModoAsignacion  varchar(20)  = 'Proporcional',  -- 'Proporcional' | 'Total'
    @Salida          varchar(10)  = 'TABLA'          -- 'TABLA' | 'XML'
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

    ;WITH PagoBase AS (
        SELECT
            p.id_pago,
            p.fecha_de_pago,
            CAST(p.importe AS decimal(18,2)) AS importe,
            p.estado,
            ca.id_consorcio,
            CAST(DATEFROMPARTS(YEAR(p.fecha_de_pago), MONTH(p.fecha_de_pago), 1) AS date) AS mes_inicio,
            CASE DATEPART(MONTH, p.fecha_de_pago)
              WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
              WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo'    WHEN 6 THEN 'junio'
              WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto'  WHEN 9 THEN 'septiembre'
              WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
            END AS mes_es
        FROM Tesoreria.Pago p
        LEFT JOIN Tesoreria.Persona_CuentaBancaria pcb
               ON pcb.id_persona_cuenta = p.id_persona_cuenta
        OUTER APPLY (
            SELECT TOP (1) c.id_consorcio
            FROM Propiedades.UF_Persona ufp
            JOIN Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
            JOIN General.Consorcio c            ON c.id_consorcio = uf.id_consorcio
            WHERE ufp.id_persona = pcb.id_persona
            ORDER BY ufp.id_uf
        ) ca
        WHERE p.fecha_de_pago BETWEEN @FechaDesde AND @FechaHasta
          AND (@EstadoPago  IS NULL OR p.estado = @EstadoPago)
          AND (@IdConsorcio IS NULL OR ca.id_consorcio = @IdConsorcio)
    ),
    PagoTipificado AS (
        SELECT
            b.*,
            ec.total_ordinarios,
            ec.total_extraordinarios,
            CASE
              WHEN UPPER(@ModoAsignacion) = 'TOTAL' THEN CAST(0 AS decimal(18,6))
              ELSE CAST(
                    ISNULL(
                        NULLIF(ec.total_extraordinarios,0)
                        / NULLIF( (NULLIF(ec.total_ordinarios,0) + NULLIF(ec.total_extraordinarios,0)), 0 ),
                        0
                    ) AS decimal(18,6)
                  )
            END AS ratio_extra
        FROM PagoBase b
        LEFT JOIN General.Expensa_Consorcio ec
               ON ec.id_consorcio = b.id_consorcio
              AND LTRIM(RTRIM(LOWER(ec.periodo))) = b.mes_es
    ),
    PagoSplit AS (
        SELECT
            b.mes_inicio,
            CASE @FormatoPeriodo
                WHEN 'MesES' THEN
                    CONCAT(
                        CASE MONTH(b.mes_inicio)
                          WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
                          WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo'    WHEN 6 THEN 'junio'
                          WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto'  WHEN 9 THEN 'septiembre'
                          WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
                        END,
                        ' ', YEAR(b.mes_inicio)
                    )
                ELSE CONVERT(char(7), b.mes_inicio, 126)
            END AS Periodo,
            CAST(b.importe * (1 - ISNULL(b.ratio_extra,0)) AS decimal(18,2)) AS ImporteOrdinario,
            CAST(b.importe * ISNULL(b.ratio_extra,0)       AS decimal(18,2)) AS ImporteExtraordinario,
            b.importe AS ImporteTotal
        FROM PagoTipificado b
    ),
    Agregado AS (
        SELECT
            Periodo,
            SUM(ImporteOrdinario)     AS Ordinario,
            SUM(ImporteExtraordinario) AS Extraordinario,
            SUM(ImporteTotal)          AS Total,
            MIN(mes_inicio)            AS OrdenPeriodo
        FROM PagoSplit
        GROUP BY Periodo
    )
    SELECT * INTO #TempResultado FROM Agregado;

    -- Salida condicional
    IF UPPER(@Salida) = 'XML'
    BEGIN
        SELECT
            Periodo        AS [periodo/@etiqueta],
            Ordinario      AS [periodo/importe/@ordinario],
            Extraordinario AS [periodo/importe/@extraordinario],
            Total          AS [periodo/importe/@total]
        FROM #TempResultado
        ORDER BY OrdenPeriodo
        FOR XML PATH('root'), TYPE;
    END
    ELSE
    BEGIN
        SELECT
            Periodo,
            Ordinario,
            Extraordinario,
            Total
        FROM #TempResultado
        ORDER BY OrdenPeriodo;
    END
END
GO