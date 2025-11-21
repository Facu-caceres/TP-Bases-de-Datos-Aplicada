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
             2. Visibilidad de datos en Reportes según Rol.
*/

USE [Com5600_Grupo14_DB];
GO

PRINT '--- INICIO TESTING DE HASHING ---';
GO

--------------------------------------------------------------------------
-- TEST 1: INTEGRIDAD DE DATOS Y TRIGGERS
--------------------------------------------------------------------------
PRINT '>>> TEST 1: Verificando Triggers de Inserción (Todos los campos sensibles)...';

BEGIN TRANSACTION;

    -- 1. Insertar Persona 
    INSERT INTO Propiedades.Persona (nombre, apellido, dni, email, telefono, es_inquilino)
    VALUES ('Usuario', 'TestHash', 11223344, 'hash@test.com', 155556666, 0);

    DECLARE @id_persona_test INT = SCOPE_IDENTITY();

    -- 2. Insertar Cuenta 
    INSERT INTO Tesoreria.Persona_CuentaBancaria (id_persona, cbu_cvu, alias, activa)
    VALUES (@id_persona_test, '0000000000000000000111', 'ALIAS.HASH.TEST', 1);

    PRINT '   Inserción realizada. Consultando datos...';

    -- 3. Verificar Persona (DNI, Email, Telefono)
    SELECT 
        'Persona' AS Tabla,
        dni AS [Original_DNI],
        dni_hash AS [Hash_DNI],
        email AS [Original_Email],
        email_hash AS [Hash_Email],
        telefono AS [Original_Tel],
        telefono_hash AS [Hash_Tel]
    FROM Propiedades.Persona 
    WHERE id_persona = @id_persona_test;

    -- 4. Verificar Cuenta (CBU)
    SELECT 
        'Cuenta' AS Tabla,
        cbu_cvu AS [Original_CBU],
        cbu_hash AS [Hash_CBU] -- Debería estar lleno con 32 bytes
    FROM Tesoreria.Persona_CuentaBancaria
    WHERE id_persona = @id_persona_test;

ROLLBACK TRANSACTION;
PRINT '>>> TEST 1 FINALIZADO.';
PRINT '';
GO

--------------------------------------------------------------------------
-- TEST 2: REPORTE MOROSIDAD
--------------------------------------------------------------------------


PRINT '>>> TEST 2: Verificando Reporte con Hashing Completo...';

PRINT '--- Ejecutando como [usr_adm_general] (Ve Hashes de DNI/Email/Tel) ---';
EXECUTE AS USER = 'usr_adm_general';
    EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte = '2025-12-31', @TopN = 10;
REVERT;



PRINT '';
PRINT '--- Ejecutando como [usr_adm_operativo] (Ve Texto Plano) ---';
EXECUTE AS USER = 'usr_adm_operativo';
    EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte = '2025-12-31', @TopN = 10;
REVERT;
GO

PRINT '--- FIN SCRIPT DE TESTING ---';
GO