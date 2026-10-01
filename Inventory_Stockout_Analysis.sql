-- ============================================================
-- Inventory Stockout Risk Analysis — SQL version (SQLite)
-- Same business logic as the Google Sheets version.
--
-- HOW TO RUN (DB Browser for SQLite):
--   1. Import the two CSVs (first row = column names) as tables
--      named "productos" and "ventas". They are the raw layer.
--   2. Run sections 1, 2 and 3 in order: select a section's text and
--      press Execute selection (play button). Then Write Changes (Ctrl+S).
--   3. Section 4 holds the read-only queries: run them one at a time.
-- Foreign key enforcement is on by default in DB Browser.
-- ============================================================


-- ------------------------------------------------------------
-- 1. CLEAN SCHEMA
-- Typed tables with keys and constraints (dim = reference data,
-- fact = transactions). Only base attributes are stored: product
-- name/category live only in dim_productos, and subtotal is not
-- stored because it is cantidad * precio_venta.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS fact_ventas;
DROP TABLE IF EXISTS dim_productos;

CREATE TABLE dim_productos (
    id_producto    TEXT PRIMARY KEY,
    nombre         TEXT NOT NULL,
    categoria      TEXT NOT NULL,
    costo_unitario REAL NOT NULL CHECK (costo_unitario >= 0),
    stock_actual   INTEGER NOT NULL CHECK (stock_actual >= 0),
    stock_minimo   INTEGER NOT NULL CHECK (stock_minimo >= 0)
);

CREATE TABLE fact_ventas (
    id_venta     INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha        TEXT NOT NULL CHECK (fecha GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
    id_producto  TEXT NOT NULL REFERENCES dim_productos (id_producto),
    cantidad     INTEGER NOT NULL CHECK (cantidad > 0),
    precio_venta REAL NOT NULL CHECK (precio_venta >= 0)
);


-- ------------------------------------------------------------
-- 2. LOAD (raw -> clean) + sanity check
-- Money exported from Sheets can arrive as text like '$1.200,00':
-- strip '$' and thousands dots, turn the decimal comma into a dot.
-- ------------------------------------------------------------
INSERT INTO dim_productos (id_producto, nombre, categoria, costo_unitario, stock_actual, stock_minimo)
SELECT
    id_producto,
    nombre,
    categoría,
    CAST(CASE WHEN typeof(costo_unitario) = 'text'
              THEN REPLACE(REPLACE(REPLACE(costo_unitario, '$', ''), '.', ''), ',', '.')
              ELSE costo_unitario END AS REAL),
    stock_actual,
    stock_mínimo
FROM productos;

INSERT INTO fact_ventas (fecha, id_producto, cantidad, precio_venta)
SELECT
    fecha,
    id_producto,
    cantidad,
    CAST(CASE WHEN typeof(precio_venta) = 'text'
              THEN REPLACE(REPLACE(REPLACE(precio_venta, '$', ''), '.', ''), ',', '.')
              ELSE precio_venta END AS REAL)
FROM ventas;

-- Expected: 15 products, 40 sales, 300 units, 235030 revenue
SELECT
    (SELECT COUNT(*) FROM dim_productos)                     AS productos,
    (SELECT COUNT(*) FROM fact_ventas)                       AS ventas,
    (SELECT SUM(cantidad) FROM fact_ventas)                  AS unidades,
    (SELECT SUM(cantidad * precio_venta) FROM fact_ventas)   AS facturacion;


-- ------------------------------------------------------------
-- 3. VIEW: per-product stockout risk
-- Shared logic for both queries below (written once, reused).
-- Status is classified on the unrounded coverage; rounding is
-- display-only, so it matches the Sheets version.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_riesgo_productos;

CREATE VIEW v_riesgo_productos AS
WITH periodo AS (
    -- Calendar days covered by the sales log (first to last sale, inclusive)
    SELECT JULIANDAY(MAX(fecha)) - JULIANDAY(MIN(fecha)) + 1 AS dias
    FROM fact_ventas
),
ventas_por_producto AS (
    SELECT id_producto, SUM(cantidad) AS total_vendido
    FROM fact_ventas
    GROUP BY id_producto
),
base AS (
    -- LEFT JOIN keeps products with no sales; COALESCE turns their NULL into 0
    SELECT
        p.id_producto, p.nombre, p.categoria,
        p.stock_actual, p.stock_minimo, p.costo_unitario,
        COALESCE(v.total_vendido, 0) AS total_vendido,
        COALESCE(v.total_vendido, 0) * 1.0 / pe.dias AS venta_diaria
    FROM dim_productos p
    LEFT JOIN ventas_por_producto v ON v.id_producto = p.id_producto
    CROSS JOIN periodo pe
)
SELECT
    id_producto, nombre, categoria, stock_actual, stock_minimo, total_vendido,
    ROUND(venta_diaria, 4) AS venta_promedio_diaria,
    CASE WHEN venta_diaria > 0 THEN ROUND(stock_actual / venta_diaria, 1) END AS dias_cobertura,
    CASE
        WHEN venta_diaria = 0                    THEN 'SIN ROTACIÓN'
        WHEN stock_actual / venta_diaria <= 7    THEN 'URGENTE'
        WHEN stock_actual / venta_diaria <= 14   THEN 'ATENCIÓN'
        ELSE 'OK'
    END AS estado,
    MAX(0, stock_minimo - stock_actual) AS unidades_para_minimo,
    MAX(0, stock_minimo - stock_actual) * costo_unitario AS costo_reposicion
FROM base;


-- ------------------------------------------------------------
-- 4. QUERIES (read-only, run one at a time)
-- ------------------------------------------------------------

-- Query 1: risk status per product (products without sales go last)
SELECT *
FROM v_riesgo_productos
ORDER BY dias_cobertura IS NULL, dias_cobertura;

-- Query 2: category summary, including the share of products at risk
SELECT
    categoria,
    COUNT(*) AS cantidad_productos,
    SUM(CASE WHEN estado IN ('URGENTE', 'ATENCIÓN') THEN 1 ELSE 0 END) AS productos_en_riesgo,
    ROUND(100.0 * SUM(CASE WHEN estado IN ('URGENTE', 'ATENCIÓN') THEN 1 ELSE 0 END) / COUNT(*), 0) AS porcentaje_en_riesgo,
    SUM(costo_reposicion) AS costo_reposicion_categoria
FROM v_riesgo_productos
GROUP BY categoria
ORDER BY productos_en_riesgo DESC, porcentaje_en_riesgo DESC;
