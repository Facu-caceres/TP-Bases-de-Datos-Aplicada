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
Descripción: Script de testing para la Entrega 6 (Reportes SPs).
*/

USE [Com5600_Grupo14_DB];
GO

PRINT '--- INICIO SCRIPT DE TESTING DE REPORTES (ENTREGA 6) ---';
GO

PRINT 'Reporte 1: Flujo de caja semanal (Todos) [Salida: TABLA]';
EXEC Reportes.sp_reporte_flujo_caja_semanal
  @FechaDesde='2025-04-01', @FechaHasta='2025-05-31', -- Fechas donde SÍ hay pagos
  @IdConsorcio=NULL, @EstadoPago=NULL, @ModoAsignacion='Proporcional',
  @Salida = 'TABLA';
GO

PRINT 'Reporte 1 (XML): Flujo de caja semanal (Todos) [Salida: XML]';
EXEC Reportes.sp_reporte_flujo_caja_semanal
  @FechaDesde='2025-04-01', @FechaHasta='2025-05-31',
  @IdConsorcio=NULL, @ModoAsignacion='Proporcional',
  @Salida = 'XML';
GO

PRINT 'Reporte 2: Recaudación por mes y depto (Consorcio 1)';
EXEC Reportes.sp_reporte_recaudacion_mes_depto
  @FechaDesde='2025-04-01', @FechaHasta='2025-05-31',
  @IdConsorcio=1, @EstadoPago='Asociado', @FormatoMes='YYYY-MM';
GO

PRINT 'Reporte 3: Recaudación por tipo/período (Todos, MesES) [Salida: TABLA]';
EXEC Reportes.sp_reporte_recaudacion_tipo_periodo
  @FechaDesde='2025-04-01', @FechaHasta='2025-05-31',
  @IdConsorcio=NULL, @EstadoPago=NULL, @FormatoPeriodo='MesES', @ModoAsignacion='Proporcional',
  @Salida = 'TABLA';
GO

PRINT 'Reporte 3 (XML): Recaudación por tipo/período (Todos, MesES) [Salida: XML]';
EXEC Reportes.sp_reporte_recaudacion_tipo_periodo
  @FechaDesde='2025-04-01', @FechaHasta='2025-05-31',
  @IdConsorcio=NULL, @EstadoPago=NULL, @FormatoPeriodo='MesES', @ModoAsignacion='Proporcional',
  @Salida = 'XML';
GO

PRINT 'Reporte 4: Top 5 Gastos e Ingresos (Todos)';
EXEC Reportes.sp_reporte_top5_gastos_ingresos
  @FechaDesde='2024-01-01', @FechaHasta='2025-12-31',
  @IdConsorcio=NULL, @EstadoPago=NULL, @FormatoPeriodo='YYYY-MM';
GO

PRINT 'Reporte 5: Top 3 Morosidad (Todos, solo Ordinarias)';
EXEC Reportes.sp_reporte_top_morosidad_propietarios
  @FechaCorte='2025-06-30', @IdConsorcio=NULL, @IncluirExtra=0, @MesesFiltroCSV='abril,mayo,junio', @TopN=3;
GO

PRINT 'Reporte 6: Intervalo de Pagos por UF (Consorcio 2) [Salida: TABLA]';
EXEC Reportes.sp_reporte_pagos_intervalo_por_uf
  @FechaDesde='2025-04-01', @FechaHasta='2025-06-30',
  @IdConsorcio=2, @EstadoPago='Asociado',
  @FormatoPeriodo='YYYY-MM', @SoloOrdinariasAsumidas=1, @Salida='TABLA';
GO

PRINT 'Reporte 6 (XML): Intervalo de Pagos por UF (Consorcio 2) [Salida: XML]';
EXEC Reportes.sp_reporte_pagos_intervalo_por_uf
  @FechaDesde='2025-04-01', @FechaHasta='2025-06-30',
  @IdConsorcio=2, @EstadoPago='Asociado',
  @FormatoPeriodo='YYYY-MM', @SoloOrdinariasAsumidas=1, @Salida='XML';
GO

PRINT '--- FIN SCRIPT DE TESTING (REPORTES) ---';
GO
