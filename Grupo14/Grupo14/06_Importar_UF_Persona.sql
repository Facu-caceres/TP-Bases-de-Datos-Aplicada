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
Descripción: SP para importar las relaciones entre Personas y Unidades Funcionales (UF) desde un archivo CSV.
*/
USE [Com5600_Grupo14_DB];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_importar_uf_persona
    @ruta_archivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tabla temporal para la carga masiva de relaciones.
    IF OBJECT_ID('tempdb..#TempUFPersona') IS NOT NULL DROP TABLE #TempUFPersona;
    CREATE TABLE #TempUFPersona (
        cbu_cvu VARCHAR(22),
        nombre_consorcio VARCHAR(100),
        nro_uf INT,
        piso VARCHAR(10),
        departamento VARCHAR(10)
    );

    -- 2. Carga masiva desde el archivo CSV.
    BEGIN TRY
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = N'
            BULK INSERT #TempUFPersona
            FROM ''' + @ruta_archivo + N'''
            WITH (
                FIELDTERMINATOR = ''|'',
                ROWTERMINATOR = ''\n'',
                FIRSTROW = 2,
                CODEPAGE = ''ACP''
            );';
        EXEC sp_executesql @sql;
        -- Se eliminan filas que puedan venir vacías.
        DELETE FROM #TempUFPersona WHERE cbu_cvu IS NULL OR nombre_consorcio IS NULL;
    END TRY
    BEGIN CATCH
        PRINT 'Error al intentar cargar el archivo CSV de UF-Persona: ' + @ruta_archivo;
        PRINT ERROR_MESSAGE();
        RETURN;
    END CATCH

    -- 3. Insertar nuevas relaciones en Propiedades.UF_Persona resolviendo los IDs.
    INSERT INTO Propiedades.UF_Persona (id_uf, id_persona)
    SELECT
        uf.id_uf,
        pcb.id_persona
    FROM #TempUFPersona temp
    -- Join para obtener el id_persona a través del CBU/CVU
    INNER JOIN Tesoreria.Persona_CuentaBancaria pcb ON temp.cbu_cvu = pcb.cbu_cvu
    -- Join para obtener el id_consorcio a través del nombre
    INNER JOIN General.Consorcio c ON temp.nombre_consorcio = c.nombre
    -- Join para obtener el id_uf usando el id_consorcio y el número de UF
    INNER JOIN Propiedades.UnidadFuncional uf ON c.id_consorcio = uf.id_consorcio AND temp.nro_uf = uf.numero
    WHERE NOT EXISTS (
        SELECT 1
        FROM Propiedades.UF_Persona ufp
        WHERE ufp.id_uf = uf.id_uf AND ufp.id_persona = pcb.id_persona
    );

    PRINT 'Proceso de importación de relaciones UF-Persona finalizado.';

    DROP TABLE #TempUFPersona;
    SET NOCOUNT OFF;
END;
GO