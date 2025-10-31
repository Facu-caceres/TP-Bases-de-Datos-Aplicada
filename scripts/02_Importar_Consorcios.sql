/*
Materia: 3641 - Bases de Datos Aplicada
Comisi�n: 02-5600
Grupo: 14
Integrantes: Aguirre Dario Ivan 44355010
             Caceres Olguin Facundo 45747823
             Ciriello Florencia Ailen 44833569
             Mangalaviti Sebastian 45233238
             Pedrol Ledesma Bianca Uriana 45012041
             Saladino Mauro Tomas 44531560
Fecha de Entrega: 07/11/2025
Descripci�n: SP para importar datos de consorcios desde un archivo xlsx al esquema General.
*/
USE [Com5600_Grupo14_DB];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_importar_consorcios
    @ruta_archivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Crear una tabla temporal para cargar los datos crudos del xlsx
    IF OBJECT_ID('tempdb..#TempConsorcios') IS NOT NULL DROP TABLE #TempConsorcios;
    CREATE TABLE #TempConsorcios (
        Consorcio VARCHAR(100),
        NombreConsorcio VARCHAR(100),
        Domicilio VARCHAR(100),
        CantUnidades INT,
        M2Totales VARCHAR(50)
    );

-- 2. Cargar los datos desde el Excel (hoja Consorcios) a la tabla temporal
BEGIN TRY
    DECLARE @provider NVARCHAR(100) = N'Microsoft.ACE.OLEDB.16.0'; -- o 12.0 seg�n lo instalado
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO #TempConsorcios (Consorcio, NombreConsorcio, Domicilio, CantUnidades, M2Totales)
        SELECT 
            [Consorcio],
            [Nombre del consorcio]    AS NombreConsorcio,
            [Domicilio],
            [Cant unidades funcionales] AS CantUnidades,
            CAST([m2 totales] AS NVARCHAR(50)) AS M2Totales
        FROM OPENROWSET(''' + @provider + N''',
                         ''Excel 12.0;HDR=YES;IMEX=1;Database=' + REPLACE(@ruta_archivo,'''','''''') + N''',
                         ''SELECT * FROM [Consorcios$]'') AS X;
    ';
    EXEC sp_executesql @sql;
END TRY
BEGIN CATCH
    PRINT 'Error al intentar cargar la hoja Consorcios del Excel: ' + @ruta_archivo;
    PRINT ERROR_MESSAGE();
    RETURN;
END CATCH


    -- 3. Actualizar registros existentes
    UPDATE GC
    SET
        GC.direccion = T.Domicilio,
        GC.cant_unidades_funcionales = T.CantUnidades,
        GC.m2_totales = TRY_CAST(REPLACE(T.M2Totales, ',', '.') AS DECIMAL(10, 2))
    FROM General.Consorcio GC
    INNER JOIN #TempConsorcios T ON GC.nombre = T.NombreConsorcio
    WHERE T.NombreConsorcio IS NOT NULL AND T.NombreConsorcio <> '';

    -- 4. Insertar nuevos registros
    INSERT INTO General.Consorcio (nombre, direccion, cant_unidades_funcionales, m2_totales)
    SELECT
        T.NombreConsorcio,
        T.Domicilio,
        T.CantUnidades,
        TRY_CAST(REPLACE(T.M2Totales, ',', '.') AS DECIMAL(10, 2))
    FROM #TempConsorcios T
    WHERE T.NombreConsorcio IS NOT NULL AND T.NombreConsorcio <> ''
      AND NOT EXISTS (
          SELECT 1
          FROM General.Consorcio GC
          WHERE GC.nombre = T.NombreConsorcio
      );

    PRINT 'Proceso de importaci�n de consorcios (General.Consorcio) finalizado.';

    -- Limpiar la tabla temporal
    DROP TABLE #TempConsorcios;
    SET NOCOUNT OFF;
END;
GO