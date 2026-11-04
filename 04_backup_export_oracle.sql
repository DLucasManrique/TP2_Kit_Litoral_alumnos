-- =====================================================================
--  RESPALDO PARCIAL - Último export del sistema legado (Oracle)
--  Generado ANTES de la migración. Contiene SOLO los datos de la clienta
--  dada de baja y sus pedidos. Sintaxis Oracle: adaptar antes de ejecutar.
--  Nota: los detalles de estos pedidos NO están en este respaldo.
-- =====================================================================

INSERT INTO cliente (id_cliente, dni, nombre, apellido, email, ciudad, activo, fecha_alta)
VALUES (5, '27345678', 'Marta', 'Rosales', 'marta.rosales@mail.com', 'Santa Fe', 'S', TO_DATE('2024-03-12', 'YYYY-MM-DD'));

INSERT INTO pedido (id_pedido, fecha, estado, id_cliente)
VALUES (7, TO_DATE('2026-08-19', 'YYYY-MM-DD'), 'ENTREGADO', 5);

INSERT INTO pedido (id_pedido, fecha, estado, id_cliente)
VALUES (12, TO_DATE('2026-09-01', 'YYYY-MM-DD'), 'ENTREGADO', 5);

INSERT INTO pedido (id_pedido, fecha, estado, id_cliente)
VALUES (19, TO_DATE('2026-09-23', 'YYYY-MM-DD'), 'ENTREGADO', 5);

COMMIT;
