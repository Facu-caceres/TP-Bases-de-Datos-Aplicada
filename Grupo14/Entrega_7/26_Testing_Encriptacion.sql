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
Descripción: Verifica el cifrado simétrico (EncryptByPassPhrase).
             1. Comprueba que los datos en disco sean binarios (VARBINARY).
             2. Prueba el desencriptado manual con la frase de paso.
             3. Prueba el Reporte de Morosidad con un usuario AUTORIZADO (debe ver datos).
*/


USE [Com5600G14];
GO

PRINT '===========================================================================';
PRINT '                 TESTING DE ENCRIPTACIÓN SIMÉTRICA';
PRINT '===========================================================================';
GO

-----------------------------------------------------------------------------------
-- TEST 1: VERIFICACIÓN DE ALMACENAMIENTO CIFRADO EN TABLAS
-----------------------------------------------------------------------------------

PRINT '';
PRINT '>>> TEST 1: Verificando almacenamiento físico (Debe ser ilegible/binario)...';

-- Consultamos directamente la tabla. No deberíamos ver texto plano.

SELECT TOP 3 * FROM Propiedades.Persona;

PRINT 'Resultado esperado: Columnas "_hash" muestran valores que comienzan con 0x...';
GO

-----------------------------------------------------------------------------------
-- TEST 2: VERIFICACIÓN DE DESENCRIPTADO MANUAL
-----------------------------------------------------------------------------------

PRINT '';
PRINT '>>> TEST 2: Verificando recuperación de datos con la Frase de Paso...';

DECLARE @PassPhrase NVARCHAR(128) = 'Grupo14_Secreto_2025';

SELECT TOP 3
    id_persona,
    nombre,
    apellido,
    es_inquilino,
    -- Convertimos el binario desencriptado a varchar para leerlo
    CAST(DecryptByPassPhrase(@PassPhrase, dni_hash) AS VARCHAR(50)) AS [DNI_Recuperado],
    CAST(DecryptByPassPhrase(@PassPhrase, email_hash) AS VARCHAR(100)) AS [Email_Recuperado],
    CAST(DecryptByPassPhrase(@PassPhrase, telefono_hash) AS VARCHAR(50)) AS [Tel_Recuperado]
FROM Propiedades.Persona
WHERE dni_hash IS NOT NULL;

PRINT 'Resultado esperado: Datos legibles recuperados correctamente.';
GO

-----------------------------------------------------------------------------------
-- TEST 3: REPORTE DE MOROSIDAD - USUARIO AUTORIZADO (Ej: Adm. General)
-----------------------------------------------------------------------------------
PRINT '';
PRINT '>>> TEST 3: Ejecución de Reporte como [usr_adm_general] (TIENE PERMISOS)...';

EXECUTE AS USER = 'usr_adm_general';
    
    -- Al tener rol 'Rol_AdmGeneral', el SP debe desencriptar los datos.
    EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte = '2025-12-31';

REVERT;
PRINT 'Resultado esperado: Columnas DNI, Email y Teléfono muestran TEXTO PLANO.';
GO

EXEC Reportes.sp_reporte_top_morosidad_propietarios
        @FechaCorte = '2025-12-31';


PRINT '===========================================================================';
PRINT '                 FIN DEL TESTING DE ENCRIPTACIÓN';
PRINT '===========================================================================';