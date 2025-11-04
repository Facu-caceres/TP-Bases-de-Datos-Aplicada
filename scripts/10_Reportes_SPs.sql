/* 
   Entrega 6 – Reportes & API
   Crea SPs para los 6 reportes solicitados.
   Esquema sugerido: REP
    */
USE [Com5600_Grupo14_DB];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Reportes')
    EXEC('CREATE SCHEMA Reportes');
GO

/* =========================
   Reporte 1 – Flujo de caja semanal
   Params:
     @FechaDesde, @FechaHasta, @IdConsorcio (NULL=todos)
   Output: recaudación semanal por tipo (ord/extra), promedio del período, acumulado.
   ========================= */


CREATE OR ALTER PROCEDURE Reportes.sp_reporte_flujo_caja_semanal
    @FechaDesde       date,
    @FechaHasta       date,
    @IdConsorcio      int          = NULL,             -- NULL = todos
    @EstadoPago       varchar(20)  = NULL,             -- 'Asociado' | 'No Asociado' | NULL
    @ModoAsignacion   varchar(20)  = 'Proporcional'    -- 'Proporcional' | 'Total'
AS
BEGIN
    SET NOCOUNT ON;

    -- Usar lunes como inicio de semana (ISO)
    SET DATEFIRST 1;

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
            CONVERT(char(7), p.fecha_de_pago, 126) AS periodo_ym  -- 'YYYY-MM'
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
              AND ec.periodo      = b.periodo_ym   -- ajustar si difiere el formato del período
    ),
    PagoSplit AS (
        SELECT
            -- Inicio de semana (lunes) según ISO (DATEFIRST 1)
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
            SemanaISO   = MIN(DATEPART(ISO_WEEK, ps.fecha_de_pago)), -- para referencia
            AnioCalend  = YEAR(MIN(ps.SemanaInicio)),                 -- año del lunes de la semana
            SUM(ps.ImporteOrdi)  AS Recaudacion_Ordinaria,
            SUM(ps.ImporteExtra) AS Recaudacion_Extraordinaria,
            SUM(ps.ImporteTotal) AS Recaudacion_Total
        FROM PagoSplit ps
        GROUP BY ps.SemanaInicio, ps.SemanaFin
    )
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
    ORDER BY SemanaInicio;
END
GO
-- chequear los pagos extraordinarios
/* ================== PRUEBAS RÁPIDAS ==================*/
EXEC Reportes.sp_reporte_flujo_caja_semanal
     @FechaDesde = '2025-01-01',
     @FechaHasta = '2025-12-31',
     @IdConsorcio = NULL,
     @EstadoPago  = NULL,
     @ModoAsignacion = 'Proporcional';

-- SELECT TOP(1) id_consorcio FROM General.Consorcio ORDER BY id_consorcio;
EXEC Reportes.sp_reporte_flujo_caja_semanal
     @FechaDesde = '2025-03-01',
     @FechaHasta = '2025-06-30',
     @IdConsorcio = 1,
     @EstadoPago  = 'Asociado',
     @ModoAsignacion = 'Total';
-- ===================================================== */

/*SELECT id_consorcio, periodo, total_ordinarios, total_extraordinarios
FROM General.Expensa_Consorcio
WHERE id_consorcio = 1                      -- cambialo si hace falta
  AND (periodo LIKE '2025-03%' OR periodo LIKE '2025-04%' 
       OR periodo LIKE '2025-05%' OR periodo LIKE '2025-06%')
ORDER BY periodo;*/

/* =========================
   Reporte 2 – Recaudación por mes y departamento (tabla cruzada)
   Params: @PeriodoDesdeYM, @PeriodoHastaYM, @IdConsorcio
   Asumo PeriodoYm = 'YYYYMM' en Expensa o derive de FechaPago.
   ========================= */

   -- 1) Consorcios (por si faltara alguno referenciado por UF)
EXEC Importacion.sp_importar_consorcios  @ruta_archivo = N'C:\Users\MauroTS\Desktop\BASE DE DATOS APLICADA\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\datos varios.xlsx';           -- hoja Consorcios

-- 2) Unidades Funcionales: crea/actualiza UF y setea piso/departamento, etc.
EXEC Importacion.sp_importar_uf          @ruta_archivo = N'C:\Users\MauroTS\Desktop\BASE DE DATOS APLICADA\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\UF por consorcio.txt';

-- 3) Personas + Cuentas (necesario para mapear CBU→persona)
EXEC Importacion.sp_importar_personas    @ruta_archivo = N'C:\Users\MauroTS\Desktop\BASE DE DATOS APLICADA\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\Inquilino-propietarios-datos.csv';

-- 4) Relaciones Persona↔UF (usa CBU y nro UF para resolver los IDs)
EXEC Importacion.sp_importar_uf_persona  @ruta_archivo = N'C:\Users\MauroTS\Desktop\BASE DE DATOS APLICADA\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\Inquilino-propietarios-UF.csv';

CREATE OR ALTER PROCEDURE Reportes.sp_reporte_recaudacion_mes_depto
    @FechaDesde  date,
    @FechaHasta  date,
    @IdConsorcio int         = NULL,         -- NULL = todos
    @EstadoPago  varchar(20) = NULL,         -- 'Asociado' | 'No Asociado' | NULL
    @FormatoMes  varchar(10) = 'YYYY-MM'     -- 'YYYY-MM' | 'MesES'
AS
BEGIN
    SET NOCOUNT ON;

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

    ;WITH Base AS (
        SELECT
            uf.departamento,
            p.importe,
            CAST(DATEFROMPARTS(YEAR(p.fecha_de_pago), MONTH(p.fecha_de_pago), 1) AS date) AS mes_inicio,
            CASE @FormatoMes
              WHEN 'MesES' THEN
                CONCAT(
                    CASE MONTH(p.fecha_de_pago)
                      WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
                      WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo'    WHEN 6 THEN 'junio'
                      WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto'  WHEN 9 THEN 'septiembre'
                      WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
                    END, ' ', YEAR(p.fecha_de_pago)
                )
              ELSE CONVERT(char(7), p.fecha_de_pago, 126) -- 'YYYY-MM'
            END AS rotulo_mes
        FROM Tesoreria.Pago p
        LEFT JOIN Tesoreria.Persona_CuentaBancaria pcb ON p.id_persona_cuenta = pcb.id_persona_cuenta
        LEFT JOIN Propiedades.UF_Persona ufp           ON pcb.id_persona = ufp.id_persona
        LEFT JOIN Propiedades.UnidadFuncional uf       ON ufp.id_uf = uf.id_uf
        WHERE p.fecha_de_pago BETWEEN @FechaDesde AND @FechaHasta
          AND (@EstadoPago  IS NULL OR p.estado = @EstadoPago)
          AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
    )
    SELECT
        rotulo_mes,
        UPPER(LTRIM(RTRIM(departamento))) AS departamento,
        SUM(importe) AS importe,
        MIN(mes_inicio) AS mes_inicio
    INTO #FuentePivot
    FROM Base
    GROUP BY rotulo_mes, UPPER(LTRIM(RTRIM(departamento)));

    -- Mapeo para ordenar por mes
    SELECT rotulo_mes, MIN(mes_inicio) AS mes_inicio
    INTO #OrdenMes
    FROM #FuentePivot
    GROUP BY rotulo_mes;

    DECLARE @cols nvarchar(max) =
        STUFF((
            SELECT DISTINCT ',' + QUOTENAME(departamento)
            FROM #FuentePivot
            WHERE departamento IS NOT NULL AND departamento <> ''
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 1, '');

    IF (@cols IS NULL OR LEN(@cols)=0)
    BEGIN
        -- No hay departamentos/UF relacionados: devolver esquema vacío
        SELECT CAST(NULL AS nvarchar(20)) AS Mes, CAST(NULL AS decimal(18,2)) AS Total
        WHERE 1=0;
        RETURN;
    END;

    -- Expresión para Total: ISNULL([A],0) + ISNULL([B],0) + ...
    DECLARE @totalExpr nvarchar(max) =
        STUFF((
            SELECT DISTINCT ' + ISNULL(' + QUOTENAME(departamento) + ',0)'
            FROM #FuentePivot
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 3, '');

    DECLARE @sql nvarchar(max) = N'
        WITH PivotSrc AS (
            SELECT rotulo_mes, departamento, importe
            FROM #FuentePivot
        )
        SELECT p.rotulo_mes AS Mes,
               ' + @cols + ',
               ' + @totalExpr + ' AS Total
        FROM (
            SELECT rotulo_mes, departamento, importe
            FROM PivotSrc
        ) s
        PIVOT (
            SUM(importe) FOR departamento IN (' + @cols + ')
        ) p
        JOIN #OrdenMes om ON om.rotulo_mes = p.rotulo_mes
        ORDER BY om.mes_inicio;';

    -- PRINT @sql; -- descomentá para ver el SQL generado
    EXEC sp_executesql @sql;
END
GO

/* =================== PRUEBAS RÁPIDAS ===================*/
-- 1) Todos los consorcios, todos los pagos, YYYY-MM
EXEC Reportes.sp_reporte_recaudacion_mes_depto
  @FechaDesde = '2025-01-01',
  @FechaHasta = '2025-12-31',
  @IdConsorcio = NULL,
  @EstadoPago  = NULL,
  @FormatoMes  = 'YYYY-MM';

-- 2) Un consorcio puntual (cambiar ID), Mes en español
--SELECT TOP(1) id_consorcio FROM General.Consorcio ORDER BY id_consorcio;
EXEC Reportes.sp_reporte_recaudacion_mes_depto
  @FechaDesde = '2025-03-01',
  @FechaHasta = '2025-06-30',
  @IdConsorcio = 1,
  @EstadoPago  = NULL,
  @FormatoMes  = 'MesES';

  EXEC Reportes.sp_reporte_recaudacion_mes_depto
  @FechaDesde='2025-01-01', @FechaHasta='2025-12-31',
  @IdConsorcio=NULL, @EstadoPago='Asociado', @FormatoMes='YYYY-MM';
-- ====================================================== 

/* =========================
   Reporte 3 – Cruzado por procedencia (ord/extra/etc.) según período
   Params: @PeriodoDesdeYM, @PeriodoHastaYM, @IdConsorcio
   (Devuelve pivot por TipoPago)
   ========================= */

CREATE OR ALTER PROCEDURE Reportes.sp_reporte_recaudacion_tipo_periodo
    @FechaDesde      date,
    @FechaHasta      date,
    @IdConsorcio     int          = NULL,            -- NULL = todos
    @EstadoPago      varchar(20)  = NULL,            -- 'Asociado' | 'No Asociado' | NULL
    @FormatoPeriodo  varchar(10)  = 'YYYY-MM',       -- 'YYYY-MM' | 'MesES'
    @ModoAsignacion  varchar(20)  = 'Proporcional'   -- 'Proporcional' | 'Total'
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

    /* -------- 1) Pagos con (posible) consorcio y período (mes) -------- */
    ;WITH PagoBase AS (
        SELECT
            p.id_pago,
            p.fecha_de_pago,
            CAST(p.importe AS decimal(18,2)) AS importe,
            p.estado,
            ca.id_consorcio,
            CAST(DATEFROMPARTS(YEAR(p.fecha_de_pago), MONTH(p.fecha_de_pago), 1) AS date) AS mes_inicio,
            CONVERT(char(7), p.fecha_de_pago, 126) AS periodo_ym,     -- 'YYYY-MM'
            /* nombre del mes en español para unir contra Expensa_Consorcio.periodo (que viene del JSON) */
            CASE DATEPART(MONTH, p.fecha_de_pago)
              WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
              WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo'    WHEN 6 THEN 'junio'
              WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto'  WHEN 9 THEN 'septiembre'
              WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
            END AS mes_es
        FROM Tesoreria.Pago p
        LEFT JOIN Tesoreria.Persona_CuentaBancaria pcb
               ON pcb.id_persona_cuenta = p.id_persona_cuenta
        /* Elegimos UN consorcio por persona (primera UF) para evitar duplicar pagos */
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
    /* -------- 2) Unimos a Expensa_Consorcio para obtener la mezcla del mes -------- */
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
              AND LTRIM(RTRIM(LOWER(ec.periodo))) = b.mes_es    -- el JSON guarda el mes como texto (p.ej., 'abril')
    ),
    /* -------- 3) Partimos cada pago en ordinario / extraordinario -------- */
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
    /* -------- 4) Agregamos por período -------- */
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
    /* -------- 5) Tabla cruzada final (columnas fijas) -------- */
    SELECT
        Periodo,
        Ordinario,
        Extraordinario,
        Total
    FROM Agregado
    ORDER BY OrdenPeriodo;
END
GO

/* =================== PRUEBAS RÁPIDAS ===================*/
-- 1) Todos los consorcios, todos los pagos, período 'YYYY-MM', separación proporcional
EXEC Reportes.sp_reporte_recaudacion_tipo_periodo
  @FechaDesde='2025-01-01', @FechaHasta='2025-12-31',
  @IdConsorcio=NULL, @EstadoPago=NULL,
  @FormatoPeriodo='YYYY-MM', @ModoAsignacion='Proporcional';

-- 2) Un consorcio puntual (cambiar ID), solo 'Asociado', período en español y modo 'Total'
-- SELECT TOP(1) id_consorcio FROM General.Consorcio ORDER BY id_consorcio;
EXEC Reportes.sp_reporte_recaudacion_tipo_periodo
  @FechaDesde='2025-03-01', @FechaHasta='2025-06-30',
  @IdConsorcio=1, @EstadoPago='Asociado',
  @FormatoPeriodo='MesES', @ModoAsignacion='Total';
-- ====================================================== 


/* =========================
   Reporte 4 – Top 5 meses con mayores Gastos e Ingresos
   Params: @AnioDesde, @AnioHasta, @IdConsorcio
   Ingresos: sum(Pago.Importe). Gastos: sum(Gasto.Importe).
   ========================= */
IF OBJECT_ID('REP.SP_TopMeses_GastosIngresos') IS NOT NULL DROP PROC REP.SP_TopMeses_GastosIngresos;
GO
CREATE PROC REP.SP_TopMeses_GastosIngresos
    @AnioDesde int,
    @AnioHasta int,
    @IdConsorcio int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Ingresos AS (
        SELECT CONVERT(char(7), p.FechaPago, 120) AS PeriodoY_M,
               SUM(p.Importe) AS TotalIngresos
        FROM dbo.Pago p
        INNER JOIN dbo.UnidadFuncional uf ON uf.IdUF = p.IdUF
        WHERE YEAR(p.FechaPago) BETWEEN @AnioDesde AND @AnioHasta
          AND (@IdConsorcio IS NULL OR uf.IdConsorcio = @IdConsorcio)
        GROUP BY CONVERT(char(7), p.FechaPago, 120)
    ),
    Gastos AS (
        SELECT CONVERT(char(7), g.FechaGasto, 120) AS PeriodoY_M,
               SUM(g.Importe) AS TotalGastos
        FROM dbo.Gasto g
        WHERE YEAR(g.FechaGasto) BETWEEN @AnioDesde AND @AnioHasta
        GROUP BY CONVERT(char(7), g.FechaGasto, 120)
    )
    SELECT TOP (5) 'MAYORES_INGRESOS' AS Tipo, i.PeriodoY_M, i.TotalIngresos
    FROM Ingresos i
    ORDER BY i.TotalIngresos DESC;

    SELECT TOP (5) 'MAYORES_GASTOS' AS Tipo, g.PeriodoY_M, g.TotalGastos
    FROM Gastos g
    ORDER BY g.TotalGastos DESC;
END
GO

/* =========================
   Reporte 5 – Top 3 propietarios con mayor morosidad
   Params: @PeriodoDesdeYM, @PeriodoHastaYM, @IdConsorcio
   Definición “morosidad” (ajustable):
     deuda = sum(Expensa emitida) – sum(Pagos aplicados) en el rango
   ========================= */
IF OBJECT_ID('REP.SP_TopPropietarios_Morosidad') IS NOT NULL DROP PROC REP.SP_TopPropietarios_Morosidad;
GO
CREATE PROC REP.SP_TopPropietarios_Morosidad
    @PeriodoDesdeYM char(6),
    @PeriodoHastaYM char(6),
    @IdConsorcio int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ExpensasPeriodo AS (
        SELECT e.IdUF, SUM(e.Importe) AS TotalExpensas
        FROM dbo.Expensa e
        INNER JOIN dbo.UnidadFuncional uf ON uf.IdUF = e.IdUF
        WHERE e.PeriodoYm BETWEEN @PeriodoDesdeYM AND @PeriodoHastaYM
          AND (@IdConsorcio IS NULL OR uf.IdConsorcio = @IdConsorcio)
        GROUP BY e.IdUF
    ),
    PagosPeriodo AS (
        SELECT p.IdUF, SUM(p.Importe) AS TotalPagos
        FROM dbo.Pago p
        INNER JOIN dbo.UnidadFuncional uf ON uf.IdUF = p.IdUF
        WHERE CONVERT(char(6),p.FechaPago,112) BETWEEN @PeriodoDesdeYM AND @PeriodoHastaYM
          AND (@IdConsorcio IS NULL OR uf.IdConsorcio = @IdConsorcio)
        GROUP BY p.IdUF
    ),
    DeudaPorUF AS (
        SELECT COALESCE(e.IdUF, pp.IdUF) AS IdUF,
               COALESCE(e.TotalExpensas,0) - COALESCE(pp.TotalPagos,0) AS Deuda
        FROM ExpensasPeriodo e
        FULL JOIN PagosPeriodo pp ON pp.IdUF = e.IdUF
    ),
    PropietariosConDeuda AS (
        SELECT p.IdPropietario,
               pr.Apellido + ', ' + pr.Nombre AS Propietario,
               pr.DNI, pr.Email, pr.Telefono,
               SUM(d.Deuda) AS DeudaTotal
        FROM DeudaPorUF d
        INNER JOIN dbo.PropietarioUF p ON p.IdUF = d.IdUF
        INNER JOIN dbo.Propietario pr ON pr.IdPropietario = p.IdPropietario
        GROUP BY p.IdPropietario, pr.Apellido, pr.Nombre, pr.DNI, pr.Email, pr.Telefono
    )
    SELECT TOP (3) *
    FROM PropietariosConDeuda
    WHERE DeudaTotal > 0
    ORDER BY DeudaTotal DESC;
END
GO

/* =========================
   Reporte 6 – Fechas de pagos ordinarios por UF y días entre pagos
   Params: @PeriodoDesde, @PeriodoHasta, @IdConsorcio
   ========================= */
IF OBJECT_ID('REP.SP_DiasEntrePagos_Ordinarios') IS NOT NULL DROP PROC REP.SP_DiasEntrePagos_Ordinarios;
GO
CREATE PROC REP.SP_DiasEntrePagos_Ordinarios
    @PeriodoDesde date,
    @PeriodoHasta date,
    @IdConsorcio int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH P AS (
        SELECT p.IdUF, p.FechaPago,
               ROW_NUMBER() OVER (PARTITION BY p.IdUF ORDER BY p.FechaPago) AS rn
        FROM dbo.Pago p
        INNER JOIN dbo.UnidadFuncional uf ON uf.IdUF = p.IdUF
        WHERE UPPER(p.TipoPago) = 'ORDINARIO'
          AND p.FechaPago BETWEEN @PeriodoDesde AND @PeriodoHasta
          AND (@IdConsorcio IS NULL OR uf.IdConsorcio = @IdConsorcio)
    )
    SELECT 
        u.IdUF,
        u.Piso, u.Depto,
        p1.FechaPago AS FechaPagoActual,
        p2.FechaPago AS FechaPagoSiguiente,
        DATEDIFF(day, p1.FechaPago, p2.FechaPago) AS DiasEntrePagos
    FROM P p1
    LEFT JOIN P p2
           ON p2.IdUF = p1.IdUF AND p2.rn = p1.rn + 1
    INNER JOIN dbo.UnidadFuncional u ON u.IdUF = p1.IdUF
    ORDER BY u.IdUF, FechaPagoActual;
END
GO
