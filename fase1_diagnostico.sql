-- =====================================================================
-- TP2 · Fase 1 · Diagnóstico · Incidente en producción
-- Base evaluada: litoral_pedidos (cargada con 02 y 03)
-- =====================================================================
SELECT VERSION();
-- Resultado: 10.4.32-MariaDB


-- =====================================================================
-- INC-01 · «El reporte de ventas trae renglones de pedidos que no
--           aparecen en ningún lado»
-- =====================================================================

-- Motor de cada tabla
SELECT TABLE_NAME, ENGINE
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'litoral_pedidos';
-- Resultado: categoria InnoDB, cliente InnoDB, detalle_pedido MyISAM,
--            pedido InnoDB, producto InnoDB

-- Cuántos renglones huérfanos hay
SELECT COUNT(*)
FROM litoral_pedidos.detalle_pedido d
LEFT JOIN litoral_pedidos.pedido p ON p.id_pedido = d.id_pedido
WHERE p.id_pedido IS NULL;
-- Resultado: 11

-- Cuáles son
SELECT d.*
FROM litoral_pedidos.detalle_pedido d
LEFT JOIN litoral_pedidos.pedido p ON p.id_pedido = d.id_pedido
WHERE p.id_pedido IS NULL;
-- Resultado: 11 renglones, de los pedidos 7, 12, 19 y 40.

-- Claves foráneas que existen realmente en el servidor
SELECT CONSTRAINT_NAME, TABLE_NAME, REFERENCED_TABLE_NAME, DELETE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'litoral_pedidos';
-- Resultado: solo 2 FK en el servidor:
--   pedido_ibfk_1   (pedido -> cliente,     DELETE_RULE = CASCADE)
--   producto_ibfk_1 (producto -> categoria, DELETE_RULE = RESTRICT)
--   Faltan las 2 FK de detalle_pedido.

-- ---------------------------------------------------------------------
-- INC-01 · CAUSA RAÍZ
-- Causa 1 (02_migracion_proveedor.sql, línea 60): detalle_pedido se creó
--   con ENGINE=MyISAM, motor que no soporta claves foráneas. Las dos
--   FOREIGN KEY de las líneas 58 y 59 se aceptaron sin error pero se
--   ignoraron: no existen en el servidor (comprobado con
--   information_schema.REFERENTIAL_CONSTRAINTS). En el original Oracle
--   (01_legado_oracle.sql, líneas 65 a 68) esas FK sí existían
--   (fk_detalle_pedido y fk_detalle_producto).
-- Causa 2 (02, línea 47): la FK de pedido hacia cliente tiene
--   ON DELETE CASCADE. Al borrar clientes se borraron sus pedidos, pero
--   sus renglones quedaron porque MyISAM no propaga el borrado.
-- Efecto: renglones huérfanos que aparecen en el reporte de ventas sin
--   pedido ni cliente asociado.
-- Relación: la causa 2 también explica INC-02.
-- ---------------------------------------------------------------------


-- =====================================================================
-- INC-02 · «Dimos de baja a Marta Rosales y desapareció todo su
--           historial de compras»
-- =====================================================================

-- ¿Existe Rosales en producción?
SELECT * FROM litoral_pedidos.cliente WHERE apellido = 'Rosales';
-- Resultado: 0 filas.

-- Pedidos suyos hoy en producción (id_cliente 5, según 04)
SELECT * FROM litoral_pedidos.pedido WHERE id_cliente = 5;
-- Resultado: 0 filas.

-- Renglones y monto que quedaron de sus pedidos 7, 12 y 19
SELECT COUNT(*) AS renglones,
       SUM(cantidad * precio_unitario) AS monto
FROM litoral_pedidos.detalle_pedido
WHERE id_pedido IN (7, 12, 19);
-- Resultado: 9 renglones; monto = 136969.38110351562
--   (≈ $136.969,38; los decimales sobrantes son ruido del tipo FLOAT).

-- Renglones huérfanos que NO son de Rosales (pedido 40)
SELECT * FROM litoral_pedidos.detalle_pedido WHERE id_pedido = 40;
-- Resultado:2 renglones sin pedido ni dueño conocido:
--   id_detalle_pedido 74 (producto 3, cantidad 2, precio 3120.75)
--   id_detalle_pedido 75 (producto 9, cantidad 1, precio 5420.85).
 --No hay pedido 40 en producción ni en el
--   respaldo 04: dueño desconocido (se registrará en descartes, Fase 3).

-- ---------------------------------------------------------------------
-- INC-02 · CAUSA RAÍZ
-- Marta Rosales (id_cliente 5, DNI 27345678, según 04) fue borrada con
-- DELETE físico. En 01 la baja es lógica (columna activo; COMMENT ON
-- COLUMN, línea 33: «los clientes NUNCA se borran»). 02 eliminó la
-- columna activo (línea 17) y agregó ON DELETE CASCADE (línea 47): el
-- borrado se llevó sus pedidos 7, 12 y 19. Sus renglones quedaron
-- huérfanos porque detalle_pedido es MyISAM (línea 60).
-- Recuperación: 04 trae cliente y pedidos (sin detalles); los detalles
-- siguen en detalle_pedido.
-- ---------------------------------------------------------------------


-- =====================================================================
-- INC-03 · «Nombres con símbolos raros (MuÃ±oz) y no se pudo dar de
--           alta a un cliente de apellido Nguyễn»
-- =====================================================================

-- Filas dañadas en cliente (comparación exacta por bytes: latin1_bin)
SELECT id_cliente, nombre, apellido
FROM litoral_pedidos.cliente
WHERE nombre   COLLATE latin1_bin LIKE '%Ã%'
   OR apellido COLLATE latin1_bin LIKE '%Ã%';
-- Resultado: 3 filas (ids 2, 6 y 10).

-- Filas dañadas en producto
SELECT id_producto, nombre
FROM litoral_pedidos.producto
WHERE nombre COLLATE latin1_bin LIKE '%Ã%';
-- Resultado: 1 fila (id 2, 'CafÃ© molido 500 g').

-- Prueba del alta de Nguyễn en una base APARTE (no se toca la evidencia).
-- Seleccionar este bloque entero y ejecutarlo junto.
CREATE DATABASE prueba_charset CHARACTER SET latin1 COLLATE latin1_swedish_ci;
CREATE TABLE prueba_charset.t (apellido VARCHAR(60));
INSERT INTO prueba_charset.t VALUES ('Nguyễn');
SHOW WARNINGS;
SELECT apellido FROM prueba_charset.t;
DROP DATABASE prueba_charset;
-- Resultado: (pegar qué se guardó y si hubo warning o error)
-- Nota: en el XAMPP del alumno (sql_mode no estricto) el alta no dio
--   error: MariaDB guardó el apellido con caracteres reemplazados.
--   En modo estricto el servidor rechaza la fila con el error 1366.

-- ---------------------------------------------------------------------
-- INC-03 · CAUSA RAÍZ (02, línea 9): CREATE DATABASE ... CHARACTER SET
-- latin1 COLLATE latin1_swedish_ci. El dump llega en UTF-8 y se guarda
-- en latin1: cada ñ/á/é de 2 bytes se lee como 2 caracteres (Ã±, Ã¡, Ã©).
-- latin1 tampoco puede guardar 'ễ': por eso falla (o se corrompe) el
-- alta de Nguyễn. Además latin1_swedish_ci no distingue Ã de A, por eso
-- un LIKE '%Ã%' común devolvía casi todos los clientes; se usó
-- latin1_bin.
-- ---------------------------------------------------------------------


-- =====================================================================
-- INC-04 · «La facturación de octubre no coincide con la nuestra
--           ($154.980,30, lo cancelado no se factura) y los totales
--           salen con decimales infinitos»
-- =====================================================================

-- 1) Total de octubre contando todo (incluye cancelados)
SELECT SUM(d.cantidad * d.precio_unitario) AS total_con_cancelados
FROM litoral_pedidos.pedido p
JOIN litoral_pedidos.detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE p.fecha BETWEEN '2026-10-01' AND '2026-10-31';
-- Resultado: (pegar resultado)

-- 2) Excluyendo cancelados
SELECT SUM(d.cantidad * d.precio_unitario) AS total_sin_cancelados
FROM litoral_pedidos.pedido p
JOIN litoral_pedidos.detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE p.fecha BETWEEN '2026-10-01' AND '2026-10-31'
  AND p.estado <> 'CANCELADO';
-- Resultado: (pegar resultado)

-- 3) Líneas con cantidad inválida dentro de octubre
SELECT d.*
FROM litoral_pedidos.pedido p
JOIN litoral_pedidos.detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE p.fecha BETWEEN '2026-10-01' AND '2026-10-31'
  AND d.cantidad <= 0;
-- Resultado: (pegar resultado)

-- 4) Sin cancelados, sin líneas inválidas y redondeado a 2 decimales
SELECT ROUND(SUM(d.cantidad * d.precio_unitario), 2) AS total_depurado
FROM litoral_pedidos.pedido p
JOIN litoral_pedidos.detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE p.fecha BETWEEN '2026-10-01' AND '2026-10-31'
  AND p.estado <> 'CANCELADO'
  AND d.cantidad > 0;
-- Resultado: (pegar resultado; comparar con $154.980,30 de Contabilidad)

-- ---------------------------------------------------------------------
-- INC-04 · CAUSA RAÍZ (completar según los resultados de arriba)
-- a) 02, líneas 34 y 56: precio y precio_unitario son FLOAT (binario
--    aproximado); en 01 eran NUMBER(10,2). Produce decimales infinitos.
-- b) El sistema suma pedidos CANCELADO (diferencia entre consulta 1 y 2).
-- c) Hay una línea con cantidad negativa en octubre (id_detalle_pedido
--    55, pedido 23, cantidad -2): ver INC-06. Falta el CHECK de la
--    línea 30 de 02.
-- ---------------------------------------------------------------------


-- =====================================================================
-- INC-05 · «Clientes repetidos con el mismo DNI y sus pedidos quedan
--           repartidos entre los dos»
-- =====================================================================

SELECT dni, COUNT(*) AS cantidad, GROUP_CONCAT(id_cliente) AS ids
FROM litoral_pedidos.cliente
GROUP BY dni
HAVING COUNT(*) > 1;
-- Resultado: 2 DNI duplicados:
--   28999555 -> clientes 8 y 15 (Pablo Ferreyra / Pablo Ferreira)
--   30111222 -> clientes 3 y 13 (Lucía Gómez / Lucia Gomez)

-- Pedidos repartidos entre los duplicados
SELECT id_cliente, COUNT(*) AS pedidos
FROM litoral_pedidos.pedido
WHERE id_cliente IN (3, 13, 8, 15)
GROUP BY id_cliente;
-- Resultado: los clientes 3, 8, 13 y 15 tienen 2 pedidos cada uno
--   (8 pedidos en total, repartidos entre los duplicados).

-- ---------------------------------------------------------------------
-- INC-05 · CAUSA RAÍZ (02, línea 18): comentario de la IA «el UNIQUE
-- sobre dni se omite para evitar errores al importar datos». En 01
-- existía uq_cliente_dni (línea 29). Sin esa restricción se pudo cargar
-- el mismo DNI dos veces.
-- ---------------------------------------------------------------------


-- =====================================================================
-- INC-06 · «Líneas de pedido con cantidad 0 o negativa y un producto
--           con stock -5»
-- =====================================================================

SELECT * FROM litoral_pedidos.detalle_pedido WHERE cantidad <= 0;
-- Resultado: 2 filas:
--   id_detalle_pedido 5  (pedido 2,  producto 6, cantidad 0)
--   id_detalle_pedido 55 (pedido 23, producto 6, cantidad -2)

SELECT * FROM litoral_pedidos.producto WHERE stock < 0;
-- Resultado: 1 fila: id_producto 7 (Esponja doble faz x3, stock -5)

-- ---------------------------------------------------------------------
-- INC-06 · CAUSA RAÍZ (02, líneas 29 y 30): comentario de la IA
-- «MySQL no soporta restricciones CHECK, se omiten». Es FALSO en
-- MariaDB 10.4.32: CHECK se aplica desde la versión 10.2.1. En 01
-- existían ck_producto_precio (línea 41), ck_producto_stock (línea 42)
-- y ck_detalle_cantidad (línea 64). Sin ellas se cargaron cantidades
-- <= 0 y stock negativo.
-- ---------------------------------------------------------------------