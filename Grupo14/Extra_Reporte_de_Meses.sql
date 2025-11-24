USE Com5600_Grupo14_DB;
GO

CREATE OR ALTER PROCEDURE Reportes.sp_liquidacion_expensas_uf
    @FechaDesde      DATE,                  
    @FechaHasta      DATE,                  
    @Vto1            DATE = NULL,           
    @Vto2            DATE = NULL,           
    @NombreConsorcio VARCHAR(100) = NULL    
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------------
    -- 0) Validaciones de rango
    ----------------------------------------------------------------------
    IF @FechaHasta < @FechaDesde
    BEGIN
        RAISERROR('La fecha final no puede ser menor que la inicial.',16,1);
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 1) Forzar idioma a Español para que DATENAME devuelva "abril, mayo..."
    ----------------------------------------------------------------------
    DECLARE @OldLang sysname = @@LANGUAGE;
    SET LANGUAGE Spanish;

    ----------------------------------------------------------------------
    -- 2) Construir lista de meses dentro del rango (abril, mayo, junio...)
    ----------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#MesesPeriodo') IS NOT NULL DROP TABLE #MesesPeriodo;

    ;WITH Meses AS (
        SELECT CAST(DATEFROMPARTS(YEAR(@FechaDesde), MONTH(@FechaDesde), 1) AS DATE) AS mes_inicio
        UNION ALL
        SELECT DATEADD(MONTH, 1, mes_inicio)
        FROM Meses
        WHERE mes_inicio < DATEFROMPARTS(YEAR(@FechaHasta), MONTH(@FechaHasta), 1)
    )
    SELECT DISTINCT 
        LOWER(DATENAME(MONTH, mes_inicio)) AS nombre_mes
    INTO #MesesPeriodo
    FROM Meses
    OPTION (MAXRECURSION 24);

    ----------------------------------------------------------------------
    -- 3) Traer expensas de TODOS los meses detectados
    ----------------------------------------------------------------------
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
    JOIN General.Consorcio c 
        ON c.id_consorcio = ec.id_consorcio
    JOIN #MesesPeriodo m
        ON LOWER(LTRIM(RTRIM(ec.periodo))) = m.nombre_mes
    WHERE (@NombreConsorcio IS NULL OR c.nombre = @NombreConsorcio);

    IF NOT EXISTS (SELECT 1 FROM #Expensas)
    BEGIN
        SET LANGUAGE @OldLang;
        RAISERROR('No se encontraron expensas dentro del rango indicado.',16,1);
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 4) Persona principal por UF
    ----------------------------------------------------------------------
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
        JOIN Propiedades.Persona p 
            ON ufp.id_persona = p.id_persona
    ),
    UFPrincipal AS (
        SELECT * FROM UFPersonas WHERE rn = 1
    ),
    ----------------------------------------------------------------------
    -- 5) Pagos por UF dentro del rango
    ----------------------------------------------------------------------
    PagosPorUF AS (
        SELECT
            ufp.id_uf,
            SUM(pag.importe) AS pagos_recibidos,
            MAX(pag.fecha_de_pago) AS ultima_fecha_pago
        FROM Propiedades.UF_Persona ufp
        JOIN UFPrincipal up ON up.id_uf = ufp.id_uf
        JOIN Tesoreria.Persona_CuentaBancaria pcb ON pcb.id_persona = up.id_persona
        JOIN Tesoreria.Pago pag ON pag.id_persona_cuenta = pcb.id_persona_cuenta
        WHERE pag.fecha_de_pago BETWEEN @FechaDesde AND @FechaHasta
        GROUP BY ufp.id_uf
    )

    ----------------------------------------------------------------------
    -- 6) Liquidación final
    ----------------------------------------------------------------------
    SELECT
        e.nombre_consorcio                       AS Consorcio,
        e.periodo                                AS Periodo,
        uf.numero                                AS UF,
        uf.porcentaje_de_prorrateo               AS Porcentaje,
        CONCAT(uf.piso, '-', uf.departamento)    AS Piso_Depto,
        CONCAT(ISNULL(UP.apellido,''), ' ', ISNULL(UP.nombre,'')) AS Propietario,

        CAST(0 AS DECIMAL(18,2))                 AS SaldoAnterior,

        ISNULL(PU.pagos_recibidos, 0)            AS PagosRecibidos,

        CAST(e.total_ordinarios * (uf.porcentaje_de_prorrateo/100.0)
            AS DECIMAL(18,2))                    AS ExpensasOrdinarias,

        CAST(e.total_ordinarios * (uf.porcentaje_de_prorrateo/100.0)
             - ISNULL(PU.pagos_recibidos, 0)
            AS DECIMAL(18,2))                    AS Deuda,

        CASE 
            WHEN @Vto1 IS NULL OR @Vto2 IS NULL THEN 0
            ELSE
                CASE 
                    WHEN (e.total_ordinarios * (uf.porcentaje_de_prorrateo/100.0)
                          - ISNULL(PU.pagos_recibidos, 0)) <= 0
                        THEN 0
                    WHEN PU.ultima_fecha_pago IS NULL OR PU.ultima_fecha_pago > @Vto2
                        THEN CAST((e.total_ordinarios*(uf.porcentaje_de_prorrateo/100.0)
                                   - ISNULL(PU.pagos_recibidos,0))*0.05 AS DECIMAL(18,2))
                    WHEN PU.ultima_fecha_pago > @Vto1
                        THEN CAST((e.total_ordinarios*(uf.porcentaje_de_prorrateo/100.0)
                                   - ISNULL(PU.pagos_recibidos,0))*0.02 AS DECIMAL(18,2))
                    ELSE 0
                END
        END AS InteresPorMora,

        CAST(ISNULL(e.total_extraordinarios,0)*(uf.porcentaje_de_prorrateo/100.0)
             AS DECIMAL(18,2))                   AS ExpensasExtraordinarias,

        CAST(
            (e.total_ordinarios*(uf.porcentaje_de_prorrateo/100.0)
             - ISNULL(PU.pagos_recibidos,0))
            +
            (
                CASE 
                    WHEN @Vto1 IS NULL OR @Vto2 IS NULL THEN 0
                    ELSE
                        CASE 
                            WHEN (e.total_ordinarios*(uf.porcentaje_de_prorrateo/100.0)
                                  - ISNULL(PU.pagos_recibidos,0)) <= 0
                                THEN 0
                            WHEN PU.ultima_fecha_pago IS NULL OR PU.ultima_fecha_pago > @Vto2
                                THEN (e.total_ordinarios*(uf.porcentaje_de_prorrateo/100.0)
                                      - ISNULL(PU.pagos_recibidos,0))*0.05
                            WHEN PU.ultima_fecha_pago > @Vto1
                                THEN (e.total_ordinarios*(uf.porcentaje_de_prorrateo/100.0)
                                      - ISNULL(PU.pagos_recibidos,0))*0.02
                            ELSE 0
                        END
                END
            )
            +
            (ISNULL(e.total_extraordinarios,0)*(uf.porcentaje_de_prorrateo/100.0))
            AS DECIMAL(18,2)
        ) AS TotalAPagar

    FROM #Expensas e
    JOIN Propiedades.UnidadFuncional uf ON uf.id_consorcio = e.id_consorcio
    LEFT JOIN UFPrincipal UP           ON UP.id_uf = uf.id_uf
    LEFT JOIN PagosPorUF PU            ON PU.id_uf = uf.id_uf
    ORDER BY e.nombre_consorcio, e.periodo, uf.numero;

    ----------------------------------------------------------------------
    -- Restaurar idioma
    ----------------------------------------------------------------------
    SET LANGUAGE @OldLang;
    SET NOCOUNT OFF;
END;
GO



EXEC Reportes.sp_liquidacion_expensas_uf
    @FechaDesde      = '2025-04-01',
    @FechaHasta      = '2025-06-30',
    @Vto1            = '2025-04-10',
    @Vto2            = '2025-04-20',
    @NombreConsorcio = NULL;   -- TODOS


SELECT DISTINCT periodo
FROM General.Expensa_Consorcio
ORDER BY periodo;

EXEC Reportes.sp_liquidacion_expensas_uf
    @FechaDesde = '2025-04-01',
    @FechaHasta = '2025-06-30',
    @Vto1 = '2025-04-10',
    @Vto2 = '2025-04-20',
    @NombreConsorcio = 'Azcuenaga';

