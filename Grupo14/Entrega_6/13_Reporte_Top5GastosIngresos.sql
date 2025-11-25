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
Descripción: Creacion de un SP para informar el Top 5 meses con mayores Gastos e Ingresos.
*/

USE [Com5600G14];
GO

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
    ;WITH GastosAgg AS (
        SELECT
            LTRIM(RTRIM(LOWER(ec.periodo))) AS PeriodoES,
            SUM(g.importe) AS TotalGastos
        FROM General.Gasto g
        JOIN General.Expensa_Consorcio ec
          ON ec.id_expensa_consorcio = g.id_expensa_consorcio
        WHERE (@IdConsorcio IS NULL OR ec.id_consorcio = @IdConsorcio)
        GROUP BY LTRIM(RTRIM(LOWER(ec.periodo)))
    )
    SELECT TOP (5)
        CONCAT(UPPER(LEFT(PeriodoES,1)), SUBSTRING(PeriodoES,2,100)) AS Periodo,
        TotalGastos
    FROM GastosAgg
    ORDER BY TotalGastos DESC, Periodo ASC;
END
GO