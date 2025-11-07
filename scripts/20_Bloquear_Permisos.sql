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
Descripción: Script de bloqueo de permisos
*/
USE [Com5600_Grupo14_DB];
GO


IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='Reportes') EXEC('CREATE SCHEMA Reportes');
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='AdministrativoGeneral')
    CREATE ROLE [AdministrativoGeneral];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='AdministrativoBancario')
    CREATE ROLE [AdministrativoBancario];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='AdministrativoOperativo')
    CREATE ROLE [AdministrativoOperativo];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='Sistemas')
    CREATE ROLE [Sistemas];
GO

-- Permisos por esquema (ajustá si tu modelo difiere)
-- Propiedades.* (datos UF)
GRANT SELECT ON SCHEMA::[Propiedades] TO [AdministrativoGeneral], [AdministrativoOperativo];
GRANT UPDATE ON SCHEMA::[Propiedades] TO [AdministrativoGeneral], [AdministrativoOperativo];
DENY  UPDATE ON SCHEMA::[Propiedades] TO [AdministrativoBancario];  -- NO
DENY  UPDATE ON SCHEMA::[Propiedades] TO [Sistemas];                 -- NO (técnico)

-- Tesoreria.* (importación bancaria)
GRANT SELECT, INSERT, UPDATE ON SCHEMA::[Tesoreria] TO [AdministrativoBancario]; -- SÍ
DENY  INSERT, UPDATE ON SCHEMA::[Tesoreria] TO [AdministrativoGeneral], [AdministrativoOperativo];
-- Sistemas con permisos técnicos (no de negocio)
GRANT VIEW DEFINITION ON SCHEMA::[Tesoreria] TO [Sistemas];

-- Reportes.* (consultas/vistas/procs de reporting)
GRANT SELECT ON SCHEMA::[Reportes] TO [AdministrativoGeneral], [AdministrativoBancario], [AdministrativoOperativo], [Sistemas];
GRANT EXECUTE ON SCHEMA::[Reportes] TO [Sistemas]; -- ejecución técnica de SPs de reporte
GO


/* ============== 2) CIFRADO de datos sensibles ============== */


-- 2.1 Master Key / Certificado / Symmetric Key
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name='##MS_DatabaseMasterKey##')
BEGIN
  CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Usar_Una_Pass_Fuerte_y_Guardada_Seguro_!2025';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name='Cert_DatosSensibles_TP')
BEGIN
  CREATE CERTIFICATE Cert_DatosSensibles_TP
    WITH SUBJECT = 'Certificado cifrado datos sensibles (TP)';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name='SK_DatosSensibles_TP')
BEGIN
  CREATE SYMMETRIC KEY SK_DatosSensibles_TP
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE Cert_DatosSensibles_TP;
END
GO

/* 2.2 Agregar columnas cifradas si faltan */

-- Tesoreria.Persona_CuentaBancaria: CVU/CBU
IF OBJECT_ID('Tesoreria.Persona_CuentaBancaria') IS NOT NULL
BEGIN
  IF COL_LENGTH('Tesoreria.Persona_CuentaBancaria','CVU_CBU_enc') IS NULL
  BEGIN
    ALTER TABLE Tesoreria.Persona_CuentaBancaria
      ADD CVU_CBU_enc VARBINARY(256) NULL;
  END
END
GO

-- Tesoreria.Pago: cbu_origen (por tu script previo)
IF OBJECT_ID('Tesoreria.Pago') IS NOT NULL
BEGIN
  IF COL_LENGTH('Tesoreria.Pago','cbu_origen_enc') IS NULL
  BEGIN
    ALTER TABLE Tesoreria.Pago
      ADD cbu_origen_enc VARBINARY(256) NULL;
  END
END
GO



/* 2.3 Migración plaintext -> cifrado */
OPEN SYMMETRIC KEY SK_DatosSensibles_TP DECRYPTION BY CERTIFICATE Cert_DatosSensibles_TP;

-- PCB: CVU/CBU -> CVU_CBU_enc
IF OBJECT_ID('Tesoreria.Persona_CuentaBancaria') IS NOT NULL
  AND COL_LENGTH('Tesoreria.Persona_CuentaBancaria','CVU_CBU') IS NOT NULL
BEGIN
  UPDATE t
  SET CVU_CBU_enc = EncryptByKey(Key_GUID('SK_DatosSensibles_TP'), CONVERT(NVARCHAR(200), t.cbu_cvu))
  FROM Tesoreria.Persona_CuentaBancaria t
  WHERE t.cbu_cvu IS NOT NULL AND(t.cbu_cvu IS NULL OR DATALENGTH(t.cbu_cvu)=0);
END

-- Pago: cbu_origen -> cbu_origen_enc
IF OBJECT_ID('Tesoreria.Pago') IS NOT NULL
  AND COL_LENGTH('Tesoreria.Pago','cbu_origen') IS NOT NULL
BEGIN
  UPDATE p
  SET cbu_origen = EncryptByKey(Key_GUID('SK_DatosSensibles_TP'), CONVERT(NVARCHAR(50), p.cbu_origen))
  FROM Tesoreria.Pago p
  WHERE p.cbu_origen IS NOT NULL AND (p.cbu_origen IS NULL OR DATALENGTH(p.cbu_origen)=0);
END

-- Persona: dni/email/telefono -> *_enc
IF OBJECT_ID('Propiedades.Persona') IS NOT NULL
BEGIN
  IF COL_LENGTH('Propiedades.Persona','dni_enc') IS NULL
  BEGIN
    ALTER TABLE Propiedades.Persona ADD dni_enc VARBINARY(256) NULL;
  END
  IF COL_LENGTH('Propiedades.Persona','email_enc') IS NULL
  BEGIN
    ALTER TABLE Propiedades.Persona ADD email_enc VARBINARY(512) NULL;
  END
  IF COL_LENGTH('Propiedades.Persona','telefono_enc') IS NULL
  BEGIN
    ALTER TABLE Propiedades.Persona ADD telefono_enc VARBINARY(256) NULL;
  END
END
GO


/* 2.4 Endurecer acceso: DENY plaintext a roles de negocio.
       Lectura vía vistas enmascaradas; descifrado controlado solo Sistemas. */

-- DENY lectura directa de tablas con datos sensibles
IF OBJECT_ID('Tesoreria.Persona_CuentaBancaria') IS NOT NULL
BEGIN
  DENY SELECT ON OBJECT::Tesoreria.Persona_CuentaBancaria TO [AdministrativoGeneral], [AdministrativoBancario], [AdministrativoOperativo];
  GRANT SELECT ON OBJECT::Tesoreria.Persona_CuentaBancaria TO [Sistemas];
END
IF OBJECT_ID('Tesoreria.Pago') IS NOT NULL
BEGIN
  DENY SELECT ON OBJECT::Tesoreria.Pago TO [AdministrativoGeneral], [AdministrativoBancario], [AdministrativoOperativo];
  GRANT SELECT ON OBJECT::Tesoreria.Pago TO [Sistemas];
END
IF OBJECT_ID('Propiedades.Persona') IS NOT NULL
BEGIN
  DENY SELECT ON OBJECT::Propiedades.Persona TO [AdministrativoGeneral], [AdministrativoBancario], [AdministrativoOperativo];
  GRANT SELECT ON OBJECT::Propiedades.Persona TO [Sistemas];
END
GO

-- Función helper para descifrar (solo útil con symmetric key abierta en el contexto)
CREATE OR ALTER FUNCTION Reportes.fn_descifrar(@dato VARBINARY(8000))
RETURNS NVARCHAR(4000) WITH SCHEMABINDING
AS
BEGIN
  RETURN TRY_CONVERT(NVARCHAR(4000), DecryptByKey(@dato));
END
GO
GRANT EXECUTE ON OBJECT::Reportes.fn_descifrar TO [Sistemas];

-- Vistas enmascaradas para negocio ( solo muestran máscara)
IF OBJECT_ID('Reportes.VW_PCB_Segura') IS NOT NULL DROP VIEW Reportes.VW_PCB_Segura;
GO
CREATE VIEW Reportes.VW_PCB_Segura AS
SELECT 
  id_persona_cuenta,
  id_persona,
  CASE WHEN DATALENGTH(CVU_CBU_enc) > 0 THEN '****-****-****' ELSE NULL END AS CVU_CBU_mask
FROM Tesoreria.Persona_CuentaBancaria;
GO
GRANT SELECT ON OBJECT::Reportes.VW_PCB_Segura TO [AdministrativoGeneral], [AdministrativoBancario], [AdministrativoOperativo], [Sistemas];

IF OBJECT_ID('Reportes.VW_Pago_Seguro') IS NOT NULL DROP VIEW Reportes.VW_Pago_Seguro;
GO
CREATE VIEW Reportes.VW_Pago_Seguro AS
SELECT 
  id_pago, fecha_de_pago, importe, estado,
  CASE WHEN DATALENGTH(cbu_origen_enc) > 0 THEN '************' ELSE NULL END AS cbu_origen_mask,
  id_persona_cuenta
FROM Tesoreria.Pago;
GO
GRANT SELECT ON OBJECT::Reportes.VW_Pago_Seguro TO [AdministrativoGeneral], [AdministrativoBancario], [AdministrativoOperativo], [Sistemas];

IF OBJECT_ID('Propiedades.Persona') IS NOT NULL
BEGIN
  IF OBJECT_ID('Reportes.VW_Persona_Segura') IS NOT NULL DROP VIEW Reportes.VW_Persona_Segura;
  EXEC('CREATE VIEW Reportes.VW_Persona_Segura AS
        SELECT id_persona,
               CASE WHEN DATALENGTH(dni_enc)>0 THEN ''***-****'' ELSE NULL END AS dni_mask,
               CASE WHEN DATALENGTH(email_enc)>0 THEN ''***@***''  ELSE NULL END AS email_mask,
               CASE WHEN DATALENGTH(telefono_enc)>0 THEN ''*****''  ELSE NULL END AS telefono_mask
        FROM Propiedades.Persona;');
  GRANT SELECT ON OBJECT::Reportes.VW_Persona_Segura TO [AdministrativoGeneral], [AdministrativoBancario], [AdministrativoOperativo], [Sistemas];
END
GO

-- Proc técnico para lectura descifrada 
CREATE OR ALTER PROC Reportes.SP_DatosSensibles_Leer
AS
BEGIN
  SET NOCOUNT ON;
  OPEN SYMMETRIC KEY SK_DatosSensibles_TP DECRYPTION BY CERTIFICATE Cert_DatosSensibles_TP;

  -- Ejemplos 
  IF OBJECT_ID('Tesoreria.Pago') IS NOT NULL AND COL_LENGTH('Tesoreria.Pago','cbu_origen_enc') IS NOT NULL
  BEGIN
    SELECT id_pago, fecha_de_pago, importe, estado,
           Reportes.fn_descifrar(cbu_origen_enc) AS cbu_origen,
           id_persona_cuenta
    FROM Tesoreria.Pago;
  END

  IF OBJECT_ID('Tesoreria.Persona_CuentaBancaria') IS NOT NULL AND COL_LENGTH('Tesoreria.Persona_CuentaBancaria','CVU_CBU_enc') IS NOT NULL
  BEGIN
    SELECT id_persona_cuenta, id_persona,
           Reportes.fn_descifrar(CVU_CBU_enc) AS CVU_CBU
    FROM Tesoreria.Persona_CuentaBancaria;
  END

  IF OBJECT_ID('Propiedades.Persona') IS NOT NULL
  BEGIN
    SELECT id_persona,
           Reportes.fn_descifrar(dni_enc)      AS dni,
           Reportes.fn_descifrar(email_enc)    AS email,
           Reportes.fn_descifrar(telefono_enc) AS telefono
    FROM Propiedades.Persona;
  END

  CLOSE SYMMETRIC KEY SK_DatosSensibles_TP;
END
GO
GRANT EXECUTE ON OBJECT::Reportes.SP_DatosSensibles_Leer TO [Sistemas];


/* ============== 3) BACKUPS + SCHEDULE + RPO ============== */

DECLARE @dirFull NVARCHAR(260) = 'C:\Backups\Com5600_Grupo14_DB\FULL\';
DECLARE @dirDiff NVARCHAR(260) = 'C:\Backups\Com5600_Grupo14_DB\DIFF\';
DECLARE @dirLog  NVARCHAR(260) = 'C:\Backups\Com5600_Grupo14_DB\LOG\';

-- FULL diario
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name='TP-Backup-Full-Diario')
BEGIN
  EXEC msdb.dbo.sp_add_job
    @job_name = N'TP-Backup-Full-Diario',
    @enabled  = 1,
    @description = N'Full diario Com5600_Grupo14_DB';

  EXEC msdb.dbo.sp_add_jobstep
    @job_name  = N'TP-Backup-Full-Diario',
    @step_name = N'BACKUP FULL',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command  = N'
      DECLARE @dir nvarchar(260) = N''C:\Backups\Com5600_Grupo14_DB\FULL\'';
      DECLARE @file nvarchar(4000) = @dir + CONVERT(varchar(8), GETDATE(),112) + N''_full.bak'';
      BACKUP DATABASE [Com5600_Grupo14_DB]
        TO DISK = @file
        WITH INIT, COMPRESSION, CHECKSUM;
    ';

  EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'TP-Full-02am',
    @freq_type = 4,                 -- diario
    @freq_interval = 1,
    @active_start_time = 020000;    -- 02:00

  EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'TP-Backup-Full-Diario',
    @schedule_name = N'TP-Full-02am';

  EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'TP-Backup-Full-Diario';
END
GO

-- Diferenciales cada 6 horas
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name='TP-Backup-Diff-6h')
BEGIN
  EXEC msdb.dbo.sp_add_job
    @job_name = N'TP-Backup-Diff-6h',
    @enabled  = 1,
    @description = N'Diferencial cada 6 horas';

  EXEC msdb.dbo.sp_add_jobstep
    @job_name  = N'TP-Backup-Diff-6h',
    @step_name = N'BACKUP DIFF',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command  = N'
      DECLARE @dir nvarchar(260) = N''C:\Backups\Com5600_Grupo14_DB\DIFF\'';
      DECLARE @file nvarchar(4000) = @dir + REPLACE(CONVERT(varchar(19), GETDATE(),120), '':'', ''-'') + N''_diff.bak'';
      BACKUP DATABASE [Com5600_Grupo14_DB]
        TO DISK = @file
        WITH DIFFERENTIAL, COMPRESSION, CHECKSUM;
    ';

  EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'TP-Diff-6h',
    @freq_type = 4,                 -- diario
    @freq_interval = 1,
    @freq_subday_type = 8,          -- cada N horas
    @freq_subday_interval = 6,      -- 6 horas
    @active_start_time = 000000;

  EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'TP-Backup-Diff-6h',
    @schedule_name = N'TP-Diff-6h';

  EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'TP-Backup-Diff-6h';
END
GO

-- Log cada 15 minutos (RPO <= 15m)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name='TP-Backup-Log-15m')
BEGIN
  EXEC msdb.dbo.sp_add_job
    @job_name = N'TP-Backup-Log-15m',
    @enabled  = 1,
    @description = N'Backup de Log cada 15 min';

  EXEC msdb.dbo.sp_add_jobstep
    @job_name  = N'TP-Backup-Log-15m',
    @step_name = N'BACKUP LOG',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command  = N'
      DECLARE @dir nvarchar(260) = N''C:\Backups\Com5600_Grupo14_DB\LOG\'';
      DECLARE @file nvarchar(4000) = @dir + REPLACE(CONVERT(varchar(19), GETDATE(),120), '':'', ''-'') + N''_log.trn'';
      BACKUP LOG [Com5600_Grupo14_DB]
        TO DISK = @file
        WITH COMPRESSION, CHECKSUM;
    ';

  EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'TP-Log-15m',
    @freq_type = 4,                  -- diario
    @freq_interval = 1,
    @freq_subday_type = 4,           -- cada N minutos
    @freq_subday_interval = 15,      -- 15 minutos
    @active_start_time = 000000;

  EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'TP-Backup-Log-15m',
    @schedule_name = N'TP-Log-15m';

  EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'TP-Backup-Log-15m';
END
GO




