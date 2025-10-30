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
Descripción: SP para importar Personas (Propiedades.Persona) y sus Cuentas Bancarias (Tesoreria.Persona_CuentaBancaria) desde CSV.
*/
USE [Com5600_Grupo14_DB];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_importar_personas
    @ruta_archivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tabla temporal
    IF OBJECT_ID('tempdb..#TempPersonas') IS NOT NULL DROP TABLE #TempPersonas;
    CREATE TABLE #TempPersonas (
        Nombre VARCHAR(100),
        Apellido VARCHAR(100),
        DNI VARCHAR(20),
        Email VARCHAR(255),
        Telefono VARCHAR(50),
        CVU_CBU VARCHAR(22),
        EsInquilino VARCHAR(5)
    );

    -- 2. Carga masiva
    BEGIN TRY
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = N'
            BULK INSERT #TempPersonas
            FROM ''' + @ruta_archivo + N'''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''\n'',
                FIRSTROW = 2,
                CODEPAGE = ''ACP''
            );';
        EXEC sp_executesql @sql;
        DELETE FROM #TempPersonas WHERE DNI IS NULL OR LTRIM(RTRIM(DNI)) = '';
    END TRY
    BEGIN CATCH
        PRINT 'Error al intentar cargar el archivo CSV de Personas: ' + @ruta_archivo;
        PRINT ERROR_MESSAGE();
        RETURN;
    END CATCH

    -- 3. Limpiar y eliminar duplicados usando ROW_NUMBER()
    IF OBJECT_ID('tempdb..#TempPersonasClean') IS NOT NULL DROP TABLE #TempPersonasClean;

    WITH PersonasRankeadas AS (
        SELECT
            TRY_CAST(LTRIM(RTRIM(DNI)) AS INT) as DNI_INT,
            LEFT(LTRIM(RTRIM(Nombre)), 50) as NombreLimpio,
            LEFT(LTRIM(RTRIM(Apellido)), 50) as ApellidoLimpio,
            LTRIM(RTRIM(Email)) as EmailLimpio,
            TRY_CAST(LEFT(LTRIM(RTRIM(Telefono)), 15) AS BIGINT) as TelefonoINT,
            CASE WHEN LTRIM(RTRIM(EsInquilino)) = '1' THEN 1 ELSE 0 END as InquilinoBIT,
            LTRIM(RTRIM(CVU_CBU)) AS CBU_Limpio,
            ROW_NUMBER() OVER(PARTITION BY LTRIM(RTRIM(DNI)) ORDER BY (SELECT NULL)) as rn
        FROM #TempPersonas
        WHERE TRY_CAST(LTRIM(RTRIM(DNI)) AS INT) IS NOT NULL -- Solo procesar DNIs válidos
    )
    SELECT *
    INTO #TempPersonasClean
    FROM PersonasRankeadas
    WHERE rn = 1;

    -- 4. Actualizar Personas existentes
    UPDATE PP
    SET
        PP.nombre = TPC.NombreLimpio,
        PP.apellido = TPC.ApellidoLimpio,
        PP.email = TPC.EmailLimpio,
        PP.telefono = TPC.TelefonoINT,
        PP.es_inquilino = TPC.InquilinoBIT
    FROM Propiedades.Persona PP
    INNER JOIN #TempPersonasClean TPC ON PP.dni = TPC.DNI_INT;

    -- 5. Insertar nuevas Personas
    INSERT INTO Propiedades.Persona (nombre, apellido, dni, email, telefono, es_inquilino)
    SELECT
        TPC.NombreLimpio,
        TPC.ApellidoLimpio,
        TPC.DNI_INT,
        TPC.EmailLimpio,
        TPC.TelefonoINT,
        TPC.InquilinoBIT
    FROM #TempPersonasClean TPC
    WHERE NOT EXISTS (
        SELECT 1
        FROM Propiedades.Persona PP
        WHERE PP.dni = TPC.DNI_INT
    );

    -- 6. Actualizar Persona_CuentaBancaria existentes
    UPDATE TPCB
    SET
        TPCB.id_persona = P.id_persona, -- Re-asociar por si cambió el DNI asociado al CBU (poco probable pero posible)
        TPCB.activa = 1
    FROM Tesoreria.Persona_CuentaBancaria TPCB
    INNER JOIN #TempPersonasClean TPC ON TPCB.cbu_cvu = TPC.CBU_Limpio
    INNER JOIN Propiedades.Persona P ON TPC.DNI_INT = P.dni -- Asegurarse que la persona existe
    WHERE TPC.CBU_Limpio IS NOT NULL AND LEN(TPC.CBU_Limpio) = 22;

    -- 7. Insertar nuevas Persona_CuentaBancaria
    INSERT INTO Tesoreria.Persona_CuentaBancaria (id_persona, cbu_cvu, activa)
    SELECT
        P.id_persona,
        TPC.CBU_Limpio,
        1 -- Activa
    FROM #TempPersonasClean TPC
    INNER JOIN Propiedades.Persona P ON TPC.DNI_INT = P.dni -- Asegurarse que la persona existe
    WHERE TPC.CBU_Limpio IS NOT NULL AND LEN(TPC.CBU_Limpio) = 22
      AND NOT EXISTS (
          SELECT 1
          FROM Tesoreria.Persona_CuentaBancaria TPCB
          WHERE TPCB.cbu_cvu = TPC.CBU_Limpio
      );

    PRINT 'Proceso de importación de Personas (Propiedades.Persona) y Cuentas (Tesoreria.Persona_CuentaBancaria) finalizado.';

    DROP TABLE #TempPersonas;
    DROP TABLE #TempPersonasClean;
    SET NOCOUNT OFF;
END;
GO
