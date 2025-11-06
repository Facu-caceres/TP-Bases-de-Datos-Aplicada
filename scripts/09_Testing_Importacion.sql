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
Descripción: Script de testing para la importación de todos los datos (Entrega 5).
             Ejecuta los SPs de importación y verifica los resultados.
*/

USE [Com5600_Grupo14_DB];
GO

PRINT '--- INICIO SCRIPT DE TESTING DE IMPORTACIÓN ---';
GO

PRINT 'Limpiando datos de ejecuciones anteriores...';

DELETE FROM Tesoreria.Pago;
DELETE FROM General.Gasto;
DELETE FROM Propiedades.UF_Persona;
DELETE FROM Tesoreria.Persona_CuentaBancaria;
DELETE FROM General.Expensa_Consorcio;
DELETE FROM Propiedades.UnidadFuncional;
DELETE FROM Propiedades.Persona;
DELETE FROM General.Consorcio;
DELETE FROM General.Proveedor;

PRINT 'Tablas limpiadas.';
GO



-- Modificar estas rutas para que apunten a los archivos en tu PC
DECLARE
    @excelPath   NVARCHAR(4000) = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\datos varios.xlsx',
    @ufPath      NVARCHAR(4000) = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\UF por consorcio.txt',
    @personasCsv NVARCHAR(4000) = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\Inquilino-propietarios-datos.csv',
    @personasUF  NVARCHAR(4000) = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\Inquilino-propietarios-UF.csv',
    @pagos       NVARCHAR(4000) = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\pagos_consorcios.csv',
    @servicios   NVARCHAR(4000) = N'C:\Users\Flor\Desktop\TP-Bases-de-Datos-Aplicada\archivos_origen\Archivos para el TP\Servicios.Servicios.json';



PRINT '--- 2. Importando Consorcios...';
EXEC Importacion.sp_importar_consorcios @ruta_archivo = @excelPath;

-- Test 2.1: Verificar que se cargaron los 5 consorcios
PRINT 'Test 2.1: Verificando carga de Consorcios (Resultado esperado: 5)';
SELECT COUNT(*) AS 'Total_Consorcios_Cargados' FROM General.Consorcio;

PRINT '--- 3. Importando Proveedores...';
EXEC Importacion.sp_importar_proveedores @ruta_archivo = @excelPath;

-- Test 3.1: Verificar que se cargaron los 5 tipos de proveedores
PRINT 'Test 3.1: Verificando carga de Proveedores (Resultado esperado: 5)';
SELECT COUNT(*) AS 'Total_Proveedores_Cargados' FROM General.Proveedor;

PRINT '--- 4. Importando Unidades Funcionales...';
EXEC Importacion.sp_importar_uf @ruta_archivo = @ufPath;

-- Test 4.1: Verificar el total de UFs cargadas
PRINT 'Test 4.1: Verificando total de UFs (Resultado esperado: 135)';
SELECT COUNT(*) AS 'Total_UF_Cargadas' FROM Propiedades.UnidadFuncional;

-- Test 4.2: Verificar requisito de consigna (UF con cochera y baulera)
PRINT 'Test 4.2: Verificando UF "Azcuenaga" nro 1 (Esperado: tiene_baulera=1, tiene_cochera=1)';
SELECT 
    c.nombre, 
    uf.numero, 
    uf.tiene_baulera, 
    uf.tiene_cochera 
FROM Propiedades.UnidadFuncional uf
JOIN General.Consorcio c ON uf.id_consorcio = c.id_consorcio
WHERE c.nombre = 'Azcuenaga' AND uf.numero = 1;

PRINT '--- 5. Importando Personas y Cuentas Bancarias...';
EXEC Importacion.sp_importar_personas @ruta_archivo = @personasCsv;

-- Test 5.1: Verificar requisito de consigna (Manejo de DNI duplicado)
-- El DNI 29364139 aparece duplicado en el CSV. 
-- El SP debe cargar solo al primero (GRISEK) y reportar el error por el segundo (VELIZ).
PRINT 'Test 5.1: Verificando manejo de DNI duplicado 29364139 (Esperado: 1 fila, "GRISEK")';
SELECT * FROM Propiedades.Persona WHERE dni = 29364139;

-- Test 5.2: Verificar totales de personas y cuentas (deben coincidir)
PRINT 'Test 5.2: Verificando totales de Personas y Cuentas (Esperado: 131 personas, 131 cuentas)';
SELECT COUNT(*) AS 'Total_Personas' FROM Propiedades.Persona;
SELECT COUNT(*) AS 'Total_Cuentas_Bancarias' FROM Tesoreria.Persona_CuentaBancaria;

PRINT '--- 6. Importando relaciones Persona-UF...';
EXEC Importacion.sp_importar_uf_persona @ruta_archivo = @personasUF;

-- Test 6.1: Verificar total de relaciones creadas
PRINT 'Test 6.1: Verificando total de relaciones UF-Persona (Resultado esperado: 131)';
SELECT COUNT(*) AS 'Total_Relaciones_UF_Persona' FROM Propiedades.UF_Persona;

PRINT '--- 7. Importando Pagos...';
EXEC Importacion.sp_importar_pagos @ruta_archivo = @pagos;

-- Test 7.1: Verificar requisito de consigna (Pagos No Asociados)
-- El SP debe marcar como 'No Asociado' cualquier pago cuyo CBU no
-- exista en la tabla Tesoreria.Persona_CuentaBancaria.
PRINT 'Test 7.1: Verificando Pagos NO Asociados (Resultado esperado: > 0)';
SELECT COUNT(*) AS 'Total_Pagos_No_Asociados' 
FROM Tesoreria.Pago 
WHERE estado = 'No Asociado';

PRINT 'Test 7.2: Verificando Pagos Asociados (Resultado esperado: > 0)';
SELECT COUNT(*) AS 'Total_Pagos_Asociados' 
FROM Tesoreria.Pago 
WHERE estado = 'Asociado';

PRINT '--- 8. Importando Servicios (JSON)...';
EXEC Importacion.sp_importar_servicios_json @ruta_archivo = @servicios;

-- Test 8.1: Verificar creación de Expensas
-- El JSON contiene 3 meses para 5 consorcios (3 * 5 = 15).
PRINT 'Test 8.1: Verificando Expensas creadas desde el JSON (Resultado esperado: 15)';
SELECT COUNT(DISTINCT id_expensa_consorcio) AS 'Total_Expensas_JSON'
FROM General.Gasto g
WHERE g.id_expensa_consorcio IS NOT NULL; 

-- Test 8.2: Verificar carga de un Gasto específico
PRINT 'Test 8.2: Verificando gasto "BANCARIOS" de "Azcuenaga" en "abril" (Esperado: 22648.59)';
SELECT g.importe
FROM General.Gasto g
JOIN General.Expensa_Consorcio ec ON g.id_expensa_consorcio = ec.id_expensa_consorcio
JOIN General.Consorcio c ON ec.id_consorcio = c.id_consorcio
WHERE c.nombre = 'Azcuenaga' 
  AND ec.periodo = 'abril' 
  AND g.categoria = 'BANCARIOS';

PRINT '--- 9. Resumen de datos cargados:';
SELECT (SELECT COUNT(*) FROM General.Consorcio) AS Consorcios;
SELECT (SELECT COUNT(*) FROM General.Proveedor) AS Proveedores;
SELECT (SELECT COUNT(*) FROM Propiedades.UnidadFuncional) AS UFs;
SELECT (SELECT COUNT(*) FROM Propiedades.Persona) AS Personas;
SELECT (SELECT COUNT(*) FROM Tesoreria.Persona_CuentaBancaria) AS Cuentas;
SELECT (SELECT COUNT(*) FROM Propiedades.UF_Persona) AS Relaciones_UF_Persona;
SELECT (SELECT COUNT(*) FROM Tesoreria.Pago) AS Pagos;
SELECT (SELECT COUNT(*) FROM General.Gasto) AS Gastos_Servicios;
GO

PRINT '--- FIN SCRIPT DE TESTING ---';
GO