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
Fecha de Entrega: 07/12/2025
Descripción: Entrega 7 - Cifrado de Datos Sensibles.
*/

USE [Com5600_Grupo14_DB];
GO

-----------------------------------------------------------------------------------------
-- 1. MODIFICACIÓN DE ESTRUCTURA
-----------------------------------------------------------------------------------------

-- 1.1. Tabla Propiedades.Persona
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'dni_hash' AND object_id = OBJECT_ID('Propiedades.Persona'))
BEGIN
    ALTER TABLE Propiedades.Persona ADD dni_hash VARBINARY(32) NULL;
    PRINT 'Columna dni_hash agregada a Propiedades.Persona';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'email_hash' AND object_id = OBJECT_ID('Propiedades.Persona'))
BEGIN
    ALTER TABLE Propiedades.Persona ADD email_hash VARBINARY(32) NULL;
    PRINT 'Columna email_hash agregada a Propiedades.Persona';
END
GO

-- 1.2. Tabla Tesoreria.Persona_CuentaBancaria
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'cbu_cvu_encriptado' AND object_id = OBJECT_ID('Tesoreria.Persona_CuentaBancaria'))
BEGIN
    ALTER TABLE Tesoreria.Persona_CuentaBancaria ADD cbu_cvu_encriptado VARBINARY(256) NULL;
    PRINT 'Columna cbu_cvu_encriptado agregada a Tesoreria.Persona_CuentaBancaria';
END
GO

-----------------------------------------------------------------------------------------
-- 2. MIGRACIÓN DE DATOS EXISTENTES
-----------------------------------------------------------------------------------------
PRINT 'Verificando migración de datos...';

BEGIN TRANSACTION;
    
    -- Actualizar Hashes de Personas (solo si están nulos para no reprocesar innecesariamente)
    UPDATE Propiedades.Persona
    SET dni_hash = HASHBYTES('SHA2_256', CAST(dni AS NVARCHAR(20))),
        email_hash = HASHBYTES('SHA2_256', CAST(email AS NVARCHAR(255)))
    WHERE dni IS NOT NULL AND dni_hash IS NULL;

    -- Actualizar Encriptación de CBUs (solo si están nulos)
    UPDATE Tesoreria.Persona_CuentaBancaria
    SET cbu_cvu_encriptado = ENCRYPTBYPASSPHRASE('Grupo14_SecretKey_2025', cbu_cvu)
    WHERE cbu_cvu IS NOT NULL AND cbu_cvu_encriptado IS NULL;

COMMIT TRANSACTION;

PRINT 'Proceso de migración completado.';
GO

-----------------------------------------------------------------------------------------
-- 3. CREACIÓN DE TRIGGERS
-----------------------------------------------------------------------------------------

-- 3.1 Trigger para Propiedades.Persona
CREATE OR ALTER TRIGGER Propiedades.trg_Persona_Seguridad
ON Propiedades.Persona
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Si se actualizó dni o email, regeneramos el hash
    IF UPDATE(dni) OR UPDATE(email)
    BEGIN
        UPDATE P
        SET 
            P.dni_hash   = HASHBYTES('SHA2_256', CAST(I.dni AS NVARCHAR(20))),
            P.email_hash = HASHBYTES('SHA2_256', CAST(I.email AS NVARCHAR(255)))
        FROM Propiedades.Persona P
        INNER JOIN inserted I ON P.id_persona = I.id_persona;
    END
END
GO

PRINT 'Trigger trg_Persona_Seguridad creado/actualizado.';
GO  

-- 3.2 Trigger para Tesoreria.Persona_CuentaBancaria
CREATE OR ALTER TRIGGER Tesoreria.trg_CuentaBancaria_Seguridad
ON Tesoreria.Persona_CuentaBancaria
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Si se actualizó el cbu_cvu, regeneramos el encriptado
    IF UPDATE(cbu_cvu)
    BEGIN
        UPDATE CB
        SET 
            CB.cbu_cvu_encriptado = ENCRYPTBYPASSPHRASE('Grupo14_SecretKey_2025', I.cbu_cvu)
        FROM Tesoreria.Persona_CuentaBancaria CB
        INNER JOIN inserted I ON CB.id_persona_cuenta = I.id_persona_cuenta;
    END
END
GO

PRINT 'Trigger trg_CuentaBancaria_Seguridad creado/actualizado.';
GO