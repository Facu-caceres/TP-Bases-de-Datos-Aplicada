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
Descripción: SP para importar datos de proveedores desde un archivo xlsx al esquema General.
*/
USE [Com5600G14];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_importar_proveedores
    @ruta_archivo NVARCHAR(MAX)
AS
BEGIN  
    SET NOCOUNT ON;

    -- 1. Crear una tabla temporal para cargar los datos crudos del xlsx
    IF OBJECT_ID('tempdb..#TempProveedores') IS NOT NULL DROP TABLE #TempProveedores;
    CREATE TABLE #TempProveedores (
        Tipo NVARCHAR(100),
        Nombre NVARCHAR(100),
        Alias VARCHAR(20),
        Nombre_Consorcio NVARCHAR(100)
    );

    -- 2. Cargar los datos desde el Excel (hoja Proveedores) a la tabla temporal
    BEGIN TRY
        DECLARE @provider NVARCHAR(100) = N'Microsoft.ACE.OLEDB.16.0';
        DECLARE @sql NVARCHAR(MAX) = N'
            INSERT INTO #TempProveedores (Tipo, Nombre, Alias, Nombre_Consorcio)
            SELECT
                CAST(NULLIF(LTRIM(RTRIM(F1)), '''') AS NVARCHAR(100)) AS Tipo,
                CAST(NULLIF(LTRIM(RTRIM(F2)), '''') AS NVARCHAR(100)) AS Nombre,
                CAST(NULLIF(LTRIM(RTRIM(F3)), '''') AS VARCHAR(20))   AS Alias,
                CAST(NULLIF(LTRIM(RTRIM(F4)), '''') AS NVARCHAR(100)) AS Nombre_Consorcio
            FROM OPENROWSET(''' + @provider + N''',
                            ''Excel 12.0;HDR=NO;IMEX=1;Database=' + REPLACE(@ruta_archivo,'''','''''') + N''',
                            ''SELECT * FROM [Proveedores$]'') AS X
            WHERE NULLIF(LTRIM(RTRIM(F1)), '''') IS NOT NULL; -- Omitir filas donde la primera columna (Tipo) está vacía
        ';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT 'Error al intentar cargar la hoja Proveedores del Excel: ' + @ruta_archivo;
        PRINT ERROR_MESSAGE();
        
        -- Limpiar la tabla temporal si falla la carga
        IF OBJECT_ID('tempdb..#TempProveedores') IS NOT NULL DROP TABLE #TempProveedores;
        RETURN;
    END CATCH

    -- 3. Actualizar registros existentes (clave lógica: Tipo)
    -- Se usa COALESCE para mantener el valor existente en la tabla si el Excel trae NULL
    UPDATE T
    SET 
        T.Nombre           = COALESCE(S.Nombre, T.Nombre),
        T.Alias            = COALESCE(S.Alias,  T.Alias),
        T.Nombre_Consorcio = COALESCE(S.Nombre_Consorcio, T.Nombre_Consorcio)
    FROM General.Proveedor T
    JOIN #TempProveedores S ON S.Tipo = T.Tipo;

    -- 4. Insertar nuevos registros
    INSERT INTO General.Proveedor (Tipo, Nombre, Alias, Nombre_Consorcio)
    SELECT 
        S.Tipo, 
        S.Nombre, 
        S.Alias, 
        S.Nombre_Consorcio
    FROM #TempProveedores S
    WHERE NOT EXISTS (
        SELECT 1 
        FROM General.Proveedor T 
        WHERE T.Tipo = S.Tipo
    );

    PRINT 'Proceso de importación de proveedores (General.Proveedor) finalizado.';

    -- 5. Limpiar la tabla temporal
    DROP TABLE #TempProveedores;
    SET NOCOUNT OFF;
END;
GO