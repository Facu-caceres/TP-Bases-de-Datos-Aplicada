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
Descripción: SP para importar los servicios desde el archivo json.
*/

USE [Com5600G14];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_importar_servicios_json
    @ruta_archivo NVARCHAR(4000) 
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        /* 1) Leer archivo JSON a tabla temporal (OPENROWSET requiere SQL dinámico) */
        IF OBJECT_ID('tempdb..#JsonFile') IS NOT NULL DROP TABLE #JsonFile;
        CREATE TABLE #JsonFile (BulkColumn NVARCHAR(MAX));

        DECLARE @sql NVARCHAR(MAX) =
            'INSERT INTO #JsonFile(BulkColumn)
              SELECT BulkColumn
              FROM OPENROWSET(BULK ''' + REPLACE(@ruta_archivo,'''','''''') + ''', SINGLE_CLOB) AS j;';
        EXEC (@sql);

        /* 2) Staging: Consorcio, Mes, Categoria, Importe (normalización POSICIONAL robusta) */
        IF OBJECT_ID('tempdb..#StgServicios') IS NOT NULL DROP TABLE #StgServicios;
        CREATE TABLE #StgServicios(
            consorcio NVARCHAR(200),
            mes       NVARCHAR(50),
            categoria NVARCHAR(200),
            importe   DECIMAL(18,2)     -- guardamos número limpio
        );

        INSERT INTO #StgServicios(consorcio, mes, categoria, importe)
        SELECT
            d.Consorcio,
            LTRIM(RTRIM(d.Mes))                         AS mes,
            kv.[key]                                    AS categoria,
            TRY_CONVERT(DECIMAL(18,2),
                CASE
                    WHEN kv.[type] = 2 THEN kv.[value]  -- número JSON puro
                    ELSE n.normalized                   -- string normalizado -> decimal
                END
            ) AS importe
        FROM #JsonFile jf
        CROSS APPLY OPENJSON(jf.BulkColumn)
             WITH (
                 Consorcio NVARCHAR(200) '$."Nombre del consorcio"',
                 Mes       NVARCHAR(50)  '$."Mes"',
                 _obj      NVARCHAR(MAX) '$' AS JSON
             ) AS d
        CROSS APPLY OPENJSON(d._obj) AS kv
        CROSS APPLY (SELECT 
            REPLACE(REPLACE(REPLACE(CAST(kv.[value] AS NVARCHAR(100)),'$',''),' ',''), NCHAR(160),'') AS raw
        ) AS c
        CROSS APPLY (SELECT
            CASE WHEN CHARINDEX(',', c.raw) > 0 
                 THEN LEN(c.raw) - CHARINDEX(',', REVERSE(c.raw)) + 1 ELSE 0 END AS p_comma,
            CASE WHEN CHARINDEX('.', c.raw) > 0 
                 THEN LEN(c.raw) - CHARINDEX('.', REVERSE(c.raw)) + 1 ELSE 0 END AS p_dot
        ) AS pos
        CROSS APPLY (SELECT
            CASE 
                WHEN pos.p_comma > 0 AND pos.p_dot > 0 THEN
                    CASE WHEN pos.p_comma > pos.p_dot 
                         THEN REPLACE(REPLACE(c.raw,'.',''),',','.')   
                         ELSE REPLACE(REPLACE(c.raw,',',''),'.','.')   
                    END
                WHEN pos.p_comma > 0 THEN
                    CASE WHEN LEN(c.raw) - pos.p_comma <= 2 
                         THEN REPLACE(c.raw,',','.') 
                         ELSE REPLACE(c.raw,',','') 
                    END
                WHEN pos.p_dot > 0 THEN
                    CASE WHEN LEN(c.raw) - pos.p_dot <= 2 
                         THEN c.raw 
                         ELSE REPLACE(c.raw,'.','') 
                    END
                ELSE c.raw
            END AS normalized
        ) AS n
        WHERE kv.[key] NOT IN ('_id', N'Nombre del consorcio', 'Mes', 'anio') -- Filtramos 'anio' si viene en el JSON nuevo
          AND kv.[value] IS NOT NULL
          AND TRY_CONVERT(DECIMAL(18,2),
                CASE WHEN kv.[type] = 2 THEN kv.[value] ELSE n.normalized END
              ) IS NOT NULL;

        IF NOT EXISTS (SELECT 1 FROM #StgServicios)
            THROW 52001, 'El JSON no trajo filas válidas (¿ruta, permisos o formato de números?).', 1;

        /* 3) Upsert Consorcios */
        INSERT INTO General.Consorcio(nombre)
        SELECT DISTINCT s.consorcio
        FROM #StgServicios s
        WHERE s.consorcio IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM General.Consorcio c WHERE c.nombre = s.consorcio);

        /* 4) Crear Expensa_Consorcio por (consorcio, mes) INICIALMENTE EN 0 o NULL */
        INSERT INTO General.Expensa_Consorcio
        (
            id_consorcio, periodo, fecha_emision, total_ordinarios, total_extraordinarios, interes_por_mora
        )
        SELECT
            c.id_consorcio,
            t.mes,
            NULL,                       
            0,                          -- Inicializamos en 0, luego se recalcula
            0,                          -- Inicializamos en 0
            NULL                        
        FROM (
            SELECT consorcio, mes
            FROM #StgServicios
            GROUP BY consorcio, mes
        ) AS t
        JOIN General.Consorcio c ON c.nombre = t.consorcio
        WHERE NOT EXISTS (
            SELECT 1 FROM General.Expensa_Consorcio ec
            WHERE ec.id_consorcio = c.id_consorcio AND ec.periodo = t.mes
        );

        /* 5) Map de expensas para insertar gastos (incluye ya existentes) */
        IF OBJECT_ID('tempdb..#ExpMap') IS NOT NULL DROP TABLE #ExpMap;
        CREATE TABLE #ExpMap(consorcio NVARCHAR(200), mes NVARCHAR(50), id_expensa_consorcio INT);

        INSERT INTO #ExpMap(consorcio, mes, id_expensa_consorcio)
        SELECT DISTINCT s.consorcio, s.mes, ec.id_expensa_consorcio
        FROM #StgServicios s
        JOIN General.Consorcio c ON c.nombre = s.consorcio
        JOIN General.Expensa_Consorcio ec
          ON ec.id_consorcio = c.id_consorcio
         AND ec.periodo      = s.mes;

        /* 6) Insertar Gastos evitando duplicados */
        INSERT INTO General.Gasto(
            id_expensa_consorcio, tipo, categoria,
            descripcion, nombre_proveedor, nro_factura, importe
        )
        SELECT
            m.id_expensa_consorcio,
            CASE WHEN s.categoria LIKE '%EXTRAORDINARI%' THEN 'Extraordinario' ELSE 'Ordinario' END,
            s.categoria,
            NULL, NULL, NULL,
            s.importe
        FROM #StgServicios s
        JOIN #ExpMap m
          ON m.consorcio = s.consorcio
         AND m.mes       = s.mes
        WHERE NOT EXISTS (
            SELECT 1
            FROM General.Gasto g
            WHERE g.id_expensa_consorcio = m.id_expensa_consorcio
              AND g.categoria = s.categoria
              AND g.importe = s.importe
        );

        /* 7) RECALCULAR TOTALES EN CABECERA (Expensa_Consorcio) */
        -- Logica solicitada para actualizar total_ordinarios y total_extraordinarios
        -- basada en la suma de los gastos recién insertados o existentes.
        
        ;WITH Totales AS (
            SELECT 
                g.id_expensa_consorcio,
                SUM(CASE 
                        WHEN g.categoria LIKE '%EXTRAORDINARI%' 
                            THEN 0 
                        ELSE g.importe 
                    END) AS total_ordinarios,
                SUM(CASE 
                        WHEN g.categoria LIKE '%EXTRAORDINARI%' 
                            THEN g.importe 
                        ELSE 0 
                    END) AS total_extraordinarios
            FROM General.Gasto g
            -- Unimos con el mapa para actualizar solo las expensas tocadas en este JSON (Optimización)
            INNER JOIN #ExpMap m ON g.id_expensa_consorcio = m.id_expensa_consorcio
            GROUP BY g.id_expensa_consorcio
        )
        UPDATE ec
        SET ec.total_ordinarios      = t.total_ordinarios,
            ec.total_extraordinarios = t.total_extraordinarios
        FROM General.Expensa_Consorcio ec
        JOIN Totales t 
          ON t.id_expensa_consorcio = ec.id_expensa_consorcio;

        COMMIT TRAN;
        PRINT 'Proceso de importación de Servicios y Recálculo de Totales finalizado.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(4000) = CONCAT('Error (', ERROR_NUMBER(), '): ', ERROR_MESSAGE());
        ;THROW 52010, @msg, 1;
    END CATCH
END;
GO