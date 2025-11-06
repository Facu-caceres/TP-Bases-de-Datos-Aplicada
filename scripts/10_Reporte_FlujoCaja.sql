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
Descripción: Creacion de un SP para informar la recaudación semanal por tipo (ord/extra), promedio del período, acumulado.
*/
USE [Com5600_Grupo14_DB];
GO

CREATE OR ALTER PROCEDURE Reportes.sp_reporte_flujo_caja_semanal
    @FechaDesde       date,
    @FechaHasta       date,
    @IdConsorcio      int          = NULL,             -- NULL = todos
    @EstadoPago       varchar(20)  = NULL,             -- 'Asociado' | 'No Asociado' | NULL
    @ModoAsignacion   varchar(20)  = 'Proporcional',   -- 'Proporcional' | 'Total'
    @Salida           varchar(10)  = 'TABLA'           -- 'TABLA' | 'XML'
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1; -- Lunes como primer día de la semana (ISO)

    IF @FechaDesde IS NULL OR @FechaHasta IS NULL
    BEGIN
        RAISERROR('Debe indicar @FechaDesde y @FechaHasta.', 16, 1);
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
            -- CORRECCIÓN: Usar el nombre del mes en español para el JOIN
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
        -- CORRECCIÓN: Joinear usando el nombre del mes (LTRIM/RTRIM por el JSON)
        LEFT JOIN General.Expensa_Consorcio ec
               ON ec.id_consorcio = b.id_consorcio
              AND LTRIM(RTRIM(LOWER(ec.periodo))) = b.mes_es
    ),
    PagoSplit AS (
        SELECT
            SemanaInicio = DATEADD(DAY, 1 - DATEPART(WEEKDAY, CAST(b.fecha_de_pago AS date)), CAST(b.fecha_de_pago AS date)),
            SemanaFin    = DATEADD(DAY, 6 - (DATEPART(WEEKDAY, CAST(b.fecha_de_pago AS date)) - 1), CAST(b.fecha_de_pago AS date)),
            CAST(b.importe * b.ratio_extra                 AS decimal(18,2)) AS ImporteExtra,
            CAST(b.importe * (1 - ISNULL(b.ratio_extra,0)) AS decimal(18,2)) AS ImporteOrdi,
            b.importe AS ImporteTotal,
            b.fecha_de_pago
        FROM PagoTipificado b
    ),
    Semanas AS (
        SELECT
            ps.SemanaInicio,
            ps.SemanaFin,
            SemanaISO   = MIN(DATEPART(ISO_WEEK, ps.fecha_de_pago)),
            AnioCalend  = YEAR(MIN(ps.SemanaInicio)),
            SUM(ps.ImporteOrdi)  AS Recaudacion_Ordinaria,
            SUM(ps.ImporteExtra) AS Recaudacion_Extraordinaria,
            SUM(ps.ImporteTotal) AS Recaudacion_Total
        FROM PagoSplit ps
        GROUP BY ps.SemanaInicio, ps.SemanaFin
    ),
    Resultado AS (
        SELECT
            AnioCalend                 AS Anio,
            SemanaISO,
            SemanaInicio,
            SemanaFin,
            Recaudacion_Ordinaria,
            Recaudacion_Extraordinaria,
            Recaudacion_Total,
            AVG(Recaudacion_Total) OVER () AS PromedioPeriodo,
            SUM(Recaudacion_Total) OVER (
                ORDER BY SemanaInicio
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS Acumulado
        FROM Semanas
    )
    SELECT * INTO #TempResultado FROM Resultado;

    -- Salida condicional (como Reporte 6)
    IF UPPER(@Salida) = 'XML'
    BEGIN
        SELECT
            SemanaInicio               AS [semana/@inicio],
            SemanaFin                  AS [semana/@fin],
            -- Aplicar @ModoAsignacion aquí también
            CASE WHEN UPPER(@ModoAsignacion)='TOTAL' THEN Recaudacion_Total ELSE Recaudacion_Ordinaria END AS [semana/recaudacion/@ordinaria],
            CASE WHEN UPPER(@ModoAsignacion)='TOTAL' THEN 0                 ELSE Recaudacion_Extraordinaria END AS [semana/recaudacion/@extraordinaria],
            Recaudacion_Total          AS [semana/recaudacion/@total],
            PromedioPeriodo            AS [semana/kpis/@promedio_periodo],
            Acumulado                  AS [semana/kpis/@acumulado]
        FROM #TempResultado
        ORDER BY SemanaInicio
        FOR XML PATH('root'), TYPE;
    END
    ELSE
    BEGIN
        SELECT * FROM #TempResultado ORDER BY SemanaInicio;
    END

END
GO