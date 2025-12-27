-- Задание 1: Создать представление по клиентам
-- Представление содержит агрегированную информацию о клиентах
CREATE OR REPLACE VIEW dw.customers_summary AS
SELECT 
    cd.cust_id,                     -- Суррогатный ключ клиента
    cd.customer_id,                 -- Бизнес-ключ клиента
    cd.customer_name,               -- Название клиента
    cd.segment,                     -- Сегмент клиента
    g.city,                         -- Город клиента
    g.state,                        -- Штат/регион
    g.country,                      -- Страна
    COUNT(DISTINCT sf.order_id) AS total_orders,  -- Количество уникальных заказов
    SUM(sf.sales) AS total_sales,                 -- Общая сумма продаж
    SUM(sf.profit) AS total_profit                -- Общая прибыль
FROM dw.customer_dim cd
LEFT JOIN dw.sales_fact sf ON cd.cust_id = sf.cust_id        -- Соединение с фактами продаж
LEFT JOIN dw.geo_dim g ON sf.geo_id = g.geo_id               -- Соединение с географией
GROUP BY 
    cd.cust_id,                     -- Группировка по суррогатному ключу клиента
    cd.customer_id,                 -- Группировка по бизнес-ключу клиента
    cd.customer_name,               -- Группировка по имени клиента
    cd.segment,                     -- Группировка по сегменту
    g.city,                         -- Группировка по городу
    g.state,                        -- Группировка по штату
    g.country;                      -- Группировка по стране

-- Задание 2: Определить продажи по способам доставки
-- Рассчитывает общие продажи и количество заказов для каждого способа доставки
SELECT 
    sd.shipping_mode,               -- Способ доставки
    SUM(sf.sales) AS total_sales,   -- Общая сумма продаж
    COUNT(sf.order_id) AS total_orders  -- Общее количество заказов
FROM dw.shipping_dim sd
JOIN dw.sales_fact sf ON sd.ship_id = sf.ship_id   -- Соединение таблиц по ключу доставки
GROUP BY sd.shipping_mode            -- Группировка по способу доставки
ORDER BY total_sales DESC;           -- Сортировка по убыванию суммы продаж

-- Задание 3: Рассчитать среднюю прибыль по городам
-- Анализ рентабельности продаж по географическим локациям
-- Цель: определить наиболее прибыльные города для фокусировки бизнес-стратегии

SELECT 
    g.city,                        -- Название города из справочника географии
    g.state,                       -- Штат/регион из справочника географии
    g.country,                     -- Страна из справочника географии
    AVG(sf.profit) AS avg_profit,  -- Средняя прибыль на один заказ в данном городе
    SUM(sf.profit) AS total_profit -- Общая прибыль от всех заказов в данном городе
FROM dw.geo_dim g                  -- Таблица-справочник географических данных
JOIN dw.sales_fact sf ON g.geo_id = sf.geo_id  -- Соединение с таблицей фактов продаж по ключу географии
GROUP BY g.city, g.state, g.country  -- Группировка для агрегации данных по уникальным городам
ORDER BY avg_profit DESC           -- Сортировка по убыванию средней прибыли (самые прибыльные города сверху)
LIMIT 10;                         -- Ограничение вывода 10 самыми прибыльными городами
