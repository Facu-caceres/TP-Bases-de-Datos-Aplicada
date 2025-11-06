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
  /*
   -- 1) Consorcios (por si faltara alguno referenciado por UF) 
   EXEC Importacion.sp_importar_consorcios @ruta_archivo = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\datos varios.xlsx'; 
   -- hoja Consorcios -- 2) Unidades Funcionales: crea/actualiza UF y setea piso/departamento, etc. 
   EXEC Importacion.sp_importar_uf @ruta_archivo = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\UF por consorcio.txt'; 
   -- 3) Personas + Cuentas (necesario para mapear CBU→persona) 
   EXEC Importacion.sp_importar_personas @ruta_archivo = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\Inquilino-propietarios-datos.csv'; 
   -- 4) Relaciones Persona↔UF (usa CBU y nro UF para resolver los IDs) 
   EXEC Importacion.sp_importar_uf_persona @ruta_archivo = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\Inquilino-propietarios-UF.csv';

   GO*/


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

/* =========================
   Reporte 4 – Top 5 meses con mayores Gastos e Ingresos
   Params: @AnioDesde, @AnioHasta, @IdConsorcio
   Ingresos: sum(Pago.Importe). Gastos: sum(Gasto.Importe).
   ========================= */

CREATE OR ALTER PROCEDURE Reportes.sp_reporte_top5_gastos_ingresos
    @FechaDesde     date,
    @FechaHasta     date,
    @IdConsorcio    int         = NULL,         -- NULL = todos
    @EstadoPago     varchar(20) = NULL,         -- 'Asociado' | 'No Asociado' | NULL
    @FormatoPeriodo varchar(10) = 'YYYY-MM'     -- para INGRESOS: 'YYYY-MM' | 'MesES'
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

    /* =======================
       1) INGRESOS por mes
       ======================= */
    ;WITH IngresosBase AS (
        SELECT
            CAST(DATEFROMPARTS(YEAR(p.fecha_de_pago), MONTH(p.fecha_de_pago), 1) AS date) AS mes_inicio,
            p.importe,
            ca.id_consorcio
        FROM Tesoreria.Pago p
        LEFT JOIN Tesoreria.Persona_CuentaBancaria pcb
               ON pcb.id_persona_cuenta = p.id_persona_cuenta
        OUTER APPLY (
            SELECT TOP (1) uf.id_consorcio
            FROM Propiedades.UF_Persona ufp
            JOIN Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
            WHERE ufp.id_persona = pcb.id_persona
            ORDER BY ufp.id_uf
        ) ca
        WHERE p.fecha_de_pago BETWEEN @FechaDesde AND @FechaHasta
          AND (@EstadoPago  IS NULL OR p.estado = @EstadoPago)
          AND (@IdConsorcio IS NULL OR ca.id_consorcio = @IdConsorcio)
    ),
    IngresosAgg AS (
        SELECT
            CASE @FormatoPeriodo
                WHEN 'MesES' THEN
                    CONCAT(
                        CASE MONTH(mes_inicio)
                          WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
                          WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo'    WHEN 6 THEN 'junio'
                          WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto'  WHEN 9 THEN 'septiembre'
                          WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
                        END, ' ', YEAR(mes_inicio)
                    )
                ELSE CONVERT(char(7), mes_inicio, 126)  -- YYYY-MM
            END AS Periodo,
            SUM(importe) AS TotalIngresos,
            MIN(mes_inicio) AS Orden
        FROM IngresosBase
        GROUP BY CASE @FormatoPeriodo
                    WHEN 'MesES' THEN CONCAT(
                        CASE MONTH(mes_inicio)
                          WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
                          WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo'    WHEN 6 THEN 'junio'
                          WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto'  WHEN 9 THEN 'septiembre'
                          WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
                        END, ' ', YEAR(mes_inicio)
                    )
                    ELSE CONVERT(char(7), mes_inicio, 126)
                 END
    )
    SELECT TOP (5)
        Periodo, TotalIngresos
    FROM IngresosAgg
    ORDER BY TotalIngresos DESC, Orden ASC;

    /* =======================
       2) GASTOS por mes
       ======================= */
    ;WITH GastosAgg AS (
        SELECT
            /* periodo en español tal como viene del JSON */
            LTRIM(RTRIM(LOWER(ec.periodo))) AS PeriodoES,
            SUM(g.importe) AS TotalGastos
        FROM General.Gasto g
        JOIN General.Expensa_Consorcio ec
          ON ec.id_expensa_consorcio = g.id_expensa_consorcio
        WHERE (@IdConsorcio IS NULL OR ec.id_consorcio = @IdConsorcio)
          /* Si existieran fechas de emisión y querés filtrar por rango temporal real: 
             AND ec.fecha_emision BETWEEN @FechaDesde AND @FechaHasta */
        GROUP BY LTRIM(RTRIM(LOWER(ec.periodo)))
    )
    SELECT TOP (5)
        /* Capitalizo el mes para mostrar lindo */
        CONCAT(UPPER(LEFT(PeriodoES,1)), SUBSTRING(PeriodoES,2,100)) AS Periodo,
        TotalGastos
    FROM GastosAgg
    ORDER BY TotalGastos DESC, Periodo ASC;  -- empate por nombre
END
GO

/* =========================
   Reporte 5 – Top 3 propietarios con mayor morosidad
   Params: @PeriodoDesdeYM, @PeriodoHastaYM, @IdConsorcio
   Definición “morosidad” (ajustable):
     deuda = sum(Expensa emitida) – sum(Pagos aplicados) en el rango
   ========================= */

CREATE OR ALTER PROCEDURE Reportes.sp_reporte_top_morosidad_propietarios
    @FechaCorte       date,                 -- pagos hasta esta fecha (inclusive)
    @IdConsorcio      int    = NULL,        -- NULL = todos
    @IncluirExtra     bit    = 0,           -- 1 = suma extraordinarias
    @MesesFiltroCSV   nvarchar(max) = NULL, -- ej: 'abril,mayo,junio' (según ec.periodo); NULL = todos los meses existentes
    @TopN             int    = 3            -- por defecto pide 3
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaCorte IS NULL
    BEGIN RAISERROR('Debe indicar @FechaCorte.',16,1); RETURN; END;

    /* ---------- 0) Meses a considerar (según texto en español de ec.periodo) ---------- */
    DECLARE @Meses TABLE (periodo nvarchar(50) PRIMARY KEY);
    IF @MesesFiltroCSV IS NULL
    BEGIN
        INSERT INTO @Meses(periodo)
        SELECT DISTINCT LTRIM(RTRIM(LOWER(periodo)))
        FROM [Com5600_Grupo14_DB].General.Expensa_Consorcio
        WHERE (@IdConsorcio IS NULL OR id_consorcio = @IdConsorcio);
    END
    ELSE
    BEGIN
        INSERT INTO @Meses(periodo)
        SELECT DISTINCT LTRIM(RTRIM(LOWER(value)))
        FROM STRING_SPLIT(@MesesFiltroCSV, ',');
    END

    /* ---------- 1) Deuda esperada por (persona, consorcio) vía % prorrateo ---------- */
    ;WITH PropietariosUF AS (
        SELECT
            p.id_persona,
            p.nombre, p.apellido, p.dni, p.email, p.telefono,
            uf.id_consorcio,
            ISNULL(NULLIF(uf.porcentaje_de_prorrateo,0),0) AS prorrateo
        FROM [Com5600_Grupo14_DB].Propiedades.UF_Persona ufp
        JOIN [Com5600_Grupo14_DB].Propiedades.Persona p   ON p.id_persona = ufp.id_persona
        JOIN [Com5600_Grupo14_DB].Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
        WHERE p.es_inquilino = 0
          AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
    ),
    DeudaPersona AS (
        SELECT
            pu.id_persona,
            pu.id_consorcio,
            SUM( (ISNULL(ec.total_ordinarios,0) +
                  CASE WHEN @IncluirExtra=1 THEN ISNULL(ec.total_extraordinarios,0) ELSE 0 END)
                 * (ISNULL(pu.prorrateo,0) / 100.0)
               ) AS DeudaEsperada
        FROM PropietariosUF pu
        JOIN [Com5600_Grupo14_DB].General.Expensa_Consorcio ec
          ON ec.id_consorcio = pu.id_consorcio
        JOIN @Meses m
          ON LTRIM(RTRIM(LOWER(ec.periodo))) = m.periodo
        GROUP BY pu.id_persona, pu.id_consorcio
    ),
    /* ---------- 2) Pagos por (persona, consorcio) hasta @FechaCorte ---------- */
    PagosPersona AS (
        SELECT
            per.id_persona,
            uf.id_consorcio,
            SUM(p.importe) AS Pagos
        FROM [Com5600_Grupo14_DB].Tesoreria.Pago p
        JOIN [Com5600_Grupo14_DB].Tesoreria.Persona_CuentaBancaria pcb ON pcb.id_persona_cuenta = p.id_persona_cuenta
        JOIN [Com5600_Grupo14_DB].Propiedades.Persona per ON per.id_persona = pcb.id_persona
        JOIN [Com5600_Grupo14_DB].Propiedades.UF_Persona ufp ON ufp.id_persona = per.id_persona
        JOIN [Com5600_Grupo14_DB].Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
        WHERE p.fecha_de_pago <= @FechaCorte
          AND per.es_inquilino = 0
          AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
        GROUP BY per.id_persona, uf.id_consorcio
    ),
    /* ---------- 3) Saldo (morosidad) ---------- */
    Morosidad AS (
        SELECT
            dp.id_persona,
            dp.id_consorcio,
            ISNULL(dp.DeudaEsperada,0) AS DeudaEsperada,
            ISNULL(pg.Pagos,0)         AS Pagos,
            CASE WHEN ISNULL(dp.DeudaEsperada,0) - ISNULL(pg.Pagos,0) > 0
                 THEN CAST(ISNULL(dp.DeudaEsperada,0) - ISNULL(pg.Pagos,0) AS decimal(18,2))
                 ELSE CAST(0 AS decimal(18,2))
            END AS Morosidad
        FROM DeudaPersona dp
        LEFT JOIN PagosPersona pg
          ON pg.id_persona = dp.id_persona
         AND pg.id_consorcio = dp.id_consorcio
    )
    SELECT TOP (@TopN)
        c.nombre              AS Consorcio,
        per.apellido,
        per.nombre,
        per.dni,
        per.email,
        per.telefono,
        m.DeudaEsperada,
        m.Pagos,
        m.Morosidad
    FROM Morosidad m
    JOIN [Com5600_Grupo14_DB].Propiedades.Persona per ON per.id_persona = m.id_persona
    JOIN [Com5600_Grupo14_DB].General.Consorcio c     ON c.id_consorcio = m.id_consorcio
    ORDER BY m.Morosidad DESC, per.apellido, per.nombre;
END
GO

/* =========================
   Reporte 6 – Fechas de pagos ordinarios por UF y días entre pagos
   Params: @PeriodoDesde, @PeriodoHasta, @IdConsorcio
   ========================= */

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
          /* Si en el futuro hay tipificación de pagos:
             AND (@SoloOrdinariasAsumidas = 0 OR p.tipo = 'Ordinario') */
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
    -- >>> CONSUMO LA CTE guardando en una temp table (esto evita el error del IF)
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




/* =================== PRUEBAS REPORTE 3 ===================*/
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

--prueba reporte4
-- Todos los consorcios
EXEC Reportes.sp_reporte_top5_gastos_ingresos 
  @FechaDesde='2025-01-01', @FechaHasta='2025-12-31',
  @IdConsorcio=NULL, @EstadoPago=NULL, @FormatoPeriodo='YYYY-MM';

-- Solo un consorcio (cambiá el ID) y solo pagos Asociados, mostrando meses en español
-- SELECT TOP(1) id_consorcio FROM General.Consorcio;
EXEC Reportes.sp_reporte_top5_gastos_ingresos 
  @FechaDesde='2025-01-01', @FechaHasta='2025-12-31',
  @IdConsorcio=1, @EstadoPago='Asociado', @FormatoPeriodo='MesES';

--prueba reporte5
EXEC Reportes.sp_reporte_top_morosidad_propietarios
  @FechaCorte='2025-06-30',
  @IdConsorcio=NULL,
  @IncluirExtra=0,
  @MesesFiltroCSV=NULL,   -- toma todos los meses que haya en Expensa_Consorcio
  @TopN=3;

-- Solo un consorcio (cambiar ID), con extraordinarias y meses específicos
-- SELECT TOP(1) id_consorcio FROM General.Consorcio ORDER BY id_consorcio;
EXEC Reportes.sp_reporte_top_morosidad_propietarios
  @FechaCorte='2025-06-30',
  @IdConsorcio=1,
  @IncluirExtra=1,
  @MesesFiltroCSV=N'abril,mayo,junio',
  @TopN=5;

--prueba reporte6
-- Tabla
EXEC Reportes.sp_reporte_pagos_intervalo_por_uf
  @FechaDesde='2025-01-01', @FechaHasta='2025-12-31',
  @IdConsorcio=NULL, @EstadoPago='Asociado',
  @FormatoPeriodo='YYYY-MM', @SoloOrdinariasAsumidas=1, @Salida='TABLA';

-- XML
EXEC Reportes.sp_reporte_pagos_intervalo_por_uf
  @FechaDesde='2025-03-01', @FechaHasta='2025-06-30',
  @IdConsorcio=NULL, @EstadoPago='Asociado',
  @FormatoPeriodo='MesES', @SoloOrdinariasAsumidas=1, @Salida='XML';

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