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
            importe   DECIMAL(18,2)     -- guardamos número limpio (sin formato visual)
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
        /* Limpieza básica previa: sacar $, espacios y NBSP; trabajar con NVARCHAR */
        CROSS APPLY (SELECT 
            REPLACE(REPLACE(REPLACE(CAST(kv.[value] AS NVARCHAR(100)),'$',''),' ',''), NCHAR(160),'') AS raw
        ) AS c
        /* Posiciones del último ',' y del último '.' en el string */
        CROSS APPLY (SELECT
            CASE WHEN CHARINDEX(',', c.raw) > 0 
                 THEN LEN(c.raw) - CHARINDEX(',', REVERSE(c.raw)) + 1 ELSE 0 END AS p_comma,
            CASE WHEN CHARINDEX('.', c.raw) > 0 
                 THEN LEN(c.raw) - CHARINDEX('.', REVERSE(c.raw)) + 1 ELSE 0 END AS p_dot
        ) AS pos
        /* Regla: el último separador es el decimal; el otro es miles y se borra */
        CROSS APPLY (SELECT
            CASE 
                WHEN pos.p_comma > 0 AND pos.p_dot > 0 THEN
                    /* Hay ambos: si la última es la coma -> coma decimal; si no, punto decimal */
                    CASE WHEN pos.p_comma > pos.p_dot 
                         THEN REPLACE(REPLACE(c.raw,'.',''),',','.')   -- '.' miles, ',' decimal
                         ELSE REPLACE(REPLACE(c.raw,',',''),'.','.')   -- ',' miles, '.' decimal
                    END
                WHEN pos.p_comma > 0 THEN
                    /* Solo coma: si está a 1-2 dígitos del final => decimal; si no, miles */
                    CASE WHEN LEN(c.raw) - pos.p_comma <= 2 
                         THEN REPLACE(c.raw,',','.') 
                         ELSE REPLACE(c.raw,',','') 
                    END
                WHEN pos.p_dot > 0 THEN
                    /* Solo punto: idem */
                    CASE WHEN LEN(c.raw) - pos.p_dot <= 2 
                         THEN c.raw 
                         ELSE REPLACE(c.raw,'.','') 
                    END
                ELSE c.raw
            END AS normalized
        ) AS n
        WHERE kv.[key] NOT IN ('_id', N'Nombre del consorcio', 'Mes')
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

        /* 4) Crear Expensa_Consorcio por (consorcio, mes) con total_ordinarios */
        INSERT INTO General.Expensa_Consorcio
        (
            id_consorcio, periodo, fecha_emision, total_ordinarios, total_extraordinarios, interes_por_mora
        )
        SELECT
            c.id_consorcio,
            t.mes,
            NULL,                       -- fecha_emision (ajustar si corresponde)
            t.total,                    -- total_ordinarios
            NULL,                       -- total_extraordinarios
            NULL                        -- interes_por_mora
        FROM (
            SELECT consorcio, mes, SUM(importe) AS total
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

        /* 6) Insertar Gastos (tipo 'Ordinario') evitando duplicados */
        INSERT INTO General.Gasto(
            id_expensa_consorcio, tipo, categoria,
            descripcion, nombre_proveedor, nro_factura, importe
        )
        SELECT
            m.id_expensa_consorcio,
            'Ordinario',
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
              AND g.tipo = 'Ordinario'
              AND g.categoria = s.categoria
              AND g.importe = s.importe
        );

        COMMIT TRAN;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(4000) = CONCAT('Error (', ERROR_NUMBER(), '): ', ERROR_MESSAGE());
        ;THROW 52010, @msg, 1;
    END CATCH
END;
GO
