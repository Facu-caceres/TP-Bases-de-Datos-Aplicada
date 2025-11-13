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
Fecha de Entrega: 07/11/2025
Descripción: SP para importar Personas (Propiedades.Persona) y sus Cuentas Bancarias (Tesoreria.Persona_CuentaBancaria) desde CSV.
*/
USE [Com5600_Grupo14_DB];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_importar_personas
    @ruta_archivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tablas temporales
    IF OBJECT_ID('tempdb..#TempPersonas') IS NOT NULL DROP TABLE #TempPersonas;
    IF OBJECT_ID('tempdb..#ErroresImportacion') IS NOT NULL DROP TABLE #ErroresImportacion;
    IF OBJECT_ID('tempdb..#TempPersonasProcesadas') IS NOT NULL DROP TABLE #TempPersonasProcesadas;
    IF OBJECT_ID('tempdb..#TempPersonasClean') IS NOT NULL DROP TABLE #TempPersonasClean;

    CREATE TABLE #TempPersonas (
        Nombre VARCHAR(100), Apellido VARCHAR(100), DNI VARCHAR(20),
        Email VARCHAR(255), Telefono VARCHAR(50), CVU_CBU VARCHAR(22), EsInquilino VARCHAR(5)
    );

    CREATE TABLE #ErroresImportacion (
        Nombre VARCHAR(100), Apellido VARCHAR(100), DNI VARCHAR(20),
        Email VARCHAR(255), Telefono VARCHAR(50), CVU_CBU VARCHAR(22), EsInquilino VARCHAR(5),
        ErrorDescripcion VARCHAR(255)
    );

    -- 2. Carga masiva desde el CSV
    BEGIN TRY
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = N'
            BULK INSERT #TempPersonas
            FROM ''' + @ruta_archivo + N'''
            WITH (
                FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', FIRSTROW = 2, CODEPAGE = ''ACP''
            );';
        EXEC sp_executesql @sql;
        DELETE FROM #TempPersonas WHERE DNI IS NULL OR LTRIM(RTRIM(DNI)) = '';
    END TRY
    BEGIN CATCH
        PRINT 'Error CATASTRÓFICO al intentar cargar el archivo CSV: ' + @ruta_archivo;
        PRINT ERROR_MESSAGE();
        RETURN;
    END CATCH

    -- 3. Procesamiento inicial: 
    -- Calculamos el DNI como entero y el ranking de duplicados.
    SELECT
        Nombre, Apellido, DNI, Email, Telefono, CVU_CBU, EsInquilino,
        TRY_CAST(LTRIM(RTRIM(DNI)) AS INT) as DNI_INT,
        ROW_NUMBER() OVER(PARTITION BY LTRIM(RTRIM(DNI)) ORDER BY (SELECT NULL)) as rn
    INTO #TempPersonasProcesadas 
    FROM #TempPersonas;

    -- 4. Insertar DNI duplicados en la tabla de errores
    INSERT INTO #ErroresImportacion (Nombre, Apellido, DNI, Email, Telefono, CVU_CBU, EsInquilino, ErrorDescripcion)
    SELECT Nombre, Apellido, DNI, Email, Telefono, CVU_CBU, EsInquilino, 'DNI duplicado en el archivo CSV (se procesó la primera aparición).'
    FROM #TempPersonasProcesadas 
    WHERE rn > 1 AND DNI_INT IS NOT NULL;

    -- Crear la tabla de datos limpios (#TempPersonasClean) solo con registros válidos y únicos (rn=1)
    SELECT
        DNI_INT,
        LEFT(LTRIM(RTRIM(Nombre)), 50) as NombreLimpio,
        LEFT(LTRIM(RTRIM(Apellido)), 50) as ApellidoLimpio,
        LTRIM(RTRIM(Email)) as EmailLimpio,
        TRY_CAST(LEFT(LTRIM(RTRIM(Telefono)), 15) AS BIGINT) as TelefonoINT,
        CASE WHEN LTRIM(RTRIM(EsInquilino)) = '1' THEN 1 ELSE 0 END as InquilinoBIT,
        LTRIM(RTRIM(CVU_CBU)) AS CBU_Limpio
    INTO #TempPersonasClean
    FROM #TempPersonasProcesadas 
    WHERE rn = 1 AND DNI_INT IS NOT NULL;

    -- 5. Actualizar Personas existentes
    UPDATE PP
    SET
        PP.nombre = TPC.NombreLimpio, PP.apellido = TPC.ApellidoLimpio, PP.email = TPC.EmailLimpio,
        PP.telefono = TPC.TelefonoINT, PP.es_inquilino = TPC.InquilinoBIT
    FROM Propiedades.Persona PP
    INNER JOIN #TempPersonasClean TPC ON PP.dni = TPC.DNI_INT;

    -- 6. Insertar nuevas Personas
    INSERT INTO Propiedades.Persona (nombre, apellido, dni, email, telefono, es_inquilino)
    SELECT
        TPC.NombreLimpio, TPC.ApellidoLimpio, TPC.DNI_INT,
        TPC.EmailLimpio, TPC.TelefonoINT, TPC.InquilinoBIT
    FROM #TempPersonasClean TPC
    WHERE NOT EXISTS (SELECT 1 FROM Propiedades.Persona PP WHERE PP.dni = TPC.DNI_INT);

    -- 7. Actualizar e insertar Persona_CuentaBancaria 
    UPDATE TPCB
    SET TPCB.id_persona = P.id_persona, TPCB.activa = 1
    FROM Tesoreria.Persona_CuentaBancaria TPCB
    INNER JOIN #TempPersonasClean TPC ON TPCB.cbu_cvu = TPC.CBU_Limpio
    INNER JOIN Propiedades.Persona P ON TPC.DNI_INT = P.dni
    WHERE TPC.CBU_Limpio IS NOT NULL AND LEN(TPC.CBU_Limpio) = 22;

    INSERT INTO Tesoreria.Persona_CuentaBancaria (id_persona, cbu_cvu, activa)
    SELECT P.id_persona, TPC.CBU_Limpio, 1
    FROM #TempPersonasClean TPC
    INNER JOIN Propiedades.Persona P ON TPC.DNI_INT = P.dni
    WHERE TPC.CBU_Limpio IS NOT NULL AND LEN(TPC.CBU_Limpio) = 22
      AND NOT EXISTS (SELECT 1 FROM Tesoreria.Persona_CuentaBancaria TPCB WHERE TPCB.cbu_cvu = TPC.CBU_Limpio);

    -- 8. Reporte de errores y resultados
    DECLARE @errores_encontrados INT;
    SELECT @errores_encontrados = COUNT(*) FROM #ErroresImportacion;

    PRINT 'Proceso de importación finalizado.';

    IF @errores_encontrados > 0
    BEGIN
        PRINT 'ATENCIÓN: Se encontraron ' + CAST(@errores_encontrados AS VARCHAR) + ' registros con errores que no fueron importados.';
        PRINT 'Detalle de los registros con errores:';
        SELECT * FROM #ErroresImportacion;
    END
    ELSE
    BEGIN
        PRINT 'Todos los registros del archivo fueron procesados sin errores.';
    END

    DROP TABLE #TempPersonas;
    DROP TABLE #TempPersonasClean;
    DROP TABLE #ErroresImportacion;
    DROP TABLE #TempPersonasProcesadas; 
    SET NOCOUNT OFF;
END;
GO