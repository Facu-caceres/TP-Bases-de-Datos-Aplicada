/* Índices sugeridos para acelerar los reportes.
   Ajustá nombres de tablas/columnas si difieren en tu esquema. */

-- Pagos: filtros por FechaPago, IdUF y agrupaciones por TipoPago
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Pago_Fecha_Tipo_IdUF' AND object_id=OBJECT_ID('dbo.Pago'))
CREATE INDEX IX_Pago_Fecha_Tipo_IdUF ON dbo.Pago (FechaPago, TipoPago, IdUF) INCLUDE (Importe);

-- UF por Consorcio
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_UF_Consorcio' AND object_id=OBJECT_ID('dbo.UnidadFuncional'))
CREATE INDEX IX_UF_Consorcio ON dbo.UnidadFuncional (IdConsorcio, Piso, Depto);

-- Gasto por Fecha
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Gasto_Fecha' AND object_id=OBJECT_ID('dbo.Gasto'))
CREATE INDEX IX_Gasto_Fecha ON dbo.Gasto (FechaGasto) INCLUDE (Importe);

-- Expensa por PeriodoYm y IdUF
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Expensa_Periodo_IdUF' AND object_id=OBJECT_ID('dbo.Expensa'))
CREATE INDEX IX_Expensa_Periodo_IdUF ON dbo.Expensa (PeriodoYm, IdUF) INCLUDE (Importe);

-- Relación PropietarioUF
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PropietarioUF_IdUF' AND object_id=OBJECT_ID('dbo.PropietarioUF'))
CREATE INDEX IX_PropietarioUF_IdUF ON dbo.PropietarioUF (IdUF);



/*INDICES NO CLUSTER MAS ESPECIFICOS CON INCLUDE (COBERTURA)*/


/*  PAGOS (consultas por fechas, UF, consorcio)  */
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Pago_Fecha_UF' AND object_id=OBJECT_ID('dbo.Pago'))
CREATE NONCLUSTERED INDEX IX_Pago_Fecha_UF
ON dbo.Pago (FechaPago, IdUF)
INCLUDE (Importe, TipoPago, Medio);

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Pago_UF_Fecha' AND object_id=OBJECT_ID('dbo.Pago'))
CREATE NONCLUSTERED INDEX IX_Pago_UF_Fecha
ON dbo.Pago (IdUF, FechaPago)
INCLUDE (Importe, TipoPago);

/* EXPENSAS (por UF, Periodo y estado)  */
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Expensa_UF_Periodo' AND object_id=OBJECT_ID('dbo.Expensa'))
CREATE NONCLUSTERED INDEX IX_Expensa_UF_Periodo
ON dbo.Expensa (IdUF, Periodo)
INCLUDE (Monto, Estado, FechaVencimiento);

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Expensa_Impaga_Periodo' AND object_id=OBJECT_ID('dbo.Expensa'))
CREATE NONCLUSTERED INDEX IX_Expensa_Impaga_Periodo
ON dbo.Expensa (Periodo)
INCLUDE (IdUF, Monto, FechaVencimiento)
WHERE Estado IN ('Impaga','Vencida');   -- índice filtrado para deuda

/* GASTOS (reportes por consorcio, rubro y fecha) */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Gasto_Consorcio_Fecha' AND object_id=OBJECT_ID('dbo.Gasto'))
CREATE NONCLUSTERED INDEX IX_Gasto_Consorcio_Fecha
ON dbo.Gasto (IdConsorcio, Fecha)
INCLUDE (Rubro, Importe, EsExtraordinario);

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Gasto_Consorcio_Rubro_Fecha' AND object_id=OBJECT_ID('dbo.Gasto'))
CREATE NONCLUSTERED INDEX IX_Gasto_Consorcio_Rubro_Fecha
ON dbo.Gasto (IdConsorcio, Rubro, Fecha)
INCLUDE (Importe, EsExtraordinario);

/* MOVIMIENTOS DE CAJA (ingresos/egresos por período) */
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Caja_Consorcio_Fecha' AND object_id=OBJECT_ID('dbo.MovimientoCaja'))
CREATE NONCLUSTERED INDEX IX_Caja_Consorcio_Fecha
ON dbo.MovimientoCaja (IdConsorcio, Fecha)
INCLUDE (Tipo, Monto, Origen);

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Caja_Consorcio_Ingreso' AND object_id=OBJECT_ID('dbo.MovimientoCaja'))
CREATE NONCLUSTERED INDEX IX_Caja_Consorcio_Ingreso
ON dbo.MovimientoCaja (IdConsorcio, Fecha)
INCLUDE (Monto, Origen)
WHERE Tipo = 'Ingreso';  -- filtrado

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Caja_Consorcio_Egreso' AND object_id=OBJECT_ID('dbo.MovimientoCaja'))
CREATE NONCLUSTERED INDEX IX_Caja_Consorcio_Egreso
ON dbo.MovimientoCaja (IdConsorcio, Fecha)
INCLUDE (Monto, Origen)
WHERE Tipo = 'Egreso';   -- filtrado

/* PERSONAS (búsquedas por DNI, apellido y nombre)  */
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_Persona_DNI' AND object_id=OBJECT_ID('dbo.Persona'))
CREATE UNIQUE NONCLUSTERED INDEX UX_Persona_DNI
ON dbo.Persona (DNI);

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Persona_Apellido_Nombre' AND object_id=OBJECT_ID('dbo.Persona'))
CREATE NONCLUSTERED INDEX IX_Persona_Apellido_Nombre
ON dbo.Persona (Apellido, Nombre)
INCLUDE (Email);

/*  COMPROBANTES (pendientes por consorcio en rango de fechas)*/
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Comprobante_Consorcio_Fecha' AND object_id=OBJECT_ID('dbo.Comprobante'))
CREATE NONCLUSTERED INDEX IX_Comprobante_Consorcio_Fecha
ON dbo.Comprobante (IdConsorcio, Fecha)
INCLUDE (Estado, Tipo, Total);

--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Comprobante_Pendiente' AND object_id=OBJECT_ID('dbo.Comprobante'))
CREATE NONCLUSTERED INDEX IX_Comprobante_Pendiente
ON dbo.Comprobante (IdConsorcio, Fecha)
INCLUDE (Tipo, Total)
WHERE Estado = 'Pendiente';  -- filtrado

/*  RECLAMOS (consorcio/estado, ordenado por fecha)  */
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Reclamo_Consorcio_Estado_Fecha' AND object_id=OBJECT_ID('dbo.Reclamo'))
CREATE NONCLUSTERED INDEX IX_Reclamo_Consorcio_Estado_Fecha
ON dbo.Reclamo (IdConsorcio, Estado, Fecha)
INCLUDE (IdUF, Prioridad);

/*  MOVIMIENTOS BANCARIOS  (consorcio/fecha)  */
--IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Banco_Consorcio_Fecha' AND object_id=OBJECT_ID('dbo.BancoMovimiento'))
CREATE NONCLUSTERED INDEX IX_Banco_Consorcio_Fecha
ON dbo.BancoMovimiento (IdConsorcio, Fecha)
INCLUDE (CBU, Monto);
