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

Descripción: Script para la creación de la base de datos, esquemas y tablas del proyecto.
*/

USE master;
GO

IF DB_ID('Com5600_Grupo14_DB') IS NOT NULL
BEGIN
    ALTER DATABASE [Com5600_Grupo14_DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [Com5600_Grupo14_DB];
END
GO

CREATE DATABASE [Com5600_Grupo14_DB];
GO

USE [Com5600_Grupo14_DB];
GO

-- Creación de Esquemas
CREATE SCHEMA General;
GO
CREATE SCHEMA Propiedades;
GO
CREATE SCHEMA Tesoreria;
GO
CREATE SCHEMA Importacion;
GO
CREATE SCHEMA Reportes;
GO

-- Creación de Tablas

-- Esquema: General
CREATE TABLE General.Consorcio (
    id_consorcio INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    direccion VARCHAR(100),
    cant_unidades_funcionales INT,
    m2_totales DECIMAL(10, 2)
);

CREATE TABLE General.Expensa_Consorcio (
    id_expensa_consorcio INT IDENTITY(1,1) PRIMARY KEY,
    id_consorcio INT NOT NULL,
    periodo VARCHAR(20) NOT NULL, 
    fecha_emision DATE,
    vto_1 DATE,
    vto_2 DATE,
    total_ordinarios DECIMAL(18, 2),
    total_extraordinarios DECIMAL(18, 2),
    interes_por_mora DECIMAL(5, 2),
    FOREIGN KEY (id_consorcio) REFERENCES General.Consorcio(id_consorcio)
);

CREATE TABLE General.Gasto (
    id_gasto INT IDENTITY(1,1) PRIMARY KEY,
    id_expensa_consorcio INT NOT NULL,
    tipo VARCHAR(100),
    categoria VARCHAR(100),
    descripcion VARCHAR(255),
    nombre_proveedor VARCHAR(50),
    nro_factura VARCHAR(100),
    importe DECIMAL(18, 2),
    FOREIGN KEY (id_expensa_consorcio) REFERENCES General.Expensa_Consorcio(id_expensa_consorcio)
);

-- Esquema: Propiedades
CREATE TABLE Propiedades.UnidadFuncional (
    id_uf INT IDENTITY(1,1) PRIMARY KEY,
    id_consorcio INT NOT NULL,
    numero INT NOT NULL,
    piso VARCHAR(3),
    departamento CHAR,
    superficie DECIMAL(10, 2),
    porcentaje_de_prorrateo DECIMAL(5, 2),
    tiene_baulera BIT,
    tiene_cochera BIT,
    m2_baulera DECIMAL(10,2),
    m2_cochera DECIMAL(10,2),
    FOREIGN KEY (id_consorcio) REFERENCES General.Consorcio(id_consorcio),
    UNIQUE (id_consorcio, numero)
);

CREATE TABLE Propiedades.Persona (
    id_persona INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50),
    apellido VARCHAR(50),
    dni INT UNIQUE,
    email VARCHAR(255),
    telefono BIGINT,
    es_inquilino BIT
);

CREATE TABLE Propiedades.UF_Persona (
    id_uf_persona INT IDENTITY(1,1) PRIMARY KEY,
    id_uf INT NOT NULL,
    id_persona INT NOT NULL,
    FOREIGN KEY (id_uf) REFERENCES Propiedades.UnidadFuncional(id_uf),
    FOREIGN KEY (id_persona) REFERENCES Propiedades.Persona(id_persona)
);

-- Esquema: Tesoreria
CREATE TABLE Tesoreria.Persona_CuentaBancaria (
    id_persona_cuenta INT IDENTITY(1,1) PRIMARY KEY,
    id_persona INT NOT NULL,
    cbu_cvu VARCHAR(22) NOT NULL UNIQUE,
    alias VARCHAR(100),
    activa BIT DEFAULT 1,
    FOREIGN KEY (id_persona) REFERENCES Propiedades.Persona(id_persona)
);

CREATE TABLE Tesoreria.Pago (
    id_pago INT PRIMARY KEY,
    id_persona_cuenta INT,
    fecha_de_pago DATE,
    importe DECIMAL(18, 2),
    cbu_origen VARCHAR(22),
    estado VARCHAR(50) DEFAULT 'No Asociado',
    FOREIGN KEY (id_persona_cuenta) REFERENCES Tesoreria.Persona_CuentaBancaria(id_persona_cuenta)
);
GO


    CREATE TABLE General.Proveedor (
        id_proveedor INT IDENTITY(1,1) PRIMARY KEY,
        Tipo NVARCHAR(100) NOT NULL,
        Nombre  NVARCHAR(100) NULL,
        Alias   VARCHAR(20)  NULL,
		Nombre_Consorcio VARCHAR(20) NOT NULL
    );