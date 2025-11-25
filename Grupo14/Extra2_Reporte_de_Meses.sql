USE [Com5600G14];
GO

CREATE OR ALTER PROCEDURE Reportes.sp_liquidacion_expensas_uf
    @Periodo         VARCHAR(50),          -- 'abril', 'mayo', etc. Debe coincidir con Expensa_Consorcio.periodo
    @FechaDesde      DATE,                 -- inicio del período de pagos a considerar
    @FechaHasta      DATE,                 -- fin del período de pagos a considerar
    @Vto1            DATE = NULL,          -- 1er vencimiento (para interés 2%)
    @Vto2            DATE = NULL,          -- 2do vencimiento (para interés 5%)
    @NombreConsorcio VARCHAR(100) = NULL   -- NULL = todos los consorcios
AS
BEGIN
    SET NOCOUNT ON;

    /* 1) Traer las expensas del período (uno o todos los consorcios) */
    IF OBJECT_ID('tempdb..#Expensas') IS NOT NULL DROP TABLE #Expensas;

    SELECT
        ec.id_expensa_consorcio,
        ec.id_consorcio,
        ec.total_ordinarios,
        ec.total_extraordinarios,
        ec.interes_por_mora,
        ec.periodo,
        c.nombre AS nombre_consorcio
    INTO #Expensas
    FROM General.Expensa_Consorcio ec
    JOIN General.Consorcio c ON c.id_consorcio = ec.id_consorcio
    WHERE ec.periodo = @Periodo
      AND (@NombreConsorcio IS NULL OR c.nombre = @NombreConsorcio);

    IF NOT EXISTS (SELECT 1 FROM #Expensas)
    BEGIN
        RAISERROR('No se encontraron expensas para ese período y filtro de consorcio.',16,1);
        RETURN;
    END;

    /* 2) Persona "principal" por UF (prioriza propietario: es_inquilino = 0) */
    ;WITH UFPersonas AS (
        SELECT
            ufp.id_uf,
            p.id_persona,
            p.nombre,
            p.apellido,
            p.es_inquilino,
            ROW_NUMBER() OVER (
                PARTITION BY ufp.id_uf
                ORDER BY p.es_inquilino, p.id_persona
            ) AS rn
        FROM Propiedades.UF_Persona ufp
        JOIN Propiedades.Persona p ON ufp.id_persona = p.id_persona
    ),
    UFPrincipal AS (
        SELECT *
        FROM UFPersonas
        WHERE rn = 1
    ),
    /* 3) Pagos por UF en el período indicado */
    PagosPorUF AS (
        SELECT
            ufp.id_uf,
            SUM(pag.importe) AS pagos_recibidos,
            MAX(pag.fecha_de_pago) AS ultima_fecha_pago
        FROM Propiedades.UF_Persona ufp
        JOIN UFPrincipal up  ON up.id_uf = ufp.id_uf
        JOIN Tesoreria.Persona_CuentaBancaria pcb ON pcb.id_persona = up.id_persona
        JOIN Tesoreria.Pago pag ON pag.id_persona_cuenta = pcb.id_persona_cuenta
        WHERE pag.fecha_de_pago BETWEEN @FechaDesde AND @FechaHasta
        GROUP BY ufp.id_uf
    )

    /* 4) Liquidación final por UF */
    SELECT
        e.nombre_consorcio                       AS Consorcio,
        e.periodo                                AS Periodo,
        uf.numero                                AS UF,
        uf.porcentaje_de_prorrateo               AS Porcentaje,
        CONCAT(uf.piso, '-', uf.departamento)    AS Piso_Depto,
        CONCAT(ISNULL(UP.apellido,''), ' ', ISNULL(UP.nombre,'')) AS Propietario,

        -- Saldo anterior: por ahora 0 (se puede mejorar encadenando meses)
        CAST(0 AS DECIMAL(18,2))                 AS SaldoAnterior,

        ISNULL(PU.pagos_recibidos, 0)            AS PagosRecibidos,

        -- Expensas ordinarias prorrateadas por %
        CAST(e.total_ordinarios * (uf.porcentaje_de_prorrateo / 100.0)
             AS DECIMAL(18,2))                   AS ExpensasOrdinarias,

        -- Deuda = expensas ordinarias - pagos (sin saldo anterior)
        CAST(e.total_ordinarios * (uf.porcentaje_de_prorrateo / 100.0)
             - ISNULL(PU.pagos_recibidos, 0)
             AS DECIMAL(18,2))                   AS Deuda,

        -- Interés por mora según último pago y vencimientos (2% entre Vto1 y Vto2, 5% luego)
        CASE 
            WHEN @Vto1 IS NULL OR @Vto2 IS NULL THEN 0
            ELSE
                CASE 
                    WHEN (e.total_ordinarios * (uf.porcentaje_de_prorrateo / 100.0)
                          - ISNULL(PU.pagos_recibidos, 0)) <= 0
                        THEN 0
                    WHEN PU.ultima_fecha_pago IS NULL 
                         OR PU.ultima_fecha_pago > @Vto2
                        THEN CAST((e.total_ordinarios * (uf.porcentaje_de_prorrateo / 100.0)
                                   - ISNULL(PU.pagos_recibidos, 0)) * 0.05 AS DECIMAL(18,2))
                    WHEN PU.ultima_fecha_pago > @Vto1
                        THEN CAST((e.total_ordinarios * (uf.porcentaje_de_prorrateo / 100.0)
                                   - ISNULL(PU.pagos_recibidos, 0)) * 0.02 AS DECIMAL(18,2))
                    ELSE 0
                END
        END                                       AS InteresPorMora,

        -- Por ahora cochera / expensas extraordinarias en 0 (se puede refinar)
        CAST(0 AS DECIMAL(18,2))                  AS Cochera,
        CAST(0 AS DECIMAL(18,2))                  AS ExpensasExtraordinarias,

        -- Total a pagar = Deuda + Interés (sin extras)
        CAST(
            (e.total_ordinarios * (uf.porcentaje_de_prorrateo / 100.0)
             - ISNULL(PU.pagos_recibidos, 0))
            +
            (
                CASE 
                    WHEN @Vto1 IS NULL OR @Vto2 IS NULL THEN 0
                    ELSE
                        CASE 
                            WHEN (e.total_ordinarios * (uf.porcentaje_de_prorrateo / 100.0)
                                  - ISNULL(PU.pagos_recibidos, 0)) <= 0
                                THEN 0
                            WHEN PU.ultima_fecha_pago IS NULL 
                                 OR PU.ultima_fecha_pago > @Vto2
                                THEN (e.total_ordinarios * (uf.porcentaje_de_prorrateo / 100.0)
                                      - ISNULL(PU.pagos_recibidos, 0)) * 0.05
                            WHEN PU.ultima_fecha_pago > @Vto1
                                THEN (e.total_ordinarios * (uf.porcentaje_de_prorrateo / 100.0)
                                      - ISNULL(PU.pagos_recibidos, 0)) * 0.02
                            ELSE 0
                        END
                END
            )
            AS DECIMAL(18,2)
        ) AS TotalAPagar
    FROM #Expensas e
    JOIN Propiedades.UnidadFuncional uf ON uf.id_consorcio = e.id_consorcio
    LEFT JOIN UFPrincipal UP ON UP.id_uf = uf.id_uf
    LEFT JOIN PagosPorUF PU ON PU.id_uf = uf.id_uf
    ORDER BY e.nombre_consorcio, uf.numero;

    SET NOCOUNT OFF;
END;
GO


/*

EXEC Reportes.sp_liquidacion_expensas_uf
    @Periodo         = 'abril',
    @FechaDesde      = '2025-04-01',
    @FechaHasta      = '2025-06-30',
    @Vto1            = '2025-04-10',
    @Vto2            = '2025-04-20',
    @NombreConsorcio = 'Azcuenaga';      -- o directamente no pasar el parámetro

EXEC Reportes.sp_liquidacion_expensas_uf
    @Periodo         = 'abril',
    @FechaDesde      = '2025-04-01',
    @FechaHasta      = '2025-06-30',
    @Vto1            = '2025-04-10',
    @Vto2            = '2025-04-20',
    @NombreConsorcio = NULL;      -- o directamente no pasar el parámetro

*/