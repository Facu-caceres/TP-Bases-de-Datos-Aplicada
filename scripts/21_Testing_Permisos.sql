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


USE [Com5600_Grupo14_DB];
GO
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA='Tesoreria' AND TABLE_NAME LIKE 'Persona_Cuenta%';

-- ¿Vistas enmascaradas responden?
SELECT TOP 3 * FROM Reportes.VW_PCB_Segura;
SELECT TOP 3 * FROM Reportes.VW_Pago_Seguro;
SELECT TOP 3 * FROM Reportes.VW_Persona_Segura;

-- ¿Tabla sensible existe y tiene cifrado?
SELECT TOP 3 id_persona_cuenta, CVU_CBU_enc
FROM Tesoreria.[<poné_el_nombre_exactamente_como_salida_en_el_query_de_arriba>]
WHERE CVU_CBU_enc IS NOT NULL;


USE [Com5600_Grupo14_DB];
GO
-- Limpieza segura
IF USER_ID('test_op') IS NOT NULL
BEGIN
  IF IS_ROLEMEMBER('AdministrativoOperativo','test_op') = 1
    ALTER ROLE AdministrativoOperativo DROP MEMBER test_op;
  DROP USER test_op;
END
GO

-- Crear usuario contenido (SIN login de servidor)
CREATE USER test_op WITHOUT LOGIN;
ALTER ROLE AdministrativoOperativo ADD MEMBER test_op;

-- Impersonar dentro de la base y probar
EXECUTE AS USER = 'test_op';
  -- Debe FALLAR: tabla sensible
  SELECT TOP 1 * FROM Tesoreria.[<nombre_exact>];
  -- Debe FUNCIONAR: vista enmascarada
  SELECT TOP 1 * FROM Reportes.VW_PCB_Segura;
REVERT;

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

