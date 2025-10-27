# TP Integrador - Bases de Datos Aplicada (3641)

## Descripción del Proyecto

Este repositorio contiene el desarrollo del Trabajo Práctico Integrador para la asignatura Bases de Datos Aplicada (3641) de la carrera de Ingeniería en Informática de la UNLaM.

El objetivo del proyecto es diseñar e implementar una base de datos en Microsoft SQL Server para la Administración de Consorcios Altos de Saint Just. El sistema busca centralizar y automatizar la generación mensual de expensas para diferentes consorcios, gestionando información sobre unidades funcionales, propietarios, inquilinos, gastos (ordinarios y extraordinarios), pagos y estados financieros.

Se incluyen scripts SQL para la creación del esquema de la base de datos, procedimientos almacenados para la importación de datos iniciales desde diversos formatos (CSV, TXT, JSON), y la generación de reportes solicitados por el cliente.

## Contexto Académico

* Universidad: Universidad Nacional de La Matanza (UNLaM)

* Carrera: Ingeniería en Informática

* Asignatura: 3641 - Bases de Datos Aplicada

* Comisión: 02-5600

* Año: 2025 (2° Cuatrimestre)

## Integrantes del Grupo 14

* Aguirre Dario Ivan (GitHub: Rner30)

* Caceres Olguin Facundo (GitHub: Facu-caceres)

* Ciriello Florencia (GitHub: florenciaciriello)

* Mangalaviti Sebastian (GitHub: Sebamangalaviti)

* Pedrol Bianca (GitHub: bianpedrol)

* Saladino Mauro (GitHub: maurots)

## Docentes

* Hnatiuk Jair

* Bossero Julio (GitHub: jbossero)

## Tecnologías Utilizadas

* Motor de Base de Datos: Microsoft SQL Server

* Lenguaje: T-SQL (Transact-SQL)

* Herramientas: SQL Server Management Studio (SSMS), Git, GitHub

## Estructura del Repositorio


      /
      |-- scripts/                 # Carpeta con todos los scripts SQL
      |   |-- 01_Creacion_Esquema.sql
      |   |-- 02_Importar_Consorcios.sql
      |   |-- 03_Importar_UnidadesFuncionales.sql
      |   |-- 04_Importar_Personas.sql
      |   |-- ... (otros scripts de importación, reportes, seguridad)
      |-- archivos_origen/         # Archivos de datos originales provistos (opcional, si deciden subirlos)
      |-- documentacion/           # Informes, DER, etc.
      |-- .gitignore
      |-- README.md                # Este archivo

## Configuración y Ejecución

1. Restaurar / Crear la Base de Datos: Ejecutar el script 01_Creacion_Esquema.sql para crear la base de datos Com5600_Grupo14_DB y sus esquemas/tablas.

2. Importar Datos: Ejecutar los scripts de importación (02_Importar_..., 03_..., etc.) en el orden numérico indicado. Asegurarse de modificar las rutas de los archivos (@ruta_archivo) dentro de cada script para que apunten a la ubicación correcta en el entorno local.

3. Consultas / Reportes: Ejecutar los scripts correspondientes a los reportes o consultas deseadas.