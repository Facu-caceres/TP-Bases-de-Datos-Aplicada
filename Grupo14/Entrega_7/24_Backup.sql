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
Descripción: estrategia de backup


La estrategia de respaldo que vamos a usar busca algo simple la idea central es proteger la información de la base de datos 
principal (toda la operatoria de consorcios, unidades funcionales, pagos, etc.) y, en segundo lugar, los archivos de reportes 
que se generen a partir de esa información.

Todos los días, en un horario donde el sistema no se use (por ejemplo, a las 2 de la mañana), se hará una copia completa 
de la base de datos. Esa copia se guarda en una carpeta específica del servidor dedicada solo a respaldos. Además, durante 
el horario de trabajo (por ejemplo, entre las 8 y las 20), se irán haciendo copias más pequeñas cada cierto tiempo (cada una hora) 
que guardan solo los cambios ocurridos desde la última copia. Con esto, si el sistema se cae o se rompe la base, al restaurar 
podríamos recuperar prácticamente todo lo que pasó, perdiendo como máximo lo que se hizo en la última hora antes del problema, 
algo que se considera aceptable para este tipo de sistema porque esos pagos se pueden volver a cargar consultando el extracto 
bancario o los comprobantes.

Una vez por semana, en la madrugada del domingo, además de la copia diaria normal, se toma una copia pensada como “respaldo 
de archivo”: esa copia se guarda no solo en el servidor principal, sino también en otro lugar físico o lógico (por ejemplo, 
un servidor dentro de la organización o un almacenamiento en la nube). La idea es que si hay un problema grave en el edificio 
(robo, incendio, fallo del servidor completo, etc.), exista al menos una copia de la información fuera del lugar donde se usa el 
sistema.

En resumen, copias completas diarias de la base, copias más frecuentes durante el día para no perder casi nada 
de lo que se carga, un respaldo semanal que se saca fuera del servidor principal y un esquema de carpetas para los reportes. Con 
esto, si pasa algo, se puede volver a poner en marcha el sistema con una pérdida de información muy baja y la mayoría de los 
reportes se pueden regenerar sin depender de un archivo puntual.






*/

