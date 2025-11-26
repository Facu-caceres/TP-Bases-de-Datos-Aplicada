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
Descripción: Creacion de un SP para informar la recaudación total por mes y departamento.
*/

USE [Com5600G14];
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

    EXEC sp_executesql @sql;
END
GO