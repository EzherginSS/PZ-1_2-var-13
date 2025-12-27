-- Создание схем для многослойной архитектуры
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dw;

-- Таблицы STG слоя (сырые данные)

-- Таблица заказов в исходном формате
CREATE TABLE stg.orders (
    row_id INTEGER NOT NULL PRIMARY KEY,
    order_id VARCHAR(14) NOT NULL,
    order_date DATE NOT NULL,
    ship_date DATE NOT NULL,
    ship_mode VARCHAR(14) NOT NULL,
    customer_id VARCHAR(8) NOT NULL,
    customer_name VARCHAR(22) NOT NULL,
    segment VARCHAR(11) NOT NULL,
    country VARCHAR(13) NOT NULL,
    city VARCHAR(17) NOT NULL,
    state VARCHAR(20) NOT NULL,
    postal_code VARCHAR(50), -- VARCHAR для сохранения ведущих нулей
    region VARCHAR(7) NOT NULL,
    product_id VARCHAR(15) NOT NULL,
    category VARCHAR(15) NOT NULL,
    subcategory VARCHAR(11) NOT NULL,
    product_name VARCHAR(127) NOT NULL,
    sales NUMERIC(9,4) NOT NULL,
    quantity INTEGER NOT NULL,
    discount NUMERIC(4,2) NOT NULL,
    profit NUMERIC(21,16) NOT NULL
);

-- Таблица менеджеров по регионам
CREATE TABLE stg.people (
    person VARCHAR(17) NOT NULL PRIMARY KEY,
    region VARCHAR(7) NOT NULL
);

-- Таблица возвратов товаров
CREATE TABLE stg.returns (
    order_id VARCHAR(25) NOT NULL,
    returned BOOLEAN NOT NULL
);

-- Таблицы DW слоя (очищенные данные)

-- Справочник способов доставки
CREATE TABLE dw.shipping_dim (
    ship_id SERIAL NOT NULL PRIMARY KEY,
    shipping_mode VARCHAR(14) NOT NULL UNIQUE
);

-- Справочник клиентов
CREATE TABLE dw.customer_dim (
    cust_id SERIAL NOT NULL PRIMARY KEY,
    customer_id VARCHAR(8) NOT NULL UNIQUE,
    customer_name VARCHAR(22) NOT NULL
);

-- Справочник географических локаций
CREATE TABLE dw.geo_dim (
    geo_id SERIAL NOT NULL PRIMARY KEY,
    country VARCHAR(13) NOT NULL,
    city VARCHAR(17) NOT NULL,
    state VARCHAR(20) NOT NULL,
    postal_code VARCHAR(20),
    CONSTRAINT unique_location UNIQUE (country, city, state, postal_code)
);

-- Справочник продуктов
CREATE TABLE dw.product_dim (
    prod_id SERIAL NOT NULL PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL,
    product_name VARCHAR(127) NOT NULL,
    category VARCHAR(15) NOT NULL,
    sub_category VARCHAR(11) NOT NULL,
    segment VARCHAR(11) NOT NULL
);

-- Справочник дат (календарь)
CREATE TABLE dw.calendar_dim (
    dateid INTEGER NOT NULL PRIMARY KEY,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    month INTEGER NOT NULL,
    week INTEGER NOT NULL,
    date DATE NOT NULL,
    week_day VARCHAR(20) NOT NULL,
    leap BOOLEAN NOT NULL
);

-- Основная таблица фактов продаж
CREATE TABLE dw.sales_fact (
    sales_id SERIAL NOT NULL PRIMARY KEY,
    cust_id INTEGER NOT NULL REFERENCES dw.customer_dim(cust_id),
    order_date_id INTEGER NOT NULL,
    ship_date_id INTEGER NOT NULL,
    prod_id INTEGER NOT NULL REFERENCES dw.product_dim(prod_id),
    ship_id INTEGER NOT NULL REFERENCES dw.shipping_dim(ship_id),
    geo_id INTEGER NOT NULL REFERENCES dw.geo_dim(geo_id),
    order_id VARCHAR(25) NOT NULL,
    sales NUMERIC(9,4) NOT NULL,
    profit NUMERIC(21,16) NOT NULL,
    quantity INTEGER NOT NULL,
    discount NUMERIC(4,2) NOT NULL
);

-- Индексы для оптимизации производительности

-- Индексы для таблицы фактов продаж
CREATE INDEX idx_sales_fact_cust_id ON dw.sales_fact(cust_id);
CREATE INDEX idx_sales_fact_prod_id ON dw.sales_fact(prod_id);
CREATE INDEX idx_sales_fact_ship_id ON dw.sales_fact(ship_id);
CREATE INDEX idx_sales_fact_geo_id ON dw.sales_fact(geo_id);
CREATE INDEX idx_sales_fact_order_date ON dw.sales_fact(order_date_id);
CREATE INDEX idx_sales_fact_ship_date ON dw.sales_fact(ship_date_id);

-- Индексы для справочника продуктов
CREATE INDEX idx_product_dim_product_id ON dw.product_dim(product_id);
CREATE INDEX idx_product_dim_category ON dw.product_dim(category);

-- Индексы для справочника географии
CREATE INDEX idx_geo_dim_city_state ON dw.geo_dim(city, state);
CREATE INDEX idx_geo_dim_postal_code ON dw.geo_dim(postal_code);
CREATE INDEX idx_geo_dim_postal_code ON dw.geo_dim(postal_code);