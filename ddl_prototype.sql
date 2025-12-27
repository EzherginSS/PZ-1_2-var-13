-- ddl-скрипт прототипа базы данных superstore
-- многослойная архитектура: stg (staging) + dw (data warehouse)

-- очистка существующих объектов (при необходимости)
drop schema if exists dw cascade;
drop schema if exists stg cascade;

-- создание схем для разделения слоев данных
create schema stg; -- слой для сырых данных
create schema dw;  -- слой для витрины данных

-- stg (staging) слой - сырые данные

-- таблица заказов в исходном формате
create table stg.orders (
    row_id integer not null primary key,
    order_id varchar(14) not null,
    order_date date not null,
    ship_date date not null,
    ship_mode varchar(14) not null,
    customer_id varchar(8) not null,
    customer_name varchar(22) not null,
    segment varchar(11) not null,
    country varchar(13) not null,
    city varchar(17) not null,
    state varchar(20) not null,
    postal_code varchar(50), -- varchar для сохранения ведущих нулей
    region varchar(7) not null,
    product_id varchar(15) not null,
    category varchar(15) not null,
    subcategory varchar(11) not null,
    product_name varchar(127) not null,
    sales numeric(9,4) not null,
    quantity integer not null,
    discount numeric(4,2) not null,
    profit numeric(21,16) not null
);

comment on table stg.orders is 'таблица заказов в сыром формате, содержит необработанные данные из источника';
comment on column stg.orders.postal_code is 'varchar для сохранения ведущих нулей в почтовых индексах';

-- таблица менеджеров по регионам
create table stg.people (
    person varchar(17) not null primary key,
    region varchar(7) not null
);

comment on table stg.people is 'таблица менеджеров, ответственных за регионы';

-- таблица возвратов товаров
create table stg.returns (
    order_id varchar(25) not null,
    returned boolean not null
);

comment on table stg.returns is 'таблица возвратов товаров';

-- dw (data warehouse) слой - очищенные данные
-- звездообразная схема (star schema)

-- справочники (dimensions)

-- справочник способов доставки
create table dw.shipping_dim (
    ship_id serial not null primary key,
    shipping_mode varchar(14) not null unique
);

comment on table dw.shipping_dim is 'справочник способов доставки';
comment on column dw.shipping_dim.ship_id is 'суррогатный ключ способа доставки';

-- справочник клиентов
create table dw.customer_dim (
    cust_id serial not null primary key,
    customer_id varchar(8) not null unique,
    customer_name varchar(22) not null
);

comment on table dw.customer_dim is 'справочник клиентов';
comment on column dw.customer_dim.cust_id is 'суррогатный ключ клиента';

-- справочник географических локаций
create table dw.geo_dim (
    geo_id serial not null primary key,
    country varchar(13) not null,
    city varchar(17) not null,
    state varchar(20) not null,
    postal_code varchar(20),
    constraint unique_location unique (country, city, state, postal_code)
);

comment on table dw.geo_dim is 'справочник географических локаций';
comment on column dw.geo_dim.geo_id is 'суррогатный ключ географической локации';

-- справочник продуктов
create table dw.product_dim (
    prod_id serial not null primary key,
    product_id varchar(50) not null,
    product_name varchar(127) not null,
    category varchar(15) not null,
    sub_category varchar(11) not null,
    segment varchar(11) not null
);

comment on table dw.product_dim is 'справочник продуктов';
comment on column dw.product_dim.prod_id is 'суррогатный ключ продукта';

-- справочник дат (календарь)
create table dw.calendar_dim (
    dateid integer not null primary key,
    year integer not null,
    quarter integer not null,
    month integer not null,
    week integer not null,
    date date not null,
    week_day varchar(20) not null,
    leap boolean not null
);

comment on table dw.calendar_dim is 'справочник дат (календарная таблица)';
comment on column dw.calendar_dim.dateid is 'идентификатор даты в формате yyyymmdd';

-- таблица фактов (facts)

-- основная таблица фактов продаж
create table dw.sales_fact (
    sales_id serial not null primary key,
    cust_id integer not null,
    order_date_id integer not null,
    ship_date_id integer not null,
    prod_id integer not null,
    ship_id integer not null,
    geo_id integer not null,
    order_id varchar(25) not null,
    sales numeric(9,4) not null,
    profit numeric(21,16) not null,
    quantity integer not null,
    discount numeric(4,2) not null,
    
    -- ограничения внешних ключей
    constraint fk_sales_fact_customer foreign key (cust_id) 
        references dw.customer_dim(cust_id),
    constraint fk_sales_fact_product foreign key (prod_id) 
        references dw.product_dim(prod_id),
    constraint fk_sales_fact_shipping foreign key (ship_id) 
        references dw.shipping_dim(ship_id),
    constraint fk_sales_fact_geo foreign key (geo_id) 
        references dw.geo_dim(geo_id)
);

comment on table dw.sales_fact is 'таблица фактов продаж (центральная таблица звездообразной схемы)';
comment on column dw.sales_fact.sales_id is 'суррогатный ключ записи о продаже';

-- индексы для оптимизации производительности

-- индексы для таблицы фактов продаж
create index idx_sales_fact_cust_id on dw.sales_fact(cust_id);
create index idx_sales_fact_prod_id on dw.sales_fact(prod_id);
create index idx_sales_fact_ship_id on dw.sales_fact(ship_id);
create index idx_sales_fact_geo_id on dw.sales_fact(geo_id);
create index idx_sales_fact_order_date on dw.sales_fact(order_date_id);
create index idx_sales_fact_ship_date on dw.sales_fact(ship_date_id);

-- индексы для справочника продуктов
create index idx_product_dim_product_id on dw.product_dim(product_id);
create index idx_product_dim_category on dw.product_dim(category);

-- индексы для справочника географии
create index idx_geo_dim_city_state on dw.geo_dim(city, state);
create index idx_geo_dim_postal_code on dw.geo_dim(postal_code);

-- индексы для справочника клиентов
create index idx_customer_dim_customer_id on dw.customer_dim(customer_id);

-- представления (views) для аналитики

-- представление для анализа клиентов
create or replace view dw.v_customers_summary as
select 
    cd.cust_id,
    cd.customer_id,
    cd.customer_name,
    g.city,
    g.state,
    g.country,
    count(distinct sf.order_id) as total_orders,
    sum(sf.sales) as total_sales,
    sum(sf.profit) as total_profit
from dw.customer_dim cd
left join dw.sales_fact sf on cd.cust_id = sf.cust_id
left join dw.geo_dim g on sf.geo_id = g.geo_id
group by 
    cd.cust_id,
    cd.customer_id,
    cd.customer_name,
    g.city,
    g.state,
    g.country;

comment on view dw.v_customers_summary is 'агрегированная информация о клиентах с метриками продаж';

-- представление для анализа продаж по категориям
create or replace view dw.v_sales_by_category as
select 
    p.category,
    count(distinct sf.order_id) as order_count,
    sum(sf.sales) as total_sales,
    sum(sf.profit) as total_profit,
    avg(sf.profit) as avg_profit_per_order
from dw.sales_fact sf
join dw.product_dim p on sf.prod_id = p.prod_id
group by p.category;

comment on view dw.v_sales_by_category is 'анализ продаж и прибыльности по категориям товаров';

-- представление для географического анализа
create or replace view dw.v_sales_by_geography as
select 
    g.country,
    g.state,
    g.city,
    count(distinct sf.order_id) as order_count,
    sum(sf.sales) as total_sales,
    sum(sf.profit) as total_profit,
    avg(sf.profit) as avg_profit_per_order
from dw.sales_fact sf
join dw.geo_dim g on sf.geo_id = g.geo_id
group by g.country, g.state, g.city;

comment on view dw.v_sales_by_geography is 'географический анализ продаж и прибыльности';