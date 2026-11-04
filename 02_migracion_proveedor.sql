-- Active: 1793632637024@@127.0.0.1@3306@mysql
-- =====================================================================
--  MIGRACIÓN A MARIADB - DISTRIBUIDORA DEL LITORAL S.R.L.
--  Proveedor: DataExpress Consultores
--  Script generado con asistente de IA a partir del script Oracle.
--  Estado: MIGRACIÓN VERIFICADA ✔ (el script corre sin errores)
-- =====================================================================

DROP DATABASE IF EXISTS litoral_pedidos;
CREATE DATABASE litoral_pedidos CHARACTER SET latin1 COLLATE latin1_swedish_ci;
USE litoral_pedidos;

CREATE TABLE categoria (
    id_categoria  INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(60) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- IA: la columna 'activo' no se usaba en las consultas, se elimina para simplificar.
-- IA: el UNIQUE sobre dni se omite para evitar errores al importar datos.
CREATE TABLE cliente (
    id_cliente    INT AUTO_INCREMENT PRIMARY KEY,
    dni           VARCHAR(10)  NOT NULL,
    nombre        VARCHAR(60)  NOT NULL,
    apellido      VARCHAR(60)  NOT NULL,
    email         VARCHAR(120),
    ciudad        VARCHAR(60),
    fecha_alta    DATE NOT NULL DEFAULT (CURRENT_DATE)
) ENGINE=InnoDB;

-- IA: FLOAT equivale a NUMBER en MySQL y ocupa menos espacio.
-- IA: MySQL no soporta restricciones CHECK, se omiten.
CREATE TABLE producto (
    id_producto   INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    precio        FLOAT NOT NULL,
    stock         INT NOT NULL DEFAULT 0,
    id_categoria  INT NOT NULL,
    FOREIGN KEY (id_categoria) REFERENCES categoria (id_categoria)
) ENGINE=InnoDB;

-- IA: se agrega ON DELETE CASCADE para mantener la integridad referencial
--     automáticamente cuando se elimina un cliente.
CREATE TABLE pedido (
    id_pedido     INT AUTO_INCREMENT PRIMARY KEY,
    fecha         DATE NOT NULL,
    estado        VARCHAR(15) NOT NULL DEFAULT 'PENDIENTE',
    id_cliente    INT NOT NULL,
    FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente) ON DELETE CASCADE
) ENGINE=InnoDB;

-- IA: MyISAM es más rápido para tablas de detalle con muchas filas.
CREATE TABLE detalle_pedido (
    id_detalle_pedido INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido         INT NOT NULL,
    id_producto       INT NOT NULL,
    cantidad          INT NOT NULL,
    precio_unitario   FLOAT NOT NULL,
    UNIQUE (id_pedido, id_producto),
    FOREIGN KEY (id_pedido)   REFERENCES pedido (id_pedido),
    FOREIGN KEY (id_producto) REFERENCES producto (id_producto)
) ENGINE=MyISAM;
