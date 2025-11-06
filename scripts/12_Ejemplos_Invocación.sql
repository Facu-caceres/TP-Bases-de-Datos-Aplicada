USE [Com5600_Grupo14_DB];
GO

-- Reporte 1 
EXEC Reportes.sp_reporte_flujo_caja_semanal
  @FechaDesde='2025-01-01', @FechaHasta='2025-03-31',
  @IdConsorcio=NULL, @EstadoPago=NULL, @ModoAsignacion='Proporcional';

-- Reporte 2 
EXEC Reportes.sp_reporte_recaudacion_mes_depto
  @FechaDesde='2025-01-01', @FechaHasta='2025-03-31',
  @IdConsorcio=1, @EstadoPago='Asociado', @FormatoMes='YYYY-MM';

-- Reporte 3 
EXEC Reportes.sp_reporte_recaudacion_tipo_periodo
  @FechaDesde='2025-01-01', @FechaHasta='2025-03-31',
  @IdConsorcio=NULL, @EstadoPago=NULL, @FormatoPeriodo='YYYY-MM', @ModoAsignacion='Proporcional';


-- Reporte 4 
EXEC Reportes.sp_reporte_top5_gastos_ingresos
  @FechaDesde='2024-01-01', @FechaHasta='2025-12-31',
  @IdConsorcio=NULL, @EstadoPago=NULL, @FormatoPeriodo='YYYY-MM';

-- Reporte 5 
EXEC Reportes.sp_reporte_top_morosidad_propietarios
  @FechaCorte='2025-06-30', @IdConsorcio=NULL, @IncluirExtra=0, @MesesFiltroCSV=NULL, @TopN=3;

-- Reporte 6 
EXEC Reportes.sp_reporte_pagos_intervalo_por_uf
  @FechaDesde='2025-01-01', @FechaHasta='2025-06-30',
  @IdConsorcio=2, @EstadoPago='Asociado',
  @FormatoPeriodo='YYYY-MM', @SoloOrdinariasAsumidas=1, @Salida='TABLA';
-- ===================== EJEMPLOS XML ====================

-- Reporte 1 XML
EXEC Reportes.SP_FlujoCajaSemanal_XML
  @FechaDesde='2025-01-01', @FechaHasta='2025-03-31',
  @IdConsorcio=NULL, @ModoAsignacion='Proporcional';

-- Reporte 3 XML 
EXEC Reportes.SP_RecaudacionPorProcedencia_XML
  @FechaDesde='2025-01-01', @FechaHasta='2025-03-31',
  @IdConsorcio=1, @FormatoPeriodo='YYYY-MM', @ModoAsignacion='Proporcional';
