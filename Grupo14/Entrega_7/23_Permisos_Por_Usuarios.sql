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
Descripción: Entrega 7 - Seguridad
             Creación de logins, roles y permisos según grilla:
             - Ningún rol puede crear bases de datos.
             - Ningún rol puede crear/alterar/borrar tablas.
             - Ningún rol puede hacer INSERT/UPDATE/DELETE directo
               (la carga es solo por Excel vía stored procedures).
             - Matriz de permisos:
                  * Actualizar datos UF: AdmGeneral, AdmOperativo
                  * Importación bancaria: AdmBancario
                  * Generar reportes: AdmGeneral, AdmOperativo,
                                     AdmBancario y Sistemas.
             Script idempotente.
*/

------------------------------------------------------------
-- 1. CREACIÓN DE LOGINS (NIVEL SERVIDOR) - IDÓMPOTENTE
------------------------------------------------------------
USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_adm_general')
    CREATE LOGIN usr_adm_general WITH PASSWORD = '123456789';
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_adm_bancario')
    CREATE LOGIN usr_adm_bancario WITH PASSWORD = '123456789';
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_adm_operativo')
    CREATE LOGIN usr_adm_operativo WITH PASSWORD = '123456789';
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_sistemas')
    CREATE LOGIN usr_sistemas WITH PASSWORD = '123456789';
GO

-- Ninguno de estos logins puede crear bases de datos
DENY CREATE ANY DATABASE TO usr_adm_general;
DENY CREATE ANY DATABASE TO usr_adm_bancario;
DENY CREATE ANY DATABASE TO usr_adm_operativo;
DENY CREATE ANY DATABASE TO usr_sistemas;
GO


------------------------------------------------------------
-- 2. CONTEXTO DE BASE DE DATOS
------------------------------------------------------------
USE [Com5600G14];
GO


------------------------------------------------------------
-- 3. CREACIÓN DE ROLES (BASE DE DATOS) - IDÓMPOTENTE
------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals
    WHERE name = 'Rol_AdmGeneral' AND type = 'R'
)
    CREATE ROLE Rol_AdmGeneral;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals
    WHERE name = 'Rol_AdmBancario' AND type = 'R'
)
    CREATE ROLE Rol_AdmBancario;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals
    WHERE name = 'Rol_AdmOperativo' AND type = 'R'
)
    CREATE ROLE Rol_AdmOperativo;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals
    WHERE name = 'Rol_Sistemas' AND type = 'R'
)
    CREATE ROLE Rol_Sistemas;
GO


------------------------------------------------------------
-- 4. CREACIÓN DE USUARIOS (BASE DE DATOS) - IDÓMPOTENTE
------------------------------------------------------------

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals WHERE name = 'usr_adm_general'
)
    CREATE USER usr_adm_general FOR LOGIN usr_adm_general;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals WHERE name = 'usr_adm_bancario'
)
    CREATE USER usr_adm_bancario FOR LOGIN usr_adm_bancario;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals WHERE name = 'usr_adm_operativo'
)
    CREATE USER usr_adm_operativo FOR LOGIN usr_adm_operativo;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals WHERE name = 'usr_sistemas'
)
    CREATE USER usr_sistemas FOR LOGIN usr_sistemas;
GO


------------------------------------------------------------
-- 5. ASIGNACIÓN DE USUARIOS A ROLES - IDÓMPOTENTE
------------------------------------------------------------

-- usr_adm_general -> Rol_AdmGeneral
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
    JOIN sys.database_principals u ON drm.member_principal_id = u.principal_id
    WHERE r.name = 'Rol_AdmGeneral'
      AND u.name = 'usr_adm_general'
)
    ALTER ROLE Rol_AdmGeneral ADD MEMBER usr_adm_general;
GO

-- usr_adm_bancario -> Rol_AdmBancario
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
    JOIN sys.database_principals u ON drm.member_principal_id = u.principal_id
    WHERE r.name = 'Rol_AdmBancario'
      AND u.name = 'usr_adm_bancario'
)
    ALTER ROLE Rol_AdmBancario ADD MEMBER usr_adm_bancario;
GO

-- usr_adm_operativo -> Rol_AdmOperativo
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
    JOIN sys.database_principals u ON drm.member_principal_id = u.principal_id
    WHERE r.name = 'Rol_AdmOperativo'
      AND u.name = 'usr_adm_operativo'
)
    ALTER ROLE Rol_AdmOperativo ADD MEMBER usr_adm_operativo;
GO

-- usr_sistemas -> Rol_Sistemas
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
    JOIN sys.database_principals u ON drm.member_principal_id = u.principal_id
    WHERE r.name = 'Rol_Sistemas'
      AND u.name = 'usr_sistemas'
)
    ALTER ROLE Rol_Sistemas ADD MEMBER usr_sistemas;
GO


------------------------------------------------------------
-- 6. LIMPIAR PERMISOS DE PUBLIC
------------------------------------------------------------

REVOKE EXECUTE ON SCHEMA::Importacion FROM public;
REVOKE EXECUTE ON SCHEMA::Reportes   FROM public;
GO


------------------------------------------------------------
-- 7. PERMISOS FUNCIONALES SEGÚN GRILLA
------------------------------------------------------------

/*
GRILLA:

- CREAR BASE DE DATOS:        ningún rol (se resolvió con DENY CREATE ANY DATABASE).
- ALTERAR/CREAR/BORRAR TABLAS: ningún rol.
- Carga de datos solo por Excel (SPs de Importacion):
    → Ningún rol hace INSERT/UPDATE/DELETE directo.

- Actualizar datos UF: AdmGeneral, AdmOperativo
- Importación bancaria: AdmBancario
- Generar reportes:     AdmGeneral, AdmOperativo, AdmBancario, Sistemas
*/

------------------------------------------------------------
-- 7.1. ACTUALIZAR DATOS DE UNIDAD FUNCIONAL
--      SP de importación de maestros
--      Roles: AdmGeneral, AdmOperativo
------------------------------------------------------------

GRANT EXECUTE ON OBJECT::Importacion.sp_importar_consorcios      TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_uf              TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_personas        TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_uf_persona      TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_proveedores     TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_servicios_json  TO Rol_AdmGeneral;

GRANT EXECUTE ON OBJECT::Importacion.sp_importar_consorcios      TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_uf              TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_personas        TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_uf_persona      TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_proveedores     TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Importacion.sp_importar_servicios_json  TO Rol_AdmOperativo;
GO


------------------------------------------------------------
-- 7.2. IMPORTACIÓN DE INFORMACIÓN BANCARIA
--      Rol: solo AdmBancario
------------------------------------------------------------

GRANT EXECUTE ON OBJECT::Importacion.sp_importar_pagos                 TO Rol_AdmBancario;
GRANT EXECUTE ON OBJECT::Importacion.sp_actualizar_cotizaciones_dolar  TO Rol_AdmBancario;
GO

------------------------------------------------------------
-- 7.3. REPORTES (TODOS LOS ROLES)
------------------------------------------------------------

-- AdmGeneral
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_flujo_caja_semanal         TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_recaudacion_mes_depto      TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_recaudacion_tipo_periodo   TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_top5_gastos_ingresos       TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_top_morosidad_propietarios TO Rol_AdmGeneral;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_pagos_intervalo_por_uf     TO Rol_AdmGeneral;

-- AdmOperativo
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_flujo_caja_semanal         TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_recaudacion_mes_depto      TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_recaudacion_tipo_periodo   TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_top5_gastos_ingresos       TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_top_morosidad_propietarios TO Rol_AdmOperativo;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_pagos_intervalo_por_uf     TO Rol_AdmOperativo;

-- AdmBancario
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_flujo_caja_semanal         TO Rol_AdmBancario;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_recaudacion_mes_depto      TO Rol_AdmBancario;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_recaudacion_tipo_periodo   TO Rol_AdmBancario;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_top5_gastos_ingresos       TO Rol_AdmBancario;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_top_morosidad_propietarios TO Rol_AdmBancario;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_pagos_intervalo_por_uf     TO Rol_AdmBancario;

-- Sistemas
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_flujo_caja_semanal         TO Rol_Sistemas;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_recaudacion_mes_depto      TO Rol_Sistemas;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_recaudacion_tipo_periodo   TO Rol_Sistemas;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_top5_gastos_ingresos       TO Rol_Sistemas;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_top_morosidad_propietarios TO Rol_Sistemas;
GRANT EXECUTE ON OBJECT::Reportes.sp_reporte_pagos_intervalo_por_uf     TO Rol_Sistemas;
GO


------------------------------------------------------------
-- 8. BLOQUEOS EXPLÍCITOS (DENY) PARA RESPETAR MATRIZ
------------------------------------------------------------

-- AdmBancario NO puede actualizar UF
DENY EXECUTE ON OBJECT::Importacion.sp_importar_consorcios     TO Rol_AdmBancario;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_uf             TO Rol_AdmBancario;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_personas       TO Rol_AdmBancario;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_uf_persona     TO Rol_AdmBancario;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_proveedores    TO Rol_AdmBancario;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_servicios_json TO Rol_AdmBancario;

-- Sistemas NO puede actualizar UF ni importar bancaria
DENY EXECUTE ON OBJECT::Importacion.sp_importar_consorcios            TO Rol_Sistemas;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_uf                    TO Rol_Sistemas;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_personas              TO Rol_Sistemas;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_uf_persona            TO Rol_Sistemas;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_proveedores           TO Rol_Sistemas;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_servicios_json        TO Rol_Sistemas;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_pagos                 TO Rol_Sistemas;
DENY EXECUTE ON OBJECT::Importacion.sp_actualizar_cotizaciones_dolar  TO Rol_Sistemas;

-- AdmGeneral y AdmOperativo NO pueden hacer importación bancaria
DENY EXECUTE ON OBJECT::Importacion.sp_importar_pagos                 TO Rol_AdmGeneral;
DENY EXECUTE ON OBJECT::Importacion.sp_actualizar_cotizaciones_dolar  TO Rol_AdmGeneral;
DENY EXECUTE ON OBJECT::Importacion.sp_importar_pagos                 TO Rol_AdmOperativo;
DENY EXECUTE ON OBJECT::Importacion.sp_actualizar_cotizaciones_dolar  TO Rol_AdmOperativo;
GO


------------------------------------------------------------
-- 9. BLOQUEO DML/DDL DIRECTO (NINGÚN ROL MODIFICA TABLAS)
------------------------------------------------------------

-- 9.1. Denegar INSERT/UPDATE/DELETE y ALTER en los esquemas de negocio

DECLARE @schemaName SYSNAME;

DECLARE curSchemas CURSOR FOR
    SELECT name
    FROM sys.schemas
    WHERE name IN ('General','Propiedades','Tesoreria','Importacion','Reportes');

OPEN curSchemas;
FETCH NEXT FROM curSchemas INTO @schemaName;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC('DENY INSERT, UPDATE, DELETE ON SCHEMA::[' + @schemaName + '] TO Rol_AdmGeneral;');
    EXEC('DENY INSERT, UPDATE, DELETE ON SCHEMA::[' + @schemaName + '] TO Rol_AdmBancario;');
    EXEC('DENY INSERT, UPDATE, DELETE ON SCHEMA::[' + @schemaName + '] TO Rol_AdmOperativo;');
    EXEC('DENY INSERT, UPDATE, DELETE ON SCHEMA::[' + @schemaName + '] TO Rol_Sistemas;');

    EXEC('DENY ALTER ON SCHEMA::[' + @schemaName + '] TO Rol_AdmGeneral;');
    EXEC('DENY ALTER ON SCHEMA::[' + @schemaName + '] TO Rol_AdmBancario;');
    EXEC('DENY ALTER ON SCHEMA::[' + @schemaName + '] TO Rol_AdmOperativo;');
    EXEC('DENY ALTER ON SCHEMA::[' + @schemaName + '] TO Rol_Sistemas;');

    FETCH NEXT FROM curSchemas INTO @schemaName;
END

CLOSE curSchemas;
DEALLOCATE curSchemas;
GO

-- 9.2. Denegar creación de objetos (CREATE TABLE/VIEW/FUNCTION/PROCEDURE) en la base

DENY CREATE TABLE, CREATE VIEW, CREATE FUNCTION, CREATE PROCEDURE, ALTER ANY SCHEMA
    TO Rol_AdmGeneral;
DENY CREATE TABLE, CREATE VIEW, CREATE FUNCTION, CREATE PROCEDURE, ALTER ANY SCHEMA
    TO Rol_AdmBancario;
DENY CREATE TABLE, CREATE VIEW, CREATE FUNCTION, CREATE PROCEDURE, ALTER ANY SCHEMA
    TO Rol_AdmOperativo;
DENY CREATE TABLE, CREATE VIEW, CREATE FUNCTION, CREATE PROCEDURE, ALTER ANY SCHEMA
    TO Rol_Sistemas;
GO