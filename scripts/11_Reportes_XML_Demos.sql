USE [Com5600_Grupo14_DB];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Reportes')
    EXEC('CREATE SCHEMA Reportes');
GO


   -- (asignación PROPORCIONAL por mes según Expensa_Consorcio)
CREATE OR ALTER VIEW REP.VW_FlujoCajaSemanal
AS
WITH PagoBase AS (
    SELECT
        p.id_pago,
        CAST(p.fecha_de_pago AS date) AS fecha_pago,
        CAST(p.importe AS decimal(18,2)) AS importe,
        ca.id_consorcio,

        LOWER(DATENAME(MONTH, p.fecha_de_pago)) AS mes_es
    FROM [Com5600_Grupo14_DB].Tesoreria.Pago p
    LEFT JOIN [Com5600_Grupo14_DB].Tesoreria.Persona_CuentaBancaria pcb
           ON pcb.id_persona_cuenta = p.id_persona_cuenta
    OUTER APPLY (
        SELECT TOP (1) uf.id_consorcio
        FROM [Com5600_Grupo14_DB].Propiedades.UF_Persona ufp
        JOIN [Com5600_Grupo14_DB].Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
        WHERE ufp.id_persona = pcb.id_persona
        ORDER BY ufp.id_uf
    ) ca
    WHERE ca.id_consorcio IS NOT NULL
),
PagoTipificado AS (
    SELECT
        b.*,
        ec.total_ordinarios,
        ec.total_extraordinarios,
        CAST(
            ISNULL(
                NULLIF(ec.total_extraordinarios,0)
                / NULLIF(NULLIF(ec.total_ordinarios,0) + NULLIF(ec.total_extraordinarios,0),0),
                0
            ) AS decimal(18,6)
        ) AS ratio_extra
    FROM PagoBase b
    LEFT JOIN [Com5600_Grupo14_DB].General.Expensa_Consorcio ec
           ON ec.id_consorcio = b.id_consorcio
          AND LTRIM(RTRIM(LOWER(ec.periodo))) = b.mes_es
),
PagoSplit AS (
    SELECT
        -- Semana que inicia en lunes (sin depender de DATEFIRST)
        DATEADD(DAY, -((DATEPART(WEEKDAY, fecha_pago) + 5) % 7), fecha_pago) AS SemanaInicio,
        id_consorcio,
        CAST(importe * (1 - ISNULL(ratio_extra,0)) AS decimal(18,2)) AS ImporteOrdi,
        CAST(importe * ISNULL(ratio_extra,0)       AS decimal(18,2)) AS ImporteExtra,
        importe AS ImporteTotal
    FROM PagoTipificado
),
Agg AS (
    SELECT
        SemanaInicio,
        id_consorcio,
        SUM(ImporteOrdi)  AS Recaud_Ordinaria,
        SUM(ImporteExtra) AS Recaud_Extra,
        SUM(ImporteTotal) AS Recaud_Total
    FROM PagoSplit
    GROUP BY SemanaInicio, id_consorcio
)
SELECT
    SemanaInicio,
    id_consorcio AS IdConsorcio,
    Recaud_Ordinaria,
    Recaud_Extra,
    Recaud_Total,
    SUM(Recaud_Total) OVER (PARTITION BY id_consorcio ORDER BY SemanaInicio
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Acumulado
FROM Agg;
GO

   --XML – Reporte 1 (Flujo de caja semanal)
  -- si @ModoAsignacion='Total' fuerza Extra=0 y Ordi=Total

CREATE OR ALTER PROC REP.SP_FlujoCajaSemanal_XML
    @FechaDesde   date,
    @FechaHasta   date,
    @IdConsorcio  int = NULL,
    @ModoAsignacion varchar(20) = 'Proporcional'
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaDesde IS NULL OR @FechaHasta IS NULL
    BEGIN RAISERROR('Indique @FechaDesde y @FechaHasta',16,1); RETURN; END;

    ;WITH F AS (
        SELECT *
        FROM REP.VW_FlujoCajaSemanal
        WHERE SemanaInicio BETWEEN DATEADD(DAY, -((DATEPART(WEEKDAY, @FechaDesde) + 5) % 7), @FechaDesde)
                              AND DATEADD(DAY, -((DATEPART(WEEKDAY, @FechaHasta) + 5) % 7), @FechaHasta)
          AND (@IdConsorcio IS NULL OR IdConsorcio = @IdConsorcio)
    )
    SELECT
        f.SemanaInicio                                         AS [semana/@inicio],
        DATEADD(DAY, 6, f.SemanaInicio)                        AS [semana/@fin],
        CASE WHEN UPPER(@ModoAsignacion)='TOTAL' THEN f.Recaud_Total ELSE f.Recaud_Ordinaria END AS [semana/recaudacion/@ordinaria],
        CASE WHEN UPPER(@ModoAsignacion)='TOTAL' THEN 0              ELSE f.Recaud_Extra       END AS [semana/recaudacion/@extraordinaria],
        f.Recaud_Total                                         AS [semana/recaudacion/@total],
        AVG(f.Recaud_Total) OVER ()                            AS [semana/kpis/@promedio_periodo],
        f.Acumulado                                            AS [semana/kpis/@acumulado]
    FROM F f
    ORDER BY f.SemanaInicio
    FOR XML PATH('root'), TYPE;
END
GO

  -- XML Reporte 3 (Recaudación por período y procedencia)

CREATE OR ALTER PROC REP.SP_RecaudacionPorProcedencia_XML
    @FechaDesde      date,
    @FechaHasta      date,
    @IdConsorcio     int = NULL,
    @FormatoPeriodo  varchar(10) = 'YYYY-MM',    
    @ModoAsignacion  varchar(20) = 'Proporcional' 
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaDesde IS NULL OR @FechaHasta IS NULL
    BEGIN RAISERROR('Indique @FechaDesde y @FechaHasta',16,1); RETURN; END;

    ;WITH PagoBase AS (
        SELECT
            CAST(DATEFROMPARTS(YEAR(p.fecha_de_pago), MONTH(p.fecha_de_pago), 1) AS date) AS mes_inicio,
            CAST(p.importe AS decimal(18,2)) AS importe,
            ca.id_consorcio,
            LOWER(DATENAME(MONTH, p.fecha_de_pago)) AS mes_es
        FROM [Com5600_Grupo14_DB].Tesoreria.Pago p
        LEFT JOIN [Com5600_Grupo14_DB].Tesoreria.Persona_CuentaBancaria pcb
               ON pcb.id_persona_cuenta = p.id_persona_cuenta
        OUTER APPLY (
            SELECT TOP (1) uf.id_consorcio
            FROM [Com5600_Grupo14_DB].Propiedades.UF_Persona ufp
            JOIN [Com5600_Grupo14_DB].Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
            WHERE ufp.id_persona = pcb.id_persona
            ORDER BY ufp.id_uf
        ) ca
        WHERE p.fecha_de_pago BETWEEN @FechaDesde AND @FechaHasta
          AND ca.id_consorcio IS NOT NULL
          AND (@IdConsorcio IS NULL OR ca.id_consorcio = @IdConsorcio)
    ),
    Mezcla AS (
        SELECT
            b.*,
            ec.total_ordinarios,
            ec.total_extraordinarios,
            CAST(
              ISNULL(
                NULLIF(ec.total_extraordinarios,0)
                / NULLIF(NULLIF(ec.total_ordinarios,0) + NULLIF(ec.total_extraordinarios,0),0),
                0
              ) AS decimal(18,6)
            ) AS ratio_extra
        FROM PagoBase b
        LEFT JOIN [Com5600_Grupo14_DB].General.Expensa_Consorcio ec
               ON ec.id_consorcio = b.id_consorcio
              AND LTRIM(RTRIM(LOWER(ec.periodo))) = b.mes_es
    ),
    Split AS (
        SELECT
            CASE @FormatoPeriodo
                WHEN 'MesES'  THEN CONCAT(LOWER(DATENAME(MONTH, mes_inicio)),' ',YEAR(mes_inicio))
                ELSE CONVERT(char(7), mes_inicio, 126)
            END AS Periodo,
            CAST(importe * CASE WHEN UPPER(@ModoAsignacion)='TOTAL' THEN 1 ELSE (1-ISNULL(ratio_extra,0)) END AS decimal(18,2)) AS Ordinario,
            CAST(importe * CASE WHEN UPPER(@ModoAsignacion)='TOTAL' THEN 0 ELSE ISNULL(ratio_extra,0) END       AS decimal(18,2)) AS Extraordinario,
            importe AS Total,
            mes_inicio
        FROM Mezcla
    ),
    Agg AS (
        SELECT
            Periodo,
            SUM(Ordinario)     AS Ordinario,
            SUM(Extraordinario) AS Extraordinario,
            SUM(Total)          AS Total,
            MIN(mes_inicio)     AS Orden
        FROM Split
        GROUP BY Periodo
    )
    SELECT
        Periodo                   AS [periodo/@etiqueta],
        Ordinario                 AS [periodo/importe/@ordinario],
        Extraordinario            AS [periodo/importe/@extraordinario],
        Total                     AS [periodo/importe/@total]
    FROM Agg
    ORDER BY Orden
    FOR XML PATH('root'), TYPE;
END
GO


-- ===================== PRUEBA =======================

-- Reporte 1
EXEC REP.SP_FlujoCajaSemanal_XML
  @FechaDesde='2025-03-01', @FechaHasta='2025-06-30',
  @IdConsorcio=NULL, @ModoAsignacion='Proporcional';

-- Reporte 3
EXEC REP.SP_RecaudacionPorProcedencia_XML
  @FechaDesde='2025-01-01', @FechaHasta='2025-12-31',
  @IdConsorcio=NULL, @FormatoPeriodo='YYYY-MM', @ModoAsignacion='Proporcional';
