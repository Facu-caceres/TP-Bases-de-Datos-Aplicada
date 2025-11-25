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
Descripción: Entrega 7 - Cifrado de Datos Sensibles.
             1. Agrega columnas VARBINARY (_hash) para cifrado simétrico.
             2. Migra datos usando EncryptByPassPhrase.
             3. Elimina dependencias (Índices y Constraints).
             4. Elimina columnas de texto plano.
             5. Regenera índices optimizados apuntando a las nuevas columnas cifradas.
             6. Actualiza todos los SP necesarios.
*/

USE [Com5600G14];
GO

-- Frase de paso para la encriptación (Simétrica)
DECLARE @PassPhrase NVARCHAR(128) = 'Grupo14_Secreto_2025';

-----------------------------------------------------------------------------------------
-- 1. MODIFICACIÓN DE ESTRUCTURA (Agregar columnas _hash VARBINARY)
-----------------------------------------------------------------------------------------

PRINT '>>> Agregando columnas VARBINARY para cifrado...';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'dni_hash' AND object_id = OBJECT_ID('Propiedades.Persona'))
    ALTER TABLE Propiedades.Persona ADD dni_hash VARBINARY(MAX) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'email_hash' AND object_id = OBJECT_ID('Propiedades.Persona'))
    ALTER TABLE Propiedades.Persona ADD email_hash VARBINARY(MAX) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'telefono_hash' AND object_id = OBJECT_ID('Propiedades.Persona'))
    ALTER TABLE Propiedades.Persona ADD telefono_hash VARBINARY(MAX) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'cbu_hash' AND object_id = OBJECT_ID('Tesoreria.Persona_CuentaBancaria'))
    ALTER TABLE Tesoreria.Persona_CuentaBancaria ADD cbu_hash VARBINARY(MAX) NULL;
GO

-----------------------------------------------------------------------------------------
-- 2. MIGRACIÓN DE DATOS 
-----------------------------------------------------------------------------------------

PRINT '>>> Migrando datos a formato cifrado (EncryptByPassPhrase)...';

BEGIN TRANSACTION;
    
    UPDATE Propiedades.Persona
    SET dni_hash      = EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(dni AS VARCHAR(50))),
        email_hash    = EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(email AS VARCHAR(255))),
        telefono_hash = EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(telefono AS VARCHAR(50)))
    WHERE dni IS NOT NULL;

    UPDATE Tesoreria.Persona_CuentaBancaria
    SET cbu_hash = EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(cbu_cvu AS VARCHAR(100)))
    WHERE cbu_cvu IS NOT NULL;

COMMIT TRANSACTION;
PRINT 'Datos migrados exitosamente.';
GO

-----------------------------------------------------------------------------------------
-- 3. ELIMINACIÓN DE DEPENDENCIAS Y COLUMNAS PLANAS
-----------------------------------------------------------------------------------------

PRINT '>>> Eliminando índices y constraints dependientes...';

BEGIN TRANSACTION;

    -- Eliminar Índice conflictivo
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Persona_Apellido_Nombre' AND object_id = OBJECT_ID('Propiedades.Persona'))
    BEGIN
        DROP INDEX IX_Persona_Apellido_Nombre ON Propiedades.Persona;
        PRINT 'Índice IX_Persona_Apellido_Nombre eliminado.';
    END

    -- Eliminar Constraints UNIQUE (DNI, CBU)
    DECLARE @ConstraintName NVARCHAR(200);
    
    SELECT @ConstraintName = name 
    FROM sys.key_constraints 
    WHERE parent_object_id = OBJECT_ID('Propiedades.Persona') AND type = 'UQ';
    
    IF @ConstraintName IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE Propiedades.Persona DROP CONSTRAINT ' + @ConstraintName);
        PRINT 'Constraint UNIQUE de DNI eliminado.';
    END

    SELECT @ConstraintName = NULL;
    SELECT @ConstraintName = name 
    FROM sys.key_constraints 
    WHERE parent_object_id = OBJECT_ID('Tesoreria.Persona_CuentaBancaria') AND type = 'UQ';

    IF @ConstraintName IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE Tesoreria.Persona_CuentaBancaria DROP CONSTRAINT ' + @ConstraintName);
        PRINT 'Constraint UNIQUE de CBU eliminado.';
    END

    -- Eliminar las columnas de texto plano
    IF EXISTS(SELECT 1 FROM sys.columns WHERE name = 'dni' AND object_id = OBJECT_ID('Propiedades.Persona'))
        ALTER TABLE Propiedades.Persona DROP COLUMN dni;
        
    IF EXISTS(SELECT 1 FROM sys.columns WHERE name = 'email' AND object_id = OBJECT_ID('Propiedades.Persona'))
        ALTER TABLE Propiedades.Persona DROP COLUMN email;
        
    IF EXISTS(SELECT 1 FROM sys.columns WHERE name = 'telefono' AND object_id = OBJECT_ID('Propiedades.Persona'))
        ALTER TABLE Propiedades.Persona DROP COLUMN telefono;

    IF EXISTS(SELECT 1 FROM sys.columns WHERE name = 'cbu_cvu' AND object_id = OBJECT_ID('Tesoreria.Persona_CuentaBancaria'))
        ALTER TABLE Tesoreria.Persona_CuentaBancaria DROP COLUMN cbu_cvu;

COMMIT TRANSACTION;
PRINT 'Columnas de texto plano eliminadas.';
GO

-----------------------------------------------------------------------------------------
-- 4. RECREACIÓN DE ÍNDICES OPTIMIZADOS 
-----------------------------------------------------------------------------------------

PRINT '>>> Regenerando índices optimizados con columnas _hash...';

-- Recreamos el índice que borramos pero incluyendo los campos hash
CREATE NONCLUSTERED INDEX IX_Persona_Apellido_Nombre
ON Propiedades.Persona (es_inquilino, apellido, nombre)
INCLUDE (dni_hash, email_hash, telefono_hash);
GO

PRINT 'Script de Seguridad completado correctamente.';
GO

---------------------------------------------------------------------------------------------------

USE [Com5600G14];
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

    -- 3. Procesamiento inicial
    SELECT
        Nombre, Apellido, DNI, Email, Telefono, CVU_CBU, EsInquilino,
        TRY_CAST(LTRIM(RTRIM(DNI)) AS INT) as DNI_INT,
        ROW_NUMBER() OVER(PARTITION BY LTRIM(RTRIM(DNI)) ORDER BY (SELECT NULL)) as rn
    INTO #TempPersonasProcesadas 
    FROM #TempPersonas;

    INSERT INTO #ErroresImportacion (Nombre, Apellido, DNI, Email, Telefono, CVU_CBU, EsInquilino, ErrorDescripcion)
    SELECT Nombre, Apellido, DNI, Email, Telefono, CVU_CBU, EsInquilino, 'DNI duplicado en archivo.'
    FROM #TempPersonasProcesadas 
    WHERE rn > 1 AND DNI_INT IS NOT NULL;

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

    -- 4. Actualizar Personas existentes (Buscando por DNI desencriptado)

    UPDATE PP
    SET
        PP.nombre = TPC.NombreLimpio, 
        PP.apellido = TPC.ApellidoLimpio, 
        -- Re-encriptamos si cambiaron
        PP.email_hash = EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(TPC.EmailLimpio AS VARCHAR(255))),
        PP.telefono_hash = EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(TPC.TelefonoINT AS VARCHAR(50))),
        PP.es_inquilino = TPC.InquilinoBIT
    FROM Propiedades.Persona PP
    INNER JOIN #TempPersonasClean TPC 
        ON CAST(DecryptByPassPhrase('Grupo14_Secreto_2025', PP.dni_hash) AS VARCHAR(50)) = CAST(TPC.DNI_INT AS VARCHAR(50));

    -- 5. Insertar nuevas Personas
    INSERT INTO Propiedades.Persona (nombre, apellido, dni_hash, email_hash, telefono_hash, es_inquilino)
    SELECT
        TPC.NombreLimpio, 
        TPC.ApellidoLimpio, 
        EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(TPC.DNI_INT AS VARCHAR(50))),
        EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(TPC.EmailLimpio AS VARCHAR(255))),
        EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(TPC.TelefonoINT AS VARCHAR(50))),
        TPC.InquilinoBIT
    FROM #TempPersonasClean TPC
    WHERE NOT EXISTS (
        SELECT 1 FROM Propiedades.Persona PP 
        WHERE CAST(DecryptByPassPhrase('Grupo14_Secreto_2025', PP.dni_hash) AS VARCHAR(50)) = CAST(TPC.DNI_INT AS VARCHAR(50))
    );

    -- 6. Insertar Cuentas Bancarias
    INSERT INTO Tesoreria.Persona_CuentaBancaria (id_persona, cbu_hash, activa)
    SELECT 
        P.id_persona, 
        EncryptByPassPhrase('Grupo14_Secreto_2025', CAST(TPC.CBU_Limpio AS VARCHAR(100))), 
        1
    FROM #TempPersonasClean TPC
    INNER JOIN Propiedades.Persona P 
        ON CAST(DecryptByPassPhrase('Grupo14_Secreto_2025', P.dni_hash) AS VARCHAR(50)) = CAST(TPC.DNI_INT AS VARCHAR(50))
    WHERE TPC.CBU_Limpio IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM Tesoreria.Persona_CuentaBancaria CB 
          WHERE CAST(DecryptByPassPhrase('Grupo14_Secreto_2025', CB.cbu_hash) AS VARCHAR(100)) = TPC.CBU_Limpio
      );

    PRINT 'Proceso de importación (Seguro) finalizado.';

    DROP TABLE #TempPersonas;
    DROP TABLE #TempPersonasClean;
    DROP TABLE #ErroresImportacion;
    DROP TABLE #TempPersonasProcesadas; 
    SET NOCOUNT OFF;
END;
GO

---------------------------------------------------------------------------------------------------

USE [Com5600G14];
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

    -- Verificar Permisos
    DECLARE @VerDatos bit = 0;
    IF IS_ROLEMEMBER('Rol_AdmGeneral') = 1 OR IS_ROLEMEMBER('Rol_Sistemas') = 1 OR IS_ROLEMEMBER('Rol_AdmBancario') = 1 OR IS_ROLEMEMBER('Rol_AdmOperativo') = 1 
        SET @VerDatos = 1;

    -- Filtro de Meses
    DECLARE @Meses table (periodo nvarchar(50) PRIMARY KEY);
    IF @MesesFiltroCSV IS NULL
        INSERT INTO @Meses SELECT DISTINCT LTRIM(RTRIM(LOWER(periodo))) FROM General.Expensa_Consorcio WHERE (@IdConsorcio IS NULL OR id_consorcio = @IdConsorcio);
    ELSE
        INSERT INTO @Meses SELECT DISTINCT LTRIM(RTRIM(LOWER(value))) FROM STRING_SPLIT(@MesesFiltroCSV, ',');

    -- CTEs de Calculo
    ;WITH PropietariosUF AS (
        SELECT p.id_persona, p.nombre, p.apellido, p.dni_hash, p.email_hash, p.telefono_hash, uf.id_consorcio, ISNULL(NULLIF(uf.porcentaje_de_prorrateo,0),0) AS prorrateo
        FROM Propiedades.UF_Persona ufp
        JOIN Propiedades.Persona p ON p.id_persona = ufp.id_persona
        JOIN Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
        WHERE p.es_inquilino = 0 AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
    ),
    DeudaPersona AS (
        SELECT pu.id_persona, pu.id_consorcio,
            SUM((ISNULL(ec.total_ordinarios,0) + CASE WHEN @IncluirExtra=1 THEN ISNULL(ec.total_extraordinarios,0) ELSE 0 END) * (ISNULL(pu.prorrateo,0)/100.0)) AS DeudaEsperada
        FROM PropietariosUF pu
        JOIN General.Expensa_Consorcio ec ON ec.id_consorcio = pu.id_consorcio
        JOIN @Meses m ON LTRIM(RTRIM(LOWER(ec.periodo))) = m.periodo
        GROUP BY pu.id_persona, pu.id_consorcio
    ),
    PagosPersona AS (
        SELECT per.id_persona, uf.id_consorcio, SUM(p.importe) AS Pagos
        FROM Tesoreria.Pago p
        JOIN Tesoreria.Persona_CuentaBancaria pcb ON pcb.id_persona_cuenta = p.id_persona_cuenta
        JOIN Propiedades.Persona per ON per.id_persona = pcb.id_persona
        JOIN Propiedades.UF_Persona ufp ON ufp.id_persona = per.id_persona
        JOIN Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
        WHERE p.fecha_de_pago <= @FechaCorte AND per.es_inquilino = 0 AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
        GROUP BY per.id_persona, uf.id_consorcio
    ),
    Morosidad AS (
        SELECT dp.id_persona, dp.id_consorcio, ISNULL(dp.DeudaEsperada,0) AS DeudaEsperada, ISNULL(pg.Pagos,0) AS Pagos,
            CASE WHEN ISNULL(dp.DeudaEsperada,0) - ISNULL(pg.Pagos,0) > 0 THEN CAST(ISNULL(dp.DeudaEsperada,0) - ISNULL(pg.Pagos,0) AS decimal(18,2)) ELSE 0 END AS Morosidad
        FROM DeudaPersona dp
        LEFT JOIN PagosPersona pg ON pg.id_persona = dp.id_persona AND pg.id_consorcio = dp.id_consorcio
    )
    
    -- SELECT FINAL CON DESENCRIPTADO CONDICIONAL
    SELECT TOP (@TopN)
        c.nombre AS Consorcio,
        per.apellido,
        per.nombre,
        
        -- DNI
        CASE WHEN @VerDatos = 1 
             THEN CAST(DecryptByPassPhrase('Grupo14_Secreto_2025', per.dni_hash) AS VARCHAR(50))
             ELSE CONVERT(VARCHAR(MAX), per.dni_hash, 1) -- Muestra el hash/binario como string
        END AS dni,

        -- EMAIL
        CASE WHEN @VerDatos = 1 
             THEN CAST(DecryptByPassPhrase('Grupo14_Secreto_2025', per.email_hash) AS VARCHAR(100))
             ELSE CONVERT(VARCHAR(MAX), per.email_hash, 1)
        END AS email,

        -- TELEFONO
        CASE WHEN @VerDatos = 1 
             THEN CAST(DecryptByPassPhrase('Grupo14_Secreto_2025', per.telefono_hash) AS VARCHAR(50))
             ELSE CONVERT(VARCHAR(MAX), per.telefono_hash, 1)
        END AS telefono,
             
        m.DeudaEsperada, m.Pagos, m.Morosidad
    FROM Morosidad m
    JOIN Propiedades.Persona per ON per.id_persona = m.id_persona
    JOIN General.Consorcio c     ON c.id_consorcio = m.id_consorcio
    ORDER BY m.Morosidad DESC, per.apellido, per.nombre;
END
GO

---------------------------------------------------------------------------------------------------

USE [Com5600G14];
GO

CREATE OR ALTER PROCEDURE Importacion.sp_importar_pagos
    @ruta_archivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tabla temporal para la carga masiva de pagos (RAW).
    IF OBJECT_ID('tempdb..#TempPagos') IS NOT NULL DROP TABLE #TempPagos;
    CREATE TABLE #TempPagos (
        id_pago VARCHAR(50), 
        fecha VARCHAR(50),
        cbu_cvu VARCHAR(22),
        valor VARCHAR(100)
    );

    -- 2. Carga masiva desde el archivo CSV.
    BEGIN TRY
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = N'
            BULK INSERT #TempPagos
            FROM ''' + @ruta_archivo + N'''
            WITH (
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\n'',
                FIRSTROW = 2,
                CODEPAGE = ''ACP''
            );';
        EXEC sp_executesql @sql;
        DELETE FROM #TempPagos WHERE id_pago IS NULL OR LTRIM(RTRIM(id_pago)) = '';
    END TRY
    BEGIN CATCH
        PRINT 'Error al intentar cargar el archivo CSV de Pagos: ' + @ruta_archivo;
        PRINT ERROR_MESSAGE();
        RETURN;
    END CATCH

    -- 3. Preparar mapeo de CBUs (Desencriptar para comparar)
    --    Como borramos la columna plana 'cbu_cvu' en la Entrega 7, 
    --    necesitamos desencriptar 'cbu_hash' para encontrar al dueño.
    IF OBJECT_ID('tempdb..#MapCBU') IS NOT NULL DROP TABLE #MapCBU;
    
    SELECT 
        id_persona_cuenta,
        -- Desencriptamos usando la misma frase de paso del script 22
        CAST(DecryptByPassPhrase('Grupo14_Secreto_2025', cbu_hash) AS VARCHAR(100)) AS cbu_plano
    INTO #MapCBU
    FROM Tesoreria.Persona_CuentaBancaria
    WHERE activa = 1; -- Solo buscamos en cuentas activas para optimizar

    -- 4. Tabla temporal para datos limpios y procesados con el cruce realizado
    IF OBJECT_ID('tempdb..#TempPagosClean') IS NOT NULL DROP TABLE #TempPagosClean;
    
    SELECT
        TRY_CAST(tp.id_pago AS INT) AS id_pago,
        map.id_persona_cuenta,
        TRY_CONVERT(DATE, tp.fecha, 103) AS fecha_de_pago,
        TRY_CAST(LTRIM(REPLACE(tp.valor, '$', '')) AS DECIMAL(18, 2)) AS importe, 
        tp.cbu_cvu AS cbu_origen, -- Guardamos el CBU origen tal cual viene (texto plano en Pagos)
        CASE WHEN map.id_persona_cuenta IS NOT NULL THEN 'Asociado' ELSE 'No Asociado' END AS estado
    INTO #TempPagosClean
    FROM #TempPagos tp
    LEFT JOIN #MapCBU map ON tp.cbu_cvu = map.cbu_plano;

    -- 5. Actualizar registros existentes en Tesoreria.Pago
    UPDATE Tpag
    SET
        Tpag.id_persona_cuenta = TPC.id_persona_cuenta,
        Tpag.fecha_de_pago = TPC.fecha_de_pago,
        Tpag.importe = TPC.importe,
        Tpag.cbu_origen = TPC.cbu_origen,
        Tpag.estado = TPC.estado
    FROM Tesoreria.Pago AS Tpag
    JOIN #TempPagosClean AS TPC ON Tpag.id_pago = TPC.id_pago;

    -- 6. Insertar nuevos registros en Tesoreria.Pago
    INSERT INTO Tesoreria.Pago (id_pago, id_persona_cuenta, fecha_de_pago, importe, cbu_origen, estado)
    SELECT
        TPC.id_pago,
        TPC.id_persona_cuenta,
        TPC.fecha_de_pago,
        TPC.importe,
        TPC.cbu_origen,
        TPC.estado
    FROM #TempPagosClean AS TPC
    WHERE NOT EXISTS (
        SELECT 1
        FROM Tesoreria.Pago AS Target
        WHERE Target.id_pago = TPC.id_pago
    );

    PRINT 'Proceso de importación de Pagos finalizado.';

    DROP TABLE #TempPagos;
    DROP TABLE #TempPagosClean;
    DROP TABLE #MapCBU;
    SET NOCOUNT OFF;
END;
GO