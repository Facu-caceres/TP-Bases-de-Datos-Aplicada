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
Fecha de Entrega: 21/11/2025*/


USE [Com5600G14];
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'Liquidacion')
	EXEC('CREATE SCHEMA [Liquidacion]');
GO

CREATE OR ALTER PROCEDURE Liquidacion.sp_generar_detalle_expensas
    @NombreConsorcio      VARCHAR(100) = NULL, -- NULL para todos
    @MesNombre            VARCHAR(20),         -- Ej: 'abril'
    @Fecha1erVencimiento  DATE,
    @Fecha2doVencimiento  DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Configuración de Fechas
    DECLARE @Anio INT = YEAR(@Fecha1erVencimiento);
    DECLARE @MesAnalisis VARCHAR(20) = LOWER(LTRIM(RTRIM(@MesNombre)));
    
    DECLARE @MesInt INT = CASE @MesAnalisis
        WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3
        WHEN 'abril' THEN 4 WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6
        WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 WHEN 'septiembre' THEN 9
        WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
        ELSE 0
    END;

    IF @MesInt = 0 BEGIN
        RAISERROR('Mes inválido. Use nombre en español (ej: abril).', 16, 1); RETURN;
    END

    DECLARE @FechaInicioMesActual DATE = DATEFROMPARTS(@Anio, @MesInt, 1);
    
    -- CTEs de Cálculo
    ;WITH ConsorciosScope AS (
        SELECT id_consorcio, nombre, m2_totales 
        FROM General.Consorcio
        WHERE (@NombreConsorcio IS NULL OR nombre = @NombreConsorcio)
    ),
    -- Totales a distribuir en este mes
    ExpensaActual AS (
        SELECT ec.id_consorcio, 
               ISNULL(ec.total_ordinarios,0) AS total_ordinarios, 
               ISNULL(ec.total_extraordinarios,0) AS total_extraordinarios
        FROM General.Expensa_Consorcio ec
        INNER JOIN ConsorciosScope cs ON ec.id_consorcio = cs.id_consorcio
        WHERE LOWER(LTRIM(RTRIM(ec.periodo))) = @MesAnalisis
    ),
    -- Datos de UF y recálculo de porcentajes según M2 reales
    DatosUF AS (
        SELECT 
            uf.id_uf, uf.id_consorcio, uf.numero, uf.piso, uf.departamento,
            uf.tiene_cochera, uf.tiene_baulera,
            
            -- Superficies individuales
            ISNULL(uf.superficie, 0) AS m2_uf,
            ISNULL(uf.m2_cochera, 0) AS m2_cochera,
            ISNULL(uf.m2_baulera, 0) AS m2_baulera,
            
            -- Porcentaje Recalculado (M2 Totales Propios / M2 Totales Consorcio)
            CAST(
                ((ISNULL(uf.superficie, 0) + ISNULL(uf.m2_cochera, 0) + ISNULL(uf.m2_baulera, 0)) 
                 / NULLIF(cs.m2_totales, 0)) * 100 
            AS DECIMAL(10,2)) AS Porcentaje_Calculado,

            -- Proporciones internas para desglosar el gasto
            ISNULL(uf.superficie, 0) / NULLIF(cs.m2_totales, 0) AS Ratio_UF,
            ISNULL(uf.m2_cochera, 0) / NULLIF(cs.m2_totales, 0) AS Ratio_Cochera,
            ISNULL(uf.m2_baulera, 0) / NULLIF(cs.m2_totales, 0) AS Ratio_Baulera

        FROM Propiedades.UnidadFuncional uf
        INNER JOIN ConsorciosScope cs ON uf.id_consorcio = cs.id_consorcio
    ),
    Propietario AS (
        SELECT uf.id_uf, p.nombre, p.apellido,
            ROW_NUMBER() OVER (PARTITION BY uf.id_uf ORDER BY p.id_persona ASC) as rn
        FROM Propiedades.UF_Persona ufp
        INNER JOIN Propiedades.Persona p ON ufp.id_persona = p.id_persona
        INNER JOIN Propiedades.UnidadFuncional uf ON ufp.id_uf = uf.id_uf
    ),
    -- Saldo Histórico
    Historial AS (
        SELECT d.id_uf,
            (ISNULL((SELECT SUM(ISNULL(ec_hist.total_ordinarios,0) + ISNULL(ec_hist.total_extraordinarios,0)) 
                    FROM General.Expensa_Consorcio ec_hist
                    WHERE ec_hist.id_consorcio = d.id_consorcio
                      AND CASE LOWER(LTRIM(RTRIM(ec_hist.periodo)))
                            WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3 WHEN 'abril' THEN 4 
                            WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6 WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 
                            WHEN 'septiembre' THEN 9 WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
                            ELSE 0 END < @MesInt
                ), 0) * (d.Porcentaje_Calculado / 100.0)) AS TotalGeneradoHistorico,
            
            ISNULL((SELECT SUM(p.importe)
                FROM Tesoreria.Pago p
                INNER JOIN Tesoreria.Persona_CuentaBancaria pcb ON p.id_persona_cuenta = pcb.id_persona_cuenta
                INNER JOIN Propiedades.UF_Persona ufp ON pcb.id_persona = ufp.id_persona
                WHERE ufp.id_uf = d.id_uf AND p.estado = 'Asociado' AND p.fecha_de_pago < @FechaInicioMesActual
            ), 0) AS TotalPagadoHistorico
        FROM DatosUF d
    ),
    -- Pagos del Mes Actual
    PagosDelMes AS (
        SELECT ufp.id_uf, SUM(p.importe) as ImportePagadoMes
        FROM Tesoreria.Pago p
        INNER JOIN Tesoreria.Persona_CuentaBancaria pcb ON p.id_persona_cuenta = pcb.id_persona_cuenta
        INNER JOIN Propiedades.UF_Persona ufp ON pcb.id_persona = ufp.id_persona
        WHERE p.fecha_de_pago >= @FechaInicioMesActual AND p.fecha_de_pago < DATEADD(MONTH, 1, @FechaInicioMesActual)
          AND p.estado = 'Asociado'
        GROUP BY ufp.id_uf
    ),
    -- Cálculo de valores numéricos finales
    CalculosFinales AS (
        SELECT 
            cs.nombre AS NombreConsorcio,
            d.numero,
            d.Porcentaje_Calculado,
            CONCAT(d.piso, '-', d.departamento) AS PisoDepto,
            ISNULL(prop.apellido + ' ' + prop.nombre, 'Sin Propietario') AS PropietarioNombre,
            
            -- Saldos
            (h.TotalGeneradoHistorico - h.TotalPagadoHistorico) AS SaldoAnterior,
            ISNULL(pm.ImportePagadoMes, 0) AS PagosRecibidos,
            
            -- Deuda Remanente
            ((h.TotalGeneradoHistorico - h.TotalPagadoHistorico) - ISNULL(pm.ImportePagadoMes, 0)) AS DeudaNeta,
            
            -- Interés (5% sobre deuda vieja remanente)
            CASE 
                WHEN ((h.TotalGeneradoHistorico - h.TotalPagadoHistorico) - ISNULL(pm.ImportePagadoMes, 0)) > 0 
                THEN ((h.TotalGeneradoHistorico - h.TotalPagadoHistorico) - ISNULL(pm.ImportePagadoMes, 0)) * 0.05
                ELSE 0 
            END AS InteresMora,

            -- Expensas Desglosadas
            (ea.total_ordinarios * d.Ratio_UF) AS ExpOrdinariaPura,
            (ea.total_ordinarios * d.Ratio_Cochera) AS ExpCochera,
            (ea.total_ordinarios * d.Ratio_Baulera) AS ExpBaulera,
            
            -- Extraordinarias
            (ea.total_extraordinarios * (d.Porcentaje_Calculado / 100.0)) AS ExpExtraordinaria

        FROM DatosUF d
        INNER JOIN ConsorciosScope cs ON d.id_consorcio = cs.id_consorcio
        LEFT JOIN ExpensaActual ea ON d.id_consorcio = ea.id_consorcio
        LEFT JOIN Propietario prop ON d.id_uf = prop.id_uf AND prop.rn = 1
        LEFT JOIN Historial h ON d.id_uf = h.id_uf
        LEFT JOIN PagosDelMes pm ON d.id_uf = pm.id_uf
    )

    -- SELECT FINAL CON FORMATO VISUAL AJUSTADO (-)
    SELECT 
        NombreConsorcio AS [Consorcio],
        numero AS [Uf],
        CAST(Porcentaje_Calculado AS DECIMAL(5,2)) AS [%],
        PisoDepto AS [Piso-Depto.],
        PropietarioNombre AS [Propietario],
        
        '$ ' + FORMAT(SaldoAnterior, '#,##0.00', 'es-AR') AS [Saldo anterior],
        '$ ' + FORMAT(PagosRecibidos, '#,##0.00', 'es-AR') AS [Pagos recibidos],
        
        -- Deuda: Muestra '-' si es 0 o negativo (saldo a favor)
        CASE WHEN DeudaNeta > 0 
             THEN '$ ' + FORMAT(DeudaNeta, '#,##0.00', 'es-AR') 
             ELSE '-' 
        END AS [Deuda],
        
        -- Interés: Muestra '-' si es 0
        CASE WHEN InteresMora > 0 
             THEN '$ ' + FORMAT(InteresMora, '#,##0.00', 'es-AR') 
             ELSE '-' 
        END AS [Interés por mora],
        
        '$ ' + FORMAT(ExpOrdinariaPura, '#,##0.00', 'es-AR') AS [expensas ordinarias],
        
        -- Cocheras: Muestra '-' si es 0
        CASE WHEN ExpCochera > 0 
             THEN '$ ' + FORMAT(ExpCochera, '#,##0.00', 'es-AR') 
             ELSE '-' 
        END AS [Cocheras],

        -- Bauleras: Muestra '-' si es 0
        CASE WHEN ExpBaulera > 0 
             THEN '$ ' + FORMAT(ExpBaulera, '#,##0.00', 'es-AR') 
             ELSE '-' 
        END AS [Bauleras],
        
        '$ ' + FORMAT(ExpExtraordinaria, '#,##0.00', 'es-AR') AS [expensas extraordinarias],
        
        -- Total Final
        '$ ' + FORMAT(
            (DeudaNeta + InteresMora + ExpOrdinariaPura + ExpCochera + ExpBaulera + ExpExtraordinaria), 
            '#,##0.00', 'es-AR'
        ) AS [Total a Pagar]

    FROM CalculosFinales
    ORDER BY NombreConsorcio, numero;

    SET NOCOUNT OFF;
END;
GO

/*
-- Ejemplo 1: Para un consorcio específico
EXEC Liquidacion.sp_generar_detalle_expensas
    @NombreConsorcio = 'Azcuenaga',
    @MesNombre = 'septiembre',
    @Fecha1erVencimiento = '2025-09-10',
    @Fecha2doVencimiento = '2025-09-20';

-- Ejemplo 2: Para TODOS los consorcios
EXEC Liquidacion.sp_generar_detalle_expensas
    @NombreConsorcio = NULL,
    @MesNombre = 'septiembre',
    @Fecha1erVencimiento = '2025-09-10',
    @Fecha2doVencimiento = '2025-09-20';

select * from Propiedades.UnidadFuncional

SELECT DISTINCT periodo
FROM General.Expensa_Consorcio
*/

--prueba gastos extraordinarios separado de gastos ordinarios
/*SELECT 
    c.nombre,
    ec.periodo,
    ec.total_ordinarios,
    ec.total_extraordinarios
FROM General.Expensa_Consorcio ec
JOIN General.Consorcio c ON c.id_consorcio = ec.id_consorcio
WHERE c.nombre = 'Azcuenaga'
  AND LOWER(LTRIM(RTRIM(ec.periodo))) = 'marzo';*/