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
Fecha de Entrega: 07/11/2025
Descripción: Script de testing para la generacion de Expensas.
             Si se le envia el parametro @NombreConsorcio lo hace para ese en especifico,
             Si no se le envia el parametro o esta en NULL, genera la expensa para todos los consorcios en ese mes.

*/

USE [Com5600G14];
GO

--Consulta para ver los meses en los que hay datos cargados:
SELECT DISTINCT periodo
FROM General.Expensa_Consorcio

-- Ejemplo 1: Para un consorcio específico en el mes de Septiembre
EXEC Liquidacion.sp_generar_detalle_expensas
    @NombreConsorcio = 'Azcuenaga',
    @MesNombre = 'septiembre',
    @Fecha1erVencimiento = '2025-09-10',
    @Fecha2doVencimiento = '2025-09-20';

-- Ejemplo 2: Para TODOS los consorcios en Septiembre
EXEC Liquidacion.sp_generar_detalle_expensas
    @MesNombre = 'septiembre',
    @Fecha1erVencimiento = '2025-09-10',
    @Fecha2doVencimiento = '2025-09-20';
--El consorcio Pereyra Iraola no esta incluido en el lote de prueba completo, por lo que sus campos salen en NULL fuera de los meses Abril, Mayo y Junio.


--Ejemplo 3: Para un consorcio específico en el mes de Abril
EXEC Liquidacion.sp_generar_detalle_expensas
    @NombreConsorcio = 'Unzue',
    @MesNombre = 'abril',
    @Fecha1erVencimiento = '2025-04-10',
    @Fecha2doVencimiento = '2025-04-20';
