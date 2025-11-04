/* =========================================================
   Entrega 6 – Reportes & API
   Crea SPs para los 6 reportes solicitados.
   Esquema sugerido: REP
   ========================================================= */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'REP')
    EXEC('CREATE SCHEMA REP');
GO

/* =========================
   Reporte 1 – Flujo de caja semanal
   Params:
     @FechaDesde, @FechaHasta, @IdConsorcio (NULL=todos)
   Output: recaudación semanal por tipo (ord/extra), promedio del período, acumulado.
   ========================= */
IF OBJECT_ID('REP.SP_FlujoCajaSemanal') IS NOT NULL DROP PROC REP.SP_FlujoCajaSemanal;
GO
CREATE PROC REP.SP_FlujoCajaSemanal
    @FechaDesde date,
    @FechaHasta date,
    @IdConsorcio int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH PagosFiltrados AS (
        SELECT p.IdPago, p.IdUF, p.FechaPago, p.Importe, UPPER(p.TipoPago) AS TipoPago
        FROM dbo.Pago p
        INNER JOIN dbo.UnidadFuncional uf ON uf.IdUF = p.IdUF
        WHERE p.FechaPago >= @FechaDesde AND p.FechaPago < DATEADD(day,1,@FechaHasta)
          AND (@IdConsorcio IS NULL OR uf.IdConsorcio = @IdConsorcio)
    ),
    Semanas AS (
        SELECT 
            DATEADD(week, DATEDIFF(week, 0, FechaPago), 0) AS SemanaInicio,
            TipoPago,
            SUM(Importe) AS Monto
        FROM PagosFiltrados
        GROUP BY DATEADD(week, DATEDIFF(week, 0, FechaPago), 0), TipoPago
    ),
    SumaSemanal AS (
        SELECT 
            s.SemanaInicio,
            SUM(CASE WHEN s.TipoPago IN ('ORDINARIO') THEN s.Monto ELSE 0 END) AS Recaud_Ordinaria,
            SUM(CASE WHEN s.TipoPago NOT IN ('ORDINARIO') THEN s.Monto ELSE 0 END) AS Recaud_Extra,
            SUM(s.Monto) AS Recaud_Total
        FROM Semanas s
        GROUP BY s.SemanaInicio
    ),
    ConAcumulado AS (
        SELECT 
            SemanaInicio,
            Recaud_Ordinaria,
            Recaud_Extra,
            Recaud_Total,
            SUM(Recaud_Total) OVER (ORDER BY SemanaInicio ROWS UNBOUNDED PRECEDING) AS Acumulado
        FROM SumaSemanal
    )
    SELECT 
        SemanaInicio,
        DATEADD(day,6,SemanaInicio) AS SemanaFin,
        Recaud_Ordinaria,
        Recaud_Extra,
        Recaud_Total,
        AVG(Recaud_Total) OVER () AS PromedioPeriodo,
        Acumulado
    FROM ConAcumulado
    ORDER BY SemanaInicio;
END
GO

/* =========================
   Reporte 2 – Recaudación por mes y departamento (tabla cruzada)
   Params: @PeriodoDesdeYM, @PeriodoHastaYM, @IdConsorcio
   Asumo PeriodoYm = 'YYYYMM' en Expensa o derive de FechaPago.
   ========================= */
IF OBJECT_ID('REP.SP_RecaudacionPorMesDepto') IS NOT NULL DROP PROC REP.SP_RecaudacionPorMesDepto;
GO
CREATE PROC REP.SP_RecaudacionPorMesDepto
    @PeriodoDesdeYM char(6),
    @PeriodoHastaYM char(6),
    @IdConsorcio int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Pagos AS (
        SELECT uf.IdConsorcio, uf.IdUF, uf.Piso, uf.Depto,
               CONVERT(char(6),p.FechaPago,112) AS PeriodoYM,
               p.Importe
        FROM dbo.Pago p
        INNER JOIN dbo.UnidadFuncional uf ON uf.IdUF = p.IdUF
        WHERE CONVERT(char(6),p.FechaPago,112) BETWEEN @PeriodoDesdeYM AND @PeriodoHastaYM
          AND (@IdConsorcio IS NULL OR uf.IdConsorcio = @IdConsorcio)
    )
    SELECT 
        CONCAT(u.Piso, '-', u.Depto) AS Departamento,
        SUM(CASE WHEN PeriodoYM = @PeriodoDesdeYM THEN Importe END) AS Monto_Ini,
        -- Tip: podés agregar más columnas dinámicas si necesitás muchos meses:
        -- Para tabla cruzada verdaderamente dinámica, usar PIVOT dinámico:
        SUM(Importe) AS TotalPeriodo
    FROM Pagos u
    GROUP BY CONCAT(u.Piso, '-', u.Depto)
    ORDER BY Departamento;
END
GO

/* =========================
   Reporte 3 – Cruzado por procedencia (ord/extra/etc.) según período
   Params: @PeriodoDesdeYM, @PeriodoHastaYM, @IdConsorcio
   (Devuelve pivot por TipoPago)
   ========================= */
IF OBJECT_ID('REP.SP_RecaudacionPorProcedencia') IS NOT NULL DROP PROC REP.SP_RecaudacionPorProcedencia;
GO
CREATE PROC REP.SP_RecaudacionPorProcedencia
    @PeriodoDesdeYM char(6),
    @PeriodoHastaYM char(6),
    @IdConsorcio int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Base AS (
        SELECT 
            CONVERT(char(6),p.FechaPago,112) AS PeriodoYM,
            UPPER(p.TipoPago) AS Tipo,
            p.Importe,
            uf.IdConsorcio
        FROM dbo.Pago p
        INNER JOIN dbo.UnidadFuncional uf ON uf.IdUF = p.IdUF
        WHERE CONVERT(char(6),p.FechaPago,112) BETWEEN @PeriodoDesdeYM AND @PeriodoHastaYM
          AND (@IdConsorcio IS NULL OR uf.IdConsorcio = @IdConsorcio)
    )
    SELECT PeriodoYM,
           SUM(CASE WHEN Tipo='ORDINARIO' THEN Importe ELSE 0 END) AS Ordinario,
           SUM(CASE WHEN Tipo='EXTRAORDINARIO' THEN Importe ELSE 0 END) AS Extraordinario,
           SUM(CASE WHEN Tipo NOT IN ('ORDINARIO','EXTRAORDINARIO') THEN Importe ELSE 0 END) AS Otros,
           SUM(Importe) AS Total
    FROM Base
    GROUP BY PeriodoYM
    ORDER BY PeriodoYM;
END
GO

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
