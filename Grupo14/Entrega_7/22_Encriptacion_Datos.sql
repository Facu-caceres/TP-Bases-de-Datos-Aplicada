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
             1. Modificación estructural (Columnas Hash para DNI, Email, Teléfono y CBU).
             2. Migración de datos existentes.
             3. Triggers de mantenimiento automático.
             4. Actualización de Reportes.
*/

USE [Com5600G14];
GO

-----------------------------------------------------------------------------------------
-- 1. MODIFICACIÓN DE ESTRUCTURA (Agregar columnas Hash)
-----------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'dni_hash' AND object_id = OBJECT_ID('Propiedades.Persona'))
BEGIN
    ALTER TABLE Propiedades.Persona ADD dni_hash VARBINARY(32) NULL;
    PRINT 'Columna dni_hash agregada.';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'email_hash' AND object_id = OBJECT_ID('Propiedades.Persona'))
BEGIN
    ALTER TABLE Propiedades.Persona ADD email_hash VARBINARY(32) NULL;
    PRINT 'Columna email_hash agregada.';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'telefono_hash' AND object_id = OBJECT_ID('Propiedades.Persona'))
BEGIN
    ALTER TABLE Propiedades.Persona ADD telefono_hash VARBINARY(32) NULL;
    PRINT 'Columna telefono_hash agregada.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'cbu_hash' AND object_id = OBJECT_ID('Tesoreria.Persona_CuentaBancaria'))
BEGIN
    ALTER TABLE Tesoreria.Persona_CuentaBancaria ADD cbu_hash VARBINARY(32) NULL; 
    PRINT 'Columna cbu_hash agregada.';
END
GO

-----------------------------------------------------------------------------------------
-- 2. MIGRACIÓN DE DATOS EXISTENTES
-----------------------------------------------------------------------------------------
PRINT 'Migrando datos a formato HASH (SHA-256)...';
BEGIN TRANSACTION;
    
    -- Hashear DNI, Email y Teléfono
    UPDATE Propiedades.Persona
    SET dni_hash      = HASHBYTES('SHA2_256', CAST(dni AS NVARCHAR(20))),
        email_hash    = HASHBYTES('SHA2_256', CAST(email AS NVARCHAR(255))),
        telefono_hash = HASHBYTES('SHA2_256', CAST(telefono AS NVARCHAR(20)))
    WHERE dni IS NOT NULL OR email IS NOT NULL OR telefono IS NOT NULL;

    -- Hashear CBU
    UPDATE Tesoreria.Persona_CuentaBancaria
    SET cbu_hash = HASHBYTES('SHA2_256', CAST(cbu_cvu AS NVARCHAR(100)))
    WHERE cbu_cvu IS NOT NULL AND cbu_hash IS NULL;

COMMIT TRANSACTION;
PRINT 'Datos migrados.';
GO

-----------------------------------------------------------------------------------------
-- 3. CREACIÓN DE TRIGGERS 
-----------------------------------------------------------------------------------------

-- 3.1 Trigger Persona (Cubre DNI, Email y Teléfono)
CREATE OR ALTER TRIGGER Propiedades.trg_Persona_Seguridad
ON Propiedades.Persona
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Si cambia alguno de los datos sensibles, regeneramos su hash
    IF UPDATE(dni) OR UPDATE(email) OR UPDATE(telefono)
    BEGIN
        UPDATE P
        SET P.dni_hash      = HASHBYTES('SHA2_256', CAST(I.dni AS NVARCHAR(20))),
            P.email_hash    = HASHBYTES('SHA2_256', CAST(I.email AS NVARCHAR(255))),
            P.telefono_hash = HASHBYTES('SHA2_256', CAST(I.telefono AS NVARCHAR(20)))
        FROM Propiedades.Persona P
        INNER JOIN inserted I ON P.id_persona = I.id_persona;
    END
END
GO
PRINT 'Trigger Persona actualizado.';
GO

-- 3.2 Trigger Cuenta Bancaria (Cubre CBU)
CREATE OR ALTER TRIGGER Tesoreria.trg_CuentaBancaria_Seguridad
ON Tesoreria.Persona_CuentaBancaria
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(cbu_cvu)
    BEGIN
        UPDATE CB
        SET CB.cbu_hash = HASHBYTES('SHA2_256', CAST(I.cbu_cvu AS NVARCHAR(100)))
        FROM Tesoreria.Persona_CuentaBancaria CB
        INNER JOIN inserted I ON CB.id_persona_cuenta = I.id_persona_cuenta;
    END
END
GO
PRINT 'Trigger CuentaBancaria actualizado.';
GO

-----------------------------------------------------------------------------------------
-- 4. ACTUALIZACIÓN DEL REPORTE 14
-----------------------------------------------------------------------------------------
PRINT 'Actualizando Reporte 14 para usar columnas hash persistidas...';
GO

CREATE OR ALTER PROCEDURE Reportes.sp_reporte_top_morosidad_propietarios
    @FechaCorte       date,
    @IdConsorcio      int    = NULL,
    @IncluirExtra     bit    = 0,
    @MesesFiltroCSV   nvarchar(max) = NULL,
    @TopN             int    = 3            
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaCorte IS NULL
    BEGIN 
        RAISERROR('Debe indicar @FechaCorte.',16,1); 
        RETURN; 
    END;

    DECLARE @VerHash bit = 0;
    IF IS_ROLEMEMBER('Rol_AdmGeneral') = 1 OR IS_ROLEMEMBER('Rol_Sistemas') = 1 OR IS_ROLEMEMBER('Rol_AdmBancario') = 1 OR IS_ROLEMEMBER('Rol_AdmOperativo') = 1 
        SET @VerHash = 1;

    DECLARE @Meses table (periodo nvarchar(50) PRIMARY KEY);
    IF @MesesFiltroCSV IS NULL
    BEGIN
        INSERT INTO @Meses(periodo)
        SELECT DISTINCT LTRIM(RTRIM(LOWER(periodo))) FROM General.Expensa_Consorcio
        WHERE (@IdConsorcio IS NULL OR id_consorcio = @IdConsorcio);
    END
    ELSE
    BEGIN
        INSERT INTO @Meses(periodo)
        SELECT DISTINCT LTRIM(RTRIM(LOWER(value))) FROM STRING_SPLIT(@MesesFiltroCSV, ',');
    END;

    ;WITH PropietariosUF AS (
        SELECT
            p.id_persona, p.nombre, p.apellido, 
            p.dni, p.dni_hash,
            p.email, p.email_hash,
            p.telefono, p.telefono_hash,  
            uf.id_consorcio,
            ISNULL(NULLIF(uf.porcentaje_de_prorrateo,0),0) AS prorrateo
        FROM Propiedades.UF_Persona ufp
        JOIN Propiedades.Persona p        ON p.id_persona = ufp.id_persona
        JOIN Propiedades.UnidadFuncional uf ON uf.id_uf = ufp.id_uf
        WHERE p.es_inquilino = 0
          AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
    ),
    DeudaPersona AS (
        SELECT
            pu.id_persona, pu.id_consorcio,
            SUM(
                (ISNULL(ec.total_ordinarios,0) + CASE WHEN @IncluirExtra = 1 THEN ISNULL(ec.total_extraordinarios,0) ELSE 0 END)
                * (ISNULL(pu.prorrateo,0) / 100.0)
            ) AS DeudaEsperada
        FROM PropietariosUF pu
        JOIN General.Expensa_Consorcio ec ON ec.id_consorcio = pu.id_consorcio
        JOIN @Meses m ON LTRIM(RTRIM(LOWER(ec.periodo))) = m.periodo
        GROUP BY pu.id_persona, pu.id_consorcio
    ),
    PagosPersona AS (
        SELECT
            per.id_persona, uf.id_consorcio, SUM(p.importe) AS Pagos
        FROM Tesoreria.Pago p
        JOIN Tesoreria.Persona_CuentaBancaria pcb ON pcb.id_persona_cuenta = p.id_persona_cuenta
        JOIN Propiedades.Persona per             ON per.id_persona = pcb.id_persona
        JOIN Propiedades.UF_Persona ufp          ON ufp.id_persona = per.id_persona
        JOIN Propiedades.UnidadFuncional uf      ON uf.id_uf = ufp.id_uf
        WHERE p.fecha_de_pago <= @FechaCorte AND per.es_inquilino = 0
          AND (@IdConsorcio IS NULL OR uf.id_consorcio = @IdConsorcio)
        GROUP BY per.id_persona, uf.id_consorcio
    ),
    Morosidad AS (
        SELECT
            dp.id_persona, dp.id_consorcio,
            ISNULL(dp.DeudaEsperada,0) AS DeudaEsperada,
            ISNULL(pg.Pagos,0)         AS Pagos,
            CASE WHEN ISNULL(dp.DeudaEsperada,0) - ISNULL(pg.Pagos,0) > 0
                 THEN CAST(ISNULL(dp.DeudaEsperada,0) - ISNULL(pg.Pagos,0) AS decimal(18,2))
                 ELSE CAST(0 AS decimal(18,2))
            END AS Morosidad
        FROM DeudaPersona dp
        LEFT JOIN PagosPersona pg ON pg.id_persona = dp.id_persona AND pg.id_consorcio = dp.id_consorcio
    )
    SELECT TOP (@TopN)
        c.nombre AS Consorcio,
        per.apellido,
        per.nombre,
        -- DNI
        CASE WHEN @VerHash = 1 THEN ISNULL(CONVERT(varchar(64), per.dni_hash, 2), 'HASH-NULL')
             ELSE CAST(per.dni AS nvarchar(20)) END AS dni,
        -- EMAIL
        CASE WHEN @VerHash = 1 THEN ISNULL(CONVERT(varchar(64), per.email_hash, 2), 'HASH-NULL')
             ELSE per.email END AS email,
        -- TELEFONO
        CASE WHEN @VerHash = 1 THEN ISNULL(CONVERT(varchar(64), per.telefono_hash, 2), 'HASH-NULL')
             ELSE CAST(per.telefono AS nvarchar(20)) END AS telefono,
             
        m.DeudaEsperada, m.Pagos, m.Morosidad
    FROM Morosidad m
    JOIN Propiedades.Persona per ON per.id_persona = m.id_persona
    JOIN General.Consorcio c     ON c.id_consorcio = m.id_consorcio
    ORDER BY m.Morosidad DESC, per.apellido, per.nombre;
END
GO