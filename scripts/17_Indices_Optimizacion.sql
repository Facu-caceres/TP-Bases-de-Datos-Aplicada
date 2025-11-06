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
Descripción: Creación de índices para optimizar filtros y JOINS en los SP de Reportes  
*/

USE [Com5600_Grupo14_DB];
GO

-- Índices sobre Tesoreria.Pago (Usados en Reportes 1, 2, 3, 6)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pago_Fecha' AND object_id = OBJECT_ID('Tesoreria.Pago'))
BEGIN
    DROP INDEX IX_Pago_Fecha ON Tesoreria.Pago;
END
CREATE NONCLUSTERED INDEX IX_Pago_Fecha
ON Tesoreria.Pago (fecha_de_pago, id_pago)
INCLUDE (Importe, cbu_origen, id_persona_cuenta, estado);
GO

-- Índices sobre Propiedades.UnidadFuncional (Usados en Reportes 1, 2, 5, 6)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UF_Consorcio_Depto' AND object_id = OBJECT_ID('Propiedades.UnidadFuncional'))
BEGIN
    DROP INDEX IX_UF_Consorcio_Depto ON Propiedades.UnidadFuncional;
END
CREATE NONCLUSTERED INDEX IX_UF_Consorcio_Depto
ON Propiedades.UnidadFuncional (id_consorcio, departamento)
INCLUDE (piso, numero, porcentaje_de_prorrateo);
GO

-- Índices sobre General.Expensa_Consorcio (Usados en Reportes 1, 3, 4, 5)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Expensa_Consorcio_Periodo' AND object_id = OBJECT_ID('General.Expensa_Consorcio'))
BEGIN
    DROP INDEX IX_Expensa_Consorcio_Periodo ON General.Expensa_Consorcio;
END
CREATE NONCLUSTERED INDEX IX_Expensa_Consorcio_Periodo
ON General.Expensa_Consorcio (id_consorcio, periodo)
INCLUDE (total_ordinarios, total_extraordinarios);
GO

-- Índices sobre General.Gasto (Usado en Reporte 4)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Gasto_Expensa_Importe' AND object_id = OBJECT_ID('General.Gasto'))
BEGIN
    DROP INDEX IX_Gasto_Expensa_Importe ON General.Gasto;
END
CREATE NONCLUSTERED INDEX IX_Gasto_Expensa_Importe
ON General.Gasto (id_expensa_consorcio)
INCLUDE (importe);
GO

-- Índices sobre Propiedades.Persona (Usado en Reporte 5)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Persona_Apellido_Nombre' AND object_id = OBJECT_ID('Propiedades.Persona'))
BEGIN
    DROP INDEX IX_Persona_Apellido_Nombre ON Propiedades.Persona;
END
CREATE NONCLUSTERED INDEX IX_Persona_Apellido_Nombre
ON Propiedades.Persona (es_inquilino, apellido, nombre)
INCLUDE (dni, email, telefono);
GO

-- Índices sobre Tesoreria.Persona_CuentaBancaria (Usados en Reportes 1, 2, 5, 6)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PersonaCuenta_IdPersona' AND object_id = OBJECT_ID('Tesoreria.Persona_CuentaBancaria'))
BEGIN
    DROP INDEX IX_PersonaCuenta_IdPersona ON Tesoreria.Persona_CuentaBancaria;
END
CREATE NONCLUSTERED INDEX IX_PersonaCuenta_IdPersona
ON Tesoreria.Persona_CuentaBancaria (id_persona);
GO