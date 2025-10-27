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
Descripción: SP para importar datos de Unidades Funcionales (UF) desde un archivo TXT al esquema Propiedades.
*/
USE [Com5600_Grupo14_DB];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_importar_uf
    @ruta_archivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tabla temporal para la carga masiva
    IF OBJECT_ID('tempdb..#TempUF') IS NOT NULL DROP TABLE #TempUF;
    CREATE TABLE #TempUF (
        nombre_consorcio VARCHAR(100),
        nro_uf INT,
        piso VARCHAR(10),
        departamento VARCHAR(10),
        coeficiente VARCHAR(10),
        m2_uf VARCHAR(50),
        bauleras VARCHAR(5),
        cochera VARCHAR(5),
        m2_baulera VARCHAR(50),
        m2_cochera VARCHAR(50)
    );

    -- 2. Carga masiva desde el archivo TXT
    BEGIN TRY
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = N'
            BULK INSERT #TempUF
            FROM ''' + @ruta_archivo + N'''
            WITH (
                FIELDTERMINATOR = ''\t'',
                ROWTERMINATOR = ''\n'',
                FIRSTROW = 2,
                CODEPAGE = ''65001''
            );';
        EXEC sp_executesql @sql;
        DELETE FROM #TempUF WHERE nombre_consorcio IS NULL OR nro_uf IS NULL;
    END TRY
    BEGIN CATCH
        PRINT 'Error al intentar cargar el archivo TXT de UF: ' + @ruta_archivo;
        PRINT ERROR_MESSAGE();
        RETURN;
    END CATCH

    -- 3. Crear tabla temporal con datos limpios y FK resuelta
    IF OBJECT_ID('tempdb..#TempUFClean') IS NOT NULL DROP TABLE #TempUFClean;
    SELECT
        c.id_consorcio,
        tuf.nro_uf,
        LEFT(LTRIM(RTRIM(tuf.piso)), 3) AS piso_limpio,
        LEFT(LTRIM(RTRIM(tuf.departamento)), 1) AS depto_limpio,
        TRY_CAST(REPLACE(tuf.m2_uf, ',', '.') AS DECIMAL(10, 2)) AS superficie_limpia,
        TRY_CAST(REPLACE(tuf.coeficiente, ',', '.') AS DECIMAL(5, 2)) AS porcentaje_limpio,
        CASE WHEN LTRIM(RTRIM(UPPER(tuf.bauleras))) = 'SI' THEN 1 ELSE 0 END AS tiene_baulera,
        CASE WHEN LTRIM(RTRIM(UPPER(tuf.cochera))) = 'SI' THEN 1 ELSE 0 END AS tiene_cochera,
        TRY_CAST(REPLACE(tuf.m2_baulera, ',', '.') AS DECIMAL(10, 2)) AS m2_baulera_limpio,
        TRY_CAST(REPLACE(tuf.m2_cochera, ',', '.') AS DECIMAL(10, 2)) AS m2_cochera_limpio
    INTO #TempUFClean
    FROM #TempUF tuf
    INNER JOIN General.Consorcio c ON tuf.nombre_consorcio = c.nombre
    WHERE tuf.nro_uf IS NOT NULL;

    -- 4. Actualizar registros existentes
    UPDATE PUF
    SET
        PUF.piso = T.piso_limpio,
        PUF.departamento = T.depto_limpio,
        PUF.superficie = T.superficie_limpia,
        PUF.porcentaje_de_prorrateo = T.porcentaje_limpio,
        PUF.tiene_baulera = T.tiene_baulera,
        PUF.tiene_cochera = T.tiene_cochera,
        PUF.m2_baulera = T.m2_baulera_limpio,
        PUF.m2_cochera = T.m2_cochera_limpio
    FROM Propiedades.UnidadFuncional PUF
    INNER JOIN #TempUFClean T ON PUF.id_consorcio = T.id_consorcio AND PUF.numero = T.nro_uf;

    -- 5. Insertar nuevos registros
    INSERT INTO Propiedades.UnidadFuncional (id_consorcio, numero, piso, departamento, superficie, porcentaje_de_prorrateo, tiene_baulera, tiene_cochera, m2_baulera, m2_cochera)
    SELECT
        T.id_consorcio,
        T.nro_uf,
        T.piso_limpio,
        T.depto_limpio,
        T.superficie_limpia,
        T.porcentaje_limpio,
        T.tiene_baulera,
        T.tiene_cochera,
        T.m2_baulera_limpio,
        T.m2_cochera_limpio
    FROM #TempUFClean T
    WHERE NOT EXISTS (
        SELECT 1
        FROM Propiedades.UnidadFuncional PUF
        WHERE PUF.id_consorcio = T.id_consorcio AND PUF.numero = T.nro_uf
    );

    PRINT 'Proceso de importación de Unidades Funcionales (Propiedades.UnidadFuncional) finalizado.';

    DROP TABLE #TempUF;
    DROP TABLE #TempUFClean;
    SET NOCOUNT OFF;
END;
GO