/* Ejemplos de uso */
-- Reporte 1
EXEC REP.SP_FlujoCajaSemanal @FechaDesde='2025-01-01', @FechaHasta='2025-03-31', @IdConsorcio=NULL;

-- Reporte 2
EXEC REP.SP_RecaudacionPorMesDepto @PeriodoDesdeYM='202501', @PeriodoHastaYM='202503', @IdConsorcio=1;

-- Reporte 3
EXEC REP.SP_RecaudacionPorProcedencia @PeriodoDesdeYM='202501', @PeriodoHastaYM='202503', @IdConsorcio=NULL;

-- Reporte 4
EXEC REP.SP_TopMeses_GastosIngresos @AnioDesde=2024, @AnioHasta=2025, @IdConsorcio=NULL;

-- Reporte 5
EXEC REP.SP_TopPropietarios_Morosidad @PeriodoDesdeYM='202501', @PeriodoHastaYM='202506', @IdConsorcio=NULL;

-- Reporte 6
EXEC REP.SP_DiasEntrePagos_Ordinarios @PeriodoDesde='2025-01-01', @PeriodoHasta='2025-06-30', @IdConsorcio=2;

-- XML
EXEC REP.SP_FlujoCajaSemanal_XML '2025-01-01','2025-03-31',NULL;
EXEC REP.SP_RecaudacionPorProcedencia_XML '202501','202503',1;
