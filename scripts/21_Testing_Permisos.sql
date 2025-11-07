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
Descripción: Script de pruebas de bloqueos de permisos
*/

USE [Com5600_Grupo14_DB];
GO

/*
-- Comprobamos columnas cifradas 
SELECT TOP 10
    id_persona_cuenta,
    cbu_cvu,        -- valor original
    CVU_CBU_enc     -- valor cifrado
FROM Tesoreria.Persona_CuentaBancaria 
WHERE CVU_CBU_enc IS NOT NULL;



--  cifra los datos existentes en cbu_cvu
OPEN SYMMETRIC KEY SK_DatosSensibles_TP
DECRYPTION BY CERTIFICATE Cert_DatosSensibles_TP;

UPDATE t
SET CVU_CBU_enc = EncryptByKey(Key_GUID('SK_DatosSensibles_TP'),
                               CONVERT(NVARCHAR(200), t.cbu_cvu))
FROM Tesoreria.Persona_CuentaBancaria AS t
WHERE t.cbu_cvu IS NOT NULL
  AND (t.CVU_CBU_enc IS NULL OR DATALENGTH(t.CVU_CBU_enc) = 0);

CLOSE SYMMETRIC KEY SK_DatosSensibles_TP;
GO


----

EXEC Reportes.SP_DatosSensibles_Leer;


SELECT TOP 5 * FROM Reportes.VW_Pago_Seguro;
SELECT TOP 5 * FROM Reportes.VW_PCB_Segura;

--borrar usuario
DROP USER test_op;
DROP LOGIN test_op;
GO


-- Crear usuario de prueba y asignarle rol
CREATE LOGIN test_op WITH PASSWORD = 'Test123!';
CREATE USER test_op FOR LOGIN test_op;
ALTER ROLE AdministrativoOperativo ADD MEMBER test_op;

-- probar acceso
EXECUTE AS USER = 'test_op';
SELECT TOP 5 * FROM Tesoreria.Persona_CuentaBancaria;  --  debería tirar error
SELECT TOP 5 * FROM Reportes.VW_PCB_Segura;            --  debería funcionar
REVERT;


--debe dar error si no tiene permisos
USE msdb;
GO
SELECT name, enabled, date_created, description
FROM dbo.sysjobs
WHERE name LIKE 'TP-Backup%';

*/

