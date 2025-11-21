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
Descripción: Creacion de un SP para informar el Top Morosidad con hash por rol
*/

USE [Com5600_Grupo14_DB];
GO

CREATE OR ALTER PROCEDURE Reportes.sp_reporte_top_morosidad_propietarios
    @FechaCorte       date,
    @IdConsorcio      int           = NULL,
    @IncluirExtra     bit           = 0,
    @MesesFiltroCSV   nvarchar(max) = NULL,
    @TopN             int           = 3            
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaCorte IS NULL
    BEGIN 
        RAISERROR('Debe indicar @FechaCorte.',16,1); 
        RETURN; 
    END;

    -- 1) Armar tabla de meses a filtrar
    DECLARE @Meses table (periodo nvarchar(50) PRIMARY KEY);

    IF @MesesFiltroCSV IS NULL
    BEGIN
        INSERT INTO @Meses(periodo)
        SELECT DISTINCT LTRIM(RTRIM(LOWER(periodo)))
        FROM General.Expensa_Consorcio
        WHERE (@IdConsorcio IS NULL OR id_consorcio = @IdConsorcio);
    END
    ELSE
    BEGIN
        INSERT INTO @Meses(periodo)
        SELECT DISTINCT LTRIM(RTRIM(LOWER(value)))
        FROM STRING_SPLIT(@MesesFiltroCSV, ',');
    END;

    -- 2) CTEs de cálculo de deuda y pagos
    ;WITH PropietariosUF AS (
        SELECT
            p.id_persona,
            p.nombre,
            p.apellido,
            p.dni,
            p.email,
            p.telefono,
            uf.id_consorcio,
            ISNULL(NULLIF(uf.porcentaje_de_prorrateo,0),0) AS prorrateo
        FROM Propiedades.UF_Persona ufp
        JOIN Propiedades.Persona p          ON p.id_persona = ufp.id_persona
        JOIN Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
        WHERE p.es_inquilino = 0
          AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
    ),
    DeudaPersona AS (
        SELECT
            pu.id_persona,
            pu.id_consorcio,
            SUM(
                (ISNULL(ec.total_ordinarios,0) + 
                 CASE WHEN @IncluirExtra = 1 THEN ISNULL(ec.total_extraordinarios,0) ELSE 0 END)
                * (ISNULL(pu.prorrateo,0) / 100.0)
            ) AS DeudaEsperada
        FROM PropietariosUF pu
        JOIN General.Expensa_Consorcio ec ON ec.id_consorcio = pu.id_consorcio
        JOIN @Meses m ON LTRIM(RTRIM(LOWER(ec.periodo))) = m.periodo
        GROUP BY pu.id_persona, pu.id_consorcio
    ),
    PagosPersona AS (
        SELECT
            per.id_persona,
            uf.id_consorcio,
            SUM(p.importe) AS Pagos
        FROM Tesoreria.Pago p
        JOIN Tesoreria.Persona_CuentaBancaria pcb ON pcb.id_persona_cuenta = p.id_persona_cuenta
        JOIN Propiedades.Persona per             ON per.id_persona = pcb.id_persona
        JOIN Propiedades.UF_Persona ufp          ON ufp.id_persona = per.id_persona
        JOIN Propiedades.UnidadFuncional uf      ON uf.id_uf = ufp.id_uf
        WHERE p.fecha_de_pago <= @FechaCorte
          AND per.es_inquilino = 0
          AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
        GROUP BY per.id_persona, uf.id_consorcio
    ),
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
        LEFT JOIN PagosPersona pg ON pg.id_persona = dp.id_persona AND pg.id_consorcio = dp.id_consorcio
    )
    -- 3) SELECT FINAL (Datos planos)
    SELECT TOP (@TopN)
        c.nombre AS Consorcio,
        per.apellido,
        per.nombre,
        CAST(per.dni AS varchar(20)) AS dni,
        per.email,
        CAST(per.telefono AS varchar(20)) AS telefono,
        m.DeudaEsperada,
        m.Pagos,
        m.Morosidad
    FROM Morosidad m
    JOIN Propiedades.Persona per ON per.id_persona = m.id_persona
    JOIN General.Consorcio c     ON c.id_consorcio = m.id_consorcio
    ORDER BY m.Morosidad DESC, per.apellido, per.nombre;
END
GO