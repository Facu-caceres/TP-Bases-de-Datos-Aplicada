/* Índices sugeridos para acelerar los reportes.
   Ajustá nombres de tablas/columnas si difieren en tu esquema. */

-- Pagos: filtros por FechaPago, IdUF y agrupaciones por TipoPago
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Pago_Fecha_Tipo_IdUF' AND object_id=OBJECT_ID('dbo.Pago'))
CREATE INDEX IX_Pago_Fecha_Tipo_IdUF ON dbo.Pago (FechaPago, TipoPago, IdUF) INCLUDE (Importe);

-- UF por Consorcio
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_UF_Consorcio' AND object_id=OBJECT_ID('dbo.UnidadFuncional'))
CREATE INDEX IX_UF_Consorcio ON dbo.UnidadFuncional (IdConsorcio, Piso, Depto);

-- Gasto por Fecha
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Gasto_Fecha' AND object_id=OBJECT_ID('dbo.Gasto'))
CREATE INDEX IX_Gasto_Fecha ON dbo.Gasto (FechaGasto) INCLUDE (Importe);

-- Expensa por PeriodoYm y IdUF
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Expensa_Periodo_IdUF' AND object_id=OBJECT_ID('dbo.Expensa'))
CREATE INDEX IX_Expensa_Periodo_IdUF ON dbo.Expensa (PeriodoYm, IdUF) INCLUDE (Importe);

-- Relación PropietarioUF
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PropietarioUF_IdUF' AND object_id=OBJECT_ID('dbo.PropietarioUF'))
CREATE INDEX IX_PropietarioUF_IdUF ON dbo.PropietarioUF (IdUF);
