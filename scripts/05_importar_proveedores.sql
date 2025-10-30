CREATE OR ALTER PROCEDURE Importacion.sp_importar_proveedores
    @ruta_archivo NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @provider NVARCHAR(100) = N'Microsoft.ACE.OLEDB.16.0';

        -- Fuente: Excel a una subconsulta (S)
        DECLARE @S NVARCHAR(MAX) = N'
            SELECT
                CAST(NULLIF(LTRIM(RTRIM(F1)), '''') AS NVARCHAR(100)) AS Tipo,
                CAST(NULLIF(LTRIM(RTRIM(F2)), '''') AS NVARCHAR(100)) AS Nombre,
                CAST(NULLIF(LTRIM(RTRIM(F3)), '''') AS VARCHAR(20))   AS Alias,
                CAST(NULLIF(LTRIM(RTRIM(F4)), '''') AS NVARCHAR(100)) AS Nombre_Consorcio
            FROM OPENROWSET(''' + @provider + N''',
                            ''Excel 12.0;HDR=NO;IMEX=1;Database=' + REPLACE(@ruta_archivo,'''','''''') + N''',
                            ''SELECT * FROM [Proveedores$]'') AS X
            WHERE NULLIF(LTRIM(RTRIM(F1)), '''') IS NOT NULL
        ';

        -- 1) UPDATE existentes (clave lógica: Tipo)
        DECLARE @upd NVARCHAR(MAX) = N'
            UPDATE T
               SET T.Nombre           = COALESCE(S.Nombre, T.Nombre),
                   T.Alias            = COALESCE(S.Alias,  T.Alias),
                   T.Nombre_Consorcio = COALESCE(S.Nombre_Consorcio, T.Nombre_Consorcio)
            FROM General.Proveedor T
            JOIN (' + @S + N') S
              ON S.Tipo = T.Tipo;
        ';
        EXEC sp_executesql @upd;

        -- 2) INSERT nuevos
        DECLARE @ins NVARCHAR(MAX) = N'
            INSERT INTO General.Proveedor (Tipo, Nombre, Alias, Nombre_Consorcio)
            SELECT S.Tipo, S.Nombre, S.Alias, S.Nombre_Consorcio
            FROM (' + @S + N') S
            WHERE NOT EXISTS (SELECT 1 FROM General.Proveedor T WHERE T.Tipo = S.Tipo);
        ';
        EXEC sp_executesql @ins;

        PRINT 'Importación de Proveedores (update/insert) OK.';
    END TRY
    BEGIN CATCH
        PRINT 'Error al importar Proveedores (update/insert): ' + @ruta_archivo;
        PRINT ERROR_MESSAGE();
        RETURN;
    END CATCH
    SET NOCOUNT OFF;
END;
GO
