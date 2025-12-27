-- Проверка 1: Количественные метрики по таблицам
-- Сравнение количества записей между STG и DW слоями
SELECT 'stg.orders' as table_name, COUNT(*) as record_count FROM stg.orders
UNION ALL
SELECT 'dw.sales_fact', COUNT(*) FROM dw.sales_fact
UNION ALL
SELECT 'dw.customer_dim', COUNT(*) FROM dw.customer_dim
UNION ALL
SELECT 'dw.product_dim', COUNT(*) FROM dw.product_dim
UNION ALL
SELECT 'dw.geo_dim', COUNT(*) FROM dw.geo_dim;

-- Проверка 2: Распределение продуктов по категориям
-- Анализ структуры ассортимента
SELECT category, COUNT(*) as product_count
FROM dw.product_dim
GROUP BY category
ORDER BY product_count DESC;

-- Проверка 3: Дубликаты в измерениях
-- Проверка целостности справочников
SELECT 'customer_dim' as table_name, customer_id, COUNT(*) as duplicate_count
FROM dw.customer_dim
GROUP BY customer_id
HAVING COUNT(*) > 1
UNION ALL
SELECT 'product_dim', product_id, COUNT(*)
FROM dw.product_dim
GROUP BY product_id
HAVING COUNT(*) > 1
UNION ALL
SELECT 'geo_dim', CONCAT(country, '-', city, '-', state), COUNT(*)
FROM dw.geo_dim
GROUP BY country, city, state
HAVING COUNT(*) > 1;

-- Проверка 4: Ссылочная целостность между фактами и измерениями
-- Поиск "сиротских" записей в таблице фактов
SELECT 
    'customer_dim' as dimension,
    COUNT(*) as orphaned_records
FROM dw.sales_fact sf
LEFT JOIN dw.customer_dim cd ON sf.cust_id = cd.cust_id
WHERE cd.cust_id IS NULL
UNION ALL
SELECT 
    'product_dim',
    COUNT(*)
FROM dw.sales_fact sf
LEFT JOIN dw.product_dim pd ON sf.prod_id = pd.prod_id
WHERE pd.prod_id IS NULL
UNION ALL
SELECT 
    'shipping_dim',
    COUNT(*)
FROM dw.sales_fact sf
LEFT JOIN dw.shipping_dim sd ON sf.ship_id = sd.ship_id
WHERE sd.ship_id IS NULL
UNION ALL
SELECT 
    'geo_dim',
    COUNT(*)
FROM dw.sales_fact sf
LEFT JOIN dw.geo_dim gd ON sf.geo_id = gd.geo_id
WHERE gd.geo_id IS NULL;

-- Проверка 5: Корректность финансовых агрегатов
-- Сверка итоговых сумм между STG и DW
SELECT 
    'stg.orders' as source,
    COUNT(*) as total_records,
    SUM(sales) as total_sales,
    SUM(profit) as total_profit,
    AVG(profit) as avg_profit,
    MIN(order_date) as min_date,
    MAX(order_date) as max_date
FROM stg.orders;

-- Проверка 6: Корректность данных в DW слое
SELECT 
    'dw.sales_fact' as source,
    COUNT(*) as total_records,
    SUM(sales) as total_sales,
    SUM(profit) as total_profit,
    AVG(profit) as avg_profit
FROM dw.sales_fact;

-- Проверка 7: Качество данных в созданном представлении
SELECT 
    COUNT(*) as total_customers,
    SUM(total_orders) as total_orders_view,
    SUM(total_sales) as total_sales_view,
    SUM(total_profit) as total_profit_view
FROM dw.customers_summary;

-- Проверка 8: Валидация результатов задания 2
SELECT 
    COUNT(*) as shipping_methods_count,
    SUM(total_sales) as total_sales_all_methods,
    SUM(total_orders) as total_orders_all_methods
FROM (
    SELECT 
        sd.shipping_mode,
        SUM(sf.sales) AS total_sales,
        COUNT(sf.order_id) AS total_orders
    FROM dw.shipping_dim sd
    JOIN dw.sales_fact sf ON sd.ship_id = sf.ship_id
    GROUP BY sd.shipping_mode
) shipping_stats;

-- Проверка 9: Валидация результатов задания 3
SELECT 
    COUNT(DISTINCT CONCAT(city, state, country)) as unique_cities,
    AVG(avg_profit) as overall_avg_profit,
    SUM(total_profit) as overall_total_profit
FROM (
    SELECT 
        g.city,
        g.state,
        g.country,
        AVG(sf.profit) AS avg_profit,
        SUM(sf.profit) AS total_profit
    FROM dw.geo_dim g
    JOIN dw.sales_fact sf ON g.geo_id = sf.geo_id
    GROUP BY g.city, g.state, g.country
) city_stats;

-- Проверка 10: Аномалии в данных
-- Поиск отрицательных значений прибыли
SELECT COUNT(*) as negative_profit_count
FROM dw.sales_fact
WHERE profit < 0;

-- Проверка экстремальных значений скидок
SELECT 
    MIN(discount) as min_discount,
    MAX(discount) as max_discount,
    AVG(discount) as avg_discount
FROM dw.sales_fact;

-- Проверка временных диапазонов
SELECT 
    MIN(order_date) as earliest_order,
    MAX(order_date) as latest_order,
    MAX(order_date) - MIN(order_date) as date_range
FROM stg.orders;