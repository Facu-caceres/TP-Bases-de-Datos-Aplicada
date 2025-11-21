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
Descripción: Script de Testing para la Entrega 7 (Cifrado y Seguridad).
             Verifica:
             1. Funcionamiento de Triggers (Auto-hashing).
             2. Funcionamiento de Encriptación simétrica (CBU).
             3. Visibilidad de datos en Reportes según Rol.
*/

USE [Com5600_Grupo14_DB];
GO

PRINT '--- INICIO TESTING DE ENCRIPTACIÓN Y HASHING ---';
GO

--------------------------------------------------------------------------
-- TEST 1: INTEGRIDAD DE DATOS Y TRIGGERS
-- Insertamos una persona y cuenta "dummy" para ver si el Trigger calcula los hashes
--------------------------------------------------------------------------
PRINT '>>> TEST 1: Verificando Triggers de Inserción...';

BEGIN TRANSACTION;

    -- 1. Insertar Persona (sin pasar los hash, el trigger debe calcularlos)
    INSERT INTO Propiedades.Persona (nombre, apellido, dni, email, telefono, es_inquilino)
    VALUES ('Usuario', 'TestSeguridad', 99999999, 'test@seguridad.com', 11111111, 0);

    DECLARE @id_persona_test INT = SCOPE_IDENTITY();

    -- 2. Insertar Cuenta (sin pasar el encriptado)
    INSERT INTO Tesoreria.Persona_CuentaBancaria (id_persona, cbu_cvu, alias, activa)
    VALUES (@id_persona_test, '0000000000000000000999', 'ALIAS.TEST.SEGURIDAD', 1);

    PRINT '   Inserción realizada. Consultando datos crudos en tabla...';

    -- 3. Verificar qué se guardó
    SELECT 
        apellido, 
        dni, 
        dni_hash AS [DNI_Hash_Generado_Por_Trigger],
        email,
        email_hash AS [Email_Hash_Generado_Por_Trigger]
    FROM Propiedades.Persona 
    WHERE id_persona = @id_persona_test;

    SELECT 
        cbu_cvu AS [CBU_Original],
        cbu_cvu_encriptado AS [CBU_Encriptado_En_Base],
        -- Intentamos desencriptar para validar que sea reversible
        CONVERT(VARCHAR(100), DECRYPTBYPASSPHRASE('Grupo14_SecretKey_2025', cbu_cvu_encriptado)) AS [CBU_Desencriptado_Test]
    FROM Tesoreria.Persona_CuentaBancaria
    WHERE id_persona = @id_persona_test;

ROLLBACK TRANSACTION; -- Deshacemos para no ensuciar la base
PRINT '>>> TEST 1 FINALIZADO (Transacción revertida).';
PRINT '';
GO

--------------------------------------------------------------------------
-- TEST 2: VISIBILIDAD EN REPORTES SEGÚN ROL
-- El Reporte 14 debe mostrar HASH para AdmGeneral y TEXTO PLANO para Operativo
--------------------------------------------------------------------------
PRINT '>>> TEST 2: Verificando Visibilidad en Reporte de Morosidad...';

-- A) Usuario Restringido (AdmGeneral o Sistemas) -> DEBE VER HASH
PRINT '--- Ejecutando como [usr_adm_general] (Debe ver HASH) ---';
EXECUTE AS USER = 'usr_adm_general';

    EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte     = '2025-12-31',
        @IdConsorcio    = NULL,
        @TopN           = 10;

REVERT;
PRINT '';

-- B) Usuario Operativo (AdmOperativo) -> DEBE VER DATOS REALES
PRINT '--- Ejecutando como [usr_adm_operativo] (Debe ver DATOS REALES) ---';
EXECUTE AS USER = 'usr_adm_operativo';
    
    EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte     = '2025-12-31',
        @IdConsorcio    = NULL,
        @TopN           = 10;

REVERT;
GO

PRINT '--- FIN SCRIPT DE TESTING ---';
GO