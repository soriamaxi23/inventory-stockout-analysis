# Análisis de Quiebres de Stock — Proyecto de Portfolio

**Autor:** Maximiliano Soria

**Herramientas:** Google Sheets (VLOOKUP, SUMIF, COUNTIFS, IF anidado, formato condicional) + SQL (SQLite: LEFT JOIN, GROUP BY, CASE WHEN, CTEs, vistas)

*Dataset sintético, diseñado para reproducir un escenario realista de operaciones retail (ver nota completa al final).*

![Dashboard del análisis](Dashboard.png)

## Resumen ejecutivo

| KPI | Resultado |
|---|---|
| Productos analizados | 15 |
| Productos en estado URGENTE | 2 |
| Productos en estado ATENCIÓN | 3 |
| Productos por debajo del stock mínimo | 8 |
| Costo para recuperar stock mínimo (todos) | $26.620 |
| Exposición semanal estimada de ventas — productos URGENTE | ~$6.732 |

## Contexto

Durante mi experiencia en operaciones retail, una de mis responsabilidades directas fue el control de stock e inventario. Este proyecto reconstruye ese proceso con datos representativos, para analizar de forma sistemática qué productos están en riesgo real de quedarse sin stock — no solo cuáles están por debajo de su nivel mínimo, sino cuáles se van a quedar sin stock *pronto*, según su ritmo real de venta.

## Metodología

- El registro de ventas y el maestro de productos se vinculan por ID de producto: VLOOKUP trae el stock al registro de ventas y la categoría a la tabla de productos, y SUMIF suma las unidades vendidas por producto. Dividiendo por los días que cubre el registro se obtiene el ritmo de venta diario de cada producto.
- Se proyectó, para cada producto, cuántos días de stock le quedan al ritmo de venta actual (Stock_Actual ÷ Venta_Promedio_Diaria).
- Cada producto fue clasificado como URGENTE, ATENCIÓN, OK o SIN ROTACIÓN (productos sin ventas; ninguno cae en ese grupo en este dataset) según los días proyectados de cobertura de stock.
- Se cuantificó el impacto en dos dimensiones de negocio: el costo de reponer stock antes de que se corte la venta, y la exposición de ventas ante un eventual quiebre de stock.

## Hallazgos clave

- **2 productos en estado URGENTE** (7 días o menos de cobertura restante): Coca Cola 2.25L y Galletitas Oreo — ambos con alta rotación, lo que hace que el riesgo sea más urgente de lo que sugeriría solo mirar el nivel de stock.
- **3 productos en ATENCIÓN** (más de 7 y hasta 14 días de cobertura restante): Leche Entera 1L, Lavandina 1L y Papel Higiénico x4.
- **Patrón por categoría:** la categoría *Limpieza* concentra 2 de sus 4 productos en estado de riesgo — la mayor cantidad de productos en riesgo de todas las categorías (Snacks tiene 1 de 1, pero con un solo producto la proporción no es comparable). Esta concentración no permite todavía afirmar una causa específica, pero justifica investigar si existe un problema común de reposición, abastecimiento o parametrización de stock mínimo en esa línea.
- **Un hallazgo metodológico relevante:** no todos los productos por debajo de su stock mínimo están en riesgo real. Arroz Largo Fino, por ejemplo, tiene stock por debajo del mínimo pero, por su bajo ritmo de venta, todavía le quedan más de 20 días de cobertura — está clasificado como OK. Esto valida que medir "días de cobertura" da una imagen más precisa del riesgo real que solo comparar contra un umbral fijo de stock mínimo.

## Impacto cuantificado

| Métrica | Valor |
|---|---|
| Costo total de reposición (todos los productos bajo mínimo) | $26.620 |
| Costo de reposición — solo productos URGENTE | $12.880 |
| Exposición semanal estimada de ventas — productos URGENTE: Coca Cola 2.25L + Galletitas Oreo (no es pérdida garantizada) | ~$6.732 |

## Recomendación

Priorizar la reposición inmediata de los 2 productos en estado URGENTE: combinan alta rotación con bajo stock, lo que los convierte en los productos con mayor exposición inmediata a quiebre de stock bajo los supuestos de este modelo. En paralelo, la concentración de casos en la categoría Limpieza (2 de sus 4 productos en riesgo) justifica investigar si existe un problema común de reposición, abastecimiento o parametrización de stock mínimo en esa línea — todavía no alcanza para confirmar una causa específica.

## Versiones del proyecto

Este análisis está resuelto en dos capas distintas sobre los mismos datos:

- **Google Sheets** (`Inventory_Stockout_Analysis.xlsx`): VLOOKUP para relacionar tablas, SUMIF/COUNTIFS para agregaciones, IF anidado para clasificar riesgo, formato condicional para el semáforo visual, y un dashboard con 3 gráficos y KPIs.
- **SQL** (`Inventory_Stockout_Analysis.sql`, SQLite): la misma lógica traducida — LEFT JOIN en lugar de VLOOKUP (así un producto sin ventas no desaparece), GROUP BY en lugar de SUMIF, CASE WHEN en lugar del IF anidado, y CTEs dentro de una vista para encadenar los cálculos de cobertura y riesgo, sobre un esquema tipado con claves primaria y foránea. Incluye además una consulta de resumen por categoría con agregación condicional (SUM + CASE WHEN) y el porcentaje de productos en riesgo. Para reproducirla, seguí las instrucciones al inicio del archivo .sql (importar los dos CSV como tablas llamadas productos y ventas).

Ambas versiones producen las mismas clasificaciones de riesgo y KPIs principales (los mismos 2 productos URGENTE y 3 ATENCIÓN, el mismo patrón por categoría). La versión SQL no incluye el cálculo de exposición de ventas, que vive solo en la planilla.

## Limitaciones

- El stock es una foto estática; el modelo no registra reposiciones ni movimientos de stock durante el período.
- El ritmo de venta diario se calcula sobre los días calendario del período, por lo que los días sin ventas bajan el promedio.
- "Unidades para llegar al mínimo" es la brecha contra el nivel mínimo, no una cantidad óptima de pedido (eso requeriría además el tiempo de entrega del proveedor y stock de seguridad).
- La exposición semanal estimada de ventas es el ingreso diario promedio × 7, es decir, supone un quiebre de una semana; es una estimación de ingresos en riesgo, no una ganancia ni una pérdida confirmada.
- El modelo no incluye tiempos de entrega de proveedores, calendario de reposición ni historial de ventas perdidas; los niveles de riesgo valen solo bajo sus supuestos.

## Nota sobre los datos

Los datos utilizados son sintéticos — no son datos reales de ninguna empresa. Fueron construidos a partir de patrones de mi experiencia en operaciones retail (rangos de precios, márgenes, rotación de productos), pero las cifras específicas no corresponden a transacciones reales de ningún empleador.

---

*English version: [README.md](README.md)*
