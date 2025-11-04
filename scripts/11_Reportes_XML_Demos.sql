/* =========================================================
   06_03_Reportes_XML_Demos.sql
   Crea una VIEW de apoyo y 2 SPs que devuelven XML:
   - REP.VW_FlujoCajaSemanal
   - REP.SP_FlujoCajaSemanal_XML
   - REP.SP_RecaudacionPorProcedencia_XML
   Requiere que existan las tablas base y el esquema REP.
   ========================================================= */

USE [Com5600_Grupo14_DB];
GO
/*
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'REP')
    EXEC('CREATE SCHEMA REP');
GO*/

-- 1) VIEW de apoyo para el Reporte 1 (flujo semanal)
IF OBJECT_ID('REP.VW_FlujoCajaSemanal') IS NOT NULL DROP VIEW REP.VW_FlujoCajaSemanal;
GO
CREATE VIEW REP.VW_FlujoCajaSemanal AS
WITH PagosFiltrados AS (
    SELECT p.id_pago, p.fecha_de_pago, p.Importe, uf.IdConsorcio --uf no tiene id de consorcio
    FROM Tesoreria.Pago p
    INNER JOIN Propiedades.UnidadFuncional uf ON uf.id_uf = p.IdUF --no se puede igualar por uf porque pagos no tiene uf
),
Semanas AS (
    SELECT DATEADD(week, DATEDIFF(week, 0, FechaPago), 0) AS SemanaInicio,
           TipoPago, SUM(Importe) AS Monto, IdConsorcio
    FROM PagosFiltrados
    GROUP BY DATEADD(week, DATEDIFF(week, 0, FechaPago), 0), TipoPago, IdConsorcio
),
SumaSemanal AS (
    SELECT SemanaInicio, IdConsorcio,
           SUM(CASE WHEN TipoPago='ORDINARIO' THEN Monto ELSE 0 END) AS Recaud_Ordinaria,
           SUM(CASE WHEN TipoPago<>'ORDINARIO' THEN Monto ELSE 0 END) AS Recaud_Extra,
           SUM(Monto) AS Recaud_Total
    FROM Semanas
    GROUP BY SemanaInicio, IdConsorcio
),
ConAcumulado AS (
    SELECT *,
           SUM(Recaud_Total) OVER (
               PARTITION BY IdConsorcio
               ORDER BY SemanaInicio
               ROWS UNBOUNDED PRECEDING
           ) AS Acumulado
    FROM SumaSemanal
)
SELECT * FROM ConAcumulado;
GO

-- 2) SP XML del Reporte 1
IF OBJECT_ID('REP.SP_FlujoCajaSemanal_XML') IS NOT NULL DROP PROC REP.SP_FlujoCajaSemanal_XML;
GO
CREATE PROC REP.SP_FlujoCajaSemanal_XML
    @FechaDesde date,
    @FechaHasta date,
    @IdConsorcio int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        cs.SemanaInicio                         AS [semana/@inicio],
        DATEADD(day,6,cs.SemanaInicio)          AS [semana/@fin],
        cs.Recaud_Ordinaria                     AS [semana/recaudacion/@ordinaria],
        cs.Recaud_Extra                         AS [semana/recaudacion/@extraordinaria],
        cs.Recaud_Total                         AS [semana/recaudacion/@total],
        AVG(cs.Recaud_Total) OVER ()            AS [semana/kpis/@promedio_periodo],
        cs.Acumulado                            AS [semana/kpis/@acumulado]
    FROM REP.VW_FlujoCajaSemanal cs
    WHERE cs.SemanaInicio BETWEEN DATEADD(week, DATEDIFF(week,0,@FechaDesde), 0)
                              AND DATEADD(week, DATEDIFF(week,0,@FechaHasta), 0)
      AND (@IdConsorcio IS NULL OR cs.IdConsorcio = @IdConsorcio)
    ORDER BY cs.SemanaInicio
    FOR XML PATH('root'), TYPE;
END
GO

-- 3) SP XML del Reporte 3 (procedencia por período)
IF OBJECT_ID('REP.SP_RecaudacionPorProcedencia_XML') IS NOT NULL DROP PROC REP.SP_RecaudacionPorProcedencia_XML;
GO
CREATE PROC REP.SP_RecaudacionPorProcedencia_XML
    @PeriodoDesdeYM char(6),
    @PeriodoHastaYM char(6),
    @IdConsorcio int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Base AS (
        SELECT 
            CONVERT(char(6),p.FechaPago,112) AS PeriodoYM,
            UPPER(p.TipoPago)                AS Tipo,
            p.Importe,
            uf.IdConsorcio
        FROM dbo.Pago p
        INNER JOIN dbo.UnidadFuncional uf ON uf.IdUF = p.IdUF
        WHERE CONVERT(char(6),p.FechaPago,112) BETWEEN @PeriodoDesdeYM AND @PeriodoHastaYM
          AND (@IdConsorcio IS NULL OR uf.IdConsorcio = @IdConsorcio)
    ),
    Agg AS (
        SELECT PeriodoYM,
               SUM(CASE WHEN Tipo='ORDINARIO' THEN Importe ELSE 0 END)           AS Ordinario,
               SUM(CASE WHEN Tipo='EXTRAORDINARIO' THEN Importe ELSE 0 END)      AS Extraordinario,
               SUM(CASE WHEN Tipo NOT IN ('ORDINARIO','EXTRAORDINARIO') THEN Importe ELSE 0 END) AS Otros,
               SUM(Importe)                                                      AS Total
        FROM Base
        GROUP BY PeriodoYM
    )
    SELECT
        PeriodoYM       AS [periodo/@ym],
        Ordinario       AS [periodo/importe/@ordinario],
        Extraordinario  AS [periodo/importe/@extraordinario],
        Otros           AS [periodo/importe/@otros],
        Total           AS [periodo/importe/@total]
    FROM Agg
    ORDER BY PeriodoYM
    FOR XML PATH('root'), TYPE;
END
GO
