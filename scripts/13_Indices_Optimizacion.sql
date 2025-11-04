USE [Com5600_Grupo14_DB];
GO



/* Índices sugeridos para acelerar los reportes.
   Ajustá nombres de tablas/columnas si difieren en tu esquema. */

-- Pagos: filtros por FechaPago, Id_pago y agrupaciones por importe
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Pago_Fecha_Tipo_IdUF' AND object_id=OBJECT_ID('dbo.Pago'))
CREATE INDEX IX_Pago_Fecha_Tipo_IdUF ON Tesoreria.Pago (fecha_de_pago, importe, id_pago); 
-- UF por Consorcio
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_UF_Consorcio' AND object_id=OBJECT_ID('dbo.UnidadFuncional'))
CREATE INDEX IX_UF_Consorcio ON Propiedades.UnidadFuncional (id_consorcio, piso, departamento);

-- Gasto por importe
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Gasto_Fecha' AND object_id=OBJECT_ID('dbo.Gasto'))
CREATE INDEX IX_Gasto_Importe ON General.Gasto (importe) INCLUDE (descripcion);

-- Expensa por PeriodoYm y IdUF
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Expensa_Periodo_IdUF' AND object_id=OBJECT_ID('dbo.Expensa'))
CREATE INDEX IX_Expensa_Periodo_IdUF ON General.Expensa_Consorcio (periodo, id_expensa_consorcio);
-- Relación PropietarioUF
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PropietarioUF_IdUF' AND object_id=OBJECT_ID('dbo.PropietarioUF'))
CREATE INDEX IX_PropietarioUF_IdUF ON Propiedades.UF_Persona (id_uf_persona);



/*INDICES NO CLUSTER MAS ESPECIFICOS CON INCLUDE (COBERTURA)*/

--si ya existen, los elimino--

DROP INDEX IX_UF_Consorcio_IdUF ON Propiedades.UnidadFuncional;

DROP INDEX IX_Pago_Fecha ON Tesoreria.Pago;

DROP INDEX IX_Expensa_UF_Periodo ON General.Expensa_Consorcio;

DROP INDEX IX_Expensa_Impaga_Periodo ON General.Expensa_Consorcio;

DROP INDEX IX_Gasto_Consorcio_Fecha ON General.Gasto;

DROP INDEX IX_Gasto_Consorcio_Rubro_Fecha ON General.Gasto;

DROP INDEX IX_Persona_Apellido_Nombre ON Propiedades.Persona;



/*  PAGOS (consultas por fechas, UF, consorcio)  */
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Pago_Fecha_UF' AND object_id=OBJECT_ID('dbo.Pago'))
CREATE NONCLUSTERED INDEX IX_Pago_Fecha
ON Tesoreria.Pago (fecha_de_pago, id_pago )
INCLUDE (Importe, cbu_origen);

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Pago_UF_Fecha' AND object_id=OBJECT_ID('dbo.Pago'))
CREATE NONCLUSTERED INDEX IX_Pago_UF_Fecha
ON Tesoreria.Pago (id_pago, fecha_de_pago)
INCLUDE (Importe);

/* EXPENSAS (por idconsorcio, Periodo y vtos)  */
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Expensa_UF_Periodo' AND object_id=OBJECT_ID('dbo.Expensa'))
CREATE NONCLUSTERED INDEX IX_Expensa_UF_Periodo
ON General.Expensa_Consorcio (id_consorcio, Periodo)
INCLUDE (vto_1, vto_2, fecha_emision);

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Expensa_Impaga_Periodo' AND object_id=OBJECT_ID('dbo.Expensa'))
CREATE NONCLUSTERED INDEX IX_Expensa_Impaga_Periodo
ON General.Expensa_Consorcio (Periodo)
INCLUDE (total_ordinarios, total_extraordinarios, fecha_Emision)

/* GASTOS (reportes por consorcio, categoria y tipo) */
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Gasto_Consorcio_Fecha' AND object_id=OBJECT_ID('dbo.Gasto'))
CREATE NONCLUSTERED INDEX IX_Gasto_Consorcio_Fecha
ON General.Gasto (id_expensa_consorcio, tipo)
INCLUDE (categoria, Importe, descripcion);

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Gasto_Consorcio_Rubro_Fecha' AND object_id=OBJECT_ID('dbo.Gasto'))
CREATE NONCLUSTERED INDEX IX_Gasto_Consorcio_Rubro_Fecha
ON General.Gasto (id_expensa_consorcio, categoria, nro_factura);


/* PERSONAS (búsquedas por DNI, apellido y nombre)  */

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Persona_Apellido_Nombre' AND object_id=OBJECT_ID('dbo.Persona'))
CREATE NONCLUSTERED INDEX IX_Persona_Apellido_Nombre
ON Propiedades.Persona (apellido, nombre)
INCLUDE (email);


