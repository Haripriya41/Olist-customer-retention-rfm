use olist;
 USE olist;

CREATE TABLE customers (
  customer_id VARCHAR(50),
  customer_unique_id VARCHAR(50),
  customer_zip_code_prefix VARCHAR(10),
  customer_city VARCHAR(100),
  customer_state VARCHAR(5)
);

LOAD DATA LOCAL INFILE 'C:/Users/user/OneDrive/Documents/Project/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

SHOW WARNINGS;
SELECT COUNT(*) FROM customers;

CREATE TABLE orders (
  order_id VARCHAR(50),
  customer_id VARCHAR(50),
  order_status VARCHAR(20),
  order_purchase_timestamp DATETIME,
  order_approved_at DATETIME,
  order_delivered_carrier_date DATETIME,
  order_delivered_customer_date DATETIME,
  order_estimated_delivery_date DATETIME
);
LOAD DATA LOCAL INFILE 'C:/Users/user/OneDrive/Documents/Project/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, @a, @b, @c, @d, @e)
SET order_purchase_timestamp = NULLIF(@a,''),
    order_approved_at = NULLIF(@b,''),
    order_delivered_carrier_date = NULLIF(@c,''),
    order_delivered_customer_date = NULLIF(@d,''),
    order_estimated_delivery_date = NULLIF(@e,'');
    
    SHOW WARNINGS;
SELECT COUNT(*) FROM orders;

CREATE TABLE payments (
  order_id VARCHAR(50),
  payment_sequential INT,
  payment_type VARCHAR(30),
  payment_installments INT,
  payment_value DECIMAL(10,2)
);
LOAD DATA LOCAL INFILE 'C:/Users/user/OneDrive/Documents/Project/olist_order_payments_dataset.csv'
INTO TABLE payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

select count(*) from payments;

CREATE TABLE reviews (
  review_id VARCHAR(50),
  order_id VARCHAR(50),
  review_score INT,
  review_comment_title TEXT,
  review_comment_message TEXT,
  review_creation_date DATETIME,
  review_answer_timestamp DATETIME
);

LOAD DATA LOCAL INFILE 'C:/Users/user/OneDrive/Documents/Project/olist_order_reviews_dataset.csv'
INTO TABLE reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

truncate table customers;
SHOW WARNINGS;
SELECT COUNT(*) FROM reviews;

SELECT 'customers' AS tbl, COUNT(*) AS cnt FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews;


SET SQL_SAFE_UPDATES = 0;   -- lets UPDATE run without a key in Workbench

CREATE TABLE customers_raw AS SELECT * FROM customers;
CREATE TABLE orders_raw    AS SELECT * FROM orders;
create table  payments_raw as select * from payments;
create table review_raw as select * from reviews;

SELECT COUNT(*) FROM customers;
select * from payments;





# Data cleaning

SELECT order_id, COUNT(*) FROM orders GROUP BY order_id HAVING COUNT(*) > 1;  #checking dulipcates
SELECT customer_id, COUNT(*) FROM customers GROUP BY customer_id HAVING COUNT(*) > 1;
SELECT COUNT(*) FROM orders WHERE order_purchase_timestamp IS NULL;
SELECT COUNT(*) FROM orders WHERE order_delivered_customer_date < order_purchase_timestamp;
SELECT COUNT(*) FROM payments WHERE payment_value <= 0;
SELECT COUNT(*) FROM reviews WHERE review_answer_timestamp IS NULL;

SELECT * FROM payments WHERE payment_value <= 0;

CREATE OR REPLACE VIEW clean_orders AS
SELECT o.order_id,
       c.customer_unique_id,
       o.order_purchase_timestamp,
       o.order_delivered_customer_date,
       o.order_estimated_delivery_date,
       p.order_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN (SELECT order_id, SUM(payment_value) AS order_value
      FROM payments GROUP BY order_id) p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
  AND p.order_value > 0
  AND (o.order_delivered_customer_date IS NULL
       OR o.order_delivered_customer_date >= o.order_purchase_timestamp);
       
       UPDATE customers SET customer_city = LOWER(TRIM(customer_city)), customer_state = UPPER(TRIM(customer_state));

CREATE INDEX idx_cust_id  ON customers(customer_id);
CREATE INDEX idx_cust_uid ON customers(customer_unique_id);
CREATE INDEX idx_ord_id   ON orders(order_id);
CREATE INDEX idx_ord_cust ON orders(customer_id);
CREATE INDEX idx_pay_ord  ON payments(order_id);
CREATE INDEX idx_rev_ord  ON reviews(order_id);


USE olist;

SELECT COUNT(*) AS rows_in_view,
       COUNT(DISTINCT order_id) AS unique_orders,
       COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM clean_orders;

CREATE OR REPLACE VIEW cohort_retention AS
WITH first_order AS (
  SELECT customer_unique_id,
         DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m-01') AS cohort_month
  FROM clean_orders
  GROUP BY customer_unique_id
),
activity AS (
  SELECT DISTINCT customer_unique_id,
         DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS order_month
  FROM clean_orders
),
cohort_counts AS (
  SELECT f.cohort_month,
         TIMESTAMPDIFF(MONTH, f.cohort_month, a.order_month) AS month_number,
         COUNT(DISTINCT a.customer_unique_id) AS customers
  FROM first_order f
  JOIN activity a ON f.customer_unique_id = a.customer_unique_id
  GROUP BY f.cohort_month, month_number
)
SELECT cohort_month, month_number, customers,
       ROUND(100 * customers /
             FIRST_VALUE(customers) OVER (PARTITION BY cohort_month ORDER BY month_number), 2) AS retention_pct
FROM cohort_counts
WHERE cohort_month BETWEEN '2017-01-01' AND '2018-06-01'
ORDER BY cohort_month, month_number;

SELECT * FROM cohort_retention;

-- Month 0 should be 100% for every cohort
SELECT cohort_month, customers, retention_pct
FROM cohort_retention WHERE month_number = 0;

-- Average retention by month
SELECT month_number, ROUND(AVG(retention_pct),2) AS avg_retention_pct
FROM cohort_retention
GROUP BY month_number ORDER BY month_number;

-- Month 0 must be 100% for every cohort
SELECT cohort_month, customers, retention_pct
FROM cohort_retention WHERE month_number = 0;

-- Average retention for each month
SELECT month_number, ROUND(AVG(retention_pct),2) AS avg_retention_pct
FROM cohort_retention
GROUP BY month_number ORDER BY month_number;

SELECT * FROM cohort_retention;

CREATE OR REPLACE VIEW rfm AS
WITH base AS (
  SELECT customer_unique_id,
         MAX(order_purchase_timestamp) AS last_order,
         COUNT(DISTINCT order_id) AS frequency,
         SUM(order_value) AS monetary
  FROM clean_orders
  GROUP BY customer_unique_id
),
scored AS (
  SELECT customer_unique_id, frequency, monetary,
         DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM clean_orders), last_order) AS recency_days,
         NTILE(5) OVER (ORDER BY last_order) AS r,
         CASE WHEN frequency = 1 THEN 1 WHEN frequency = 2 THEN 3 ELSE 5 END AS f,
         NTILE(5) OVER (ORDER BY monetary) AS m
  FROM base
)
SELECT *,
  CASE
    WHEN f >= 3 AND r >= 4 THEN 'Champions'
    WHEN f >= 3 AND r <= 3 THEN 'Loyal - At Risk'
    WHEN f = 1 AND r >= 4 AND m >= 4 THEN 'New Big Spenders'
    WHEN f = 1 AND r >= 4 THEN 'New Customers'
    WHEN f = 1 AND r <= 2 AND m >= 4 THEN 'At Risk - High Value'
    WHEN f = 1 AND r <= 2 THEN 'Lost'
    ELSE 'Needs Attention'
  END AS segment
FROM scored;

SELECT segment,
       COUNT(*) AS customers,
       ROUND(SUM(monetary)) AS revenue,
       ROUND(AVG(monetary),1) AS avg_spend,
       ROUND(AVG(recency_days)) AS avg_days_since_last_order
FROM rfm
GROUP BY segment
ORDER BY revenue DESC;

USE olist;

CREATE OR REPLACE VIEW clean_reviews AS
SELECT order_id, review_score, review_creation_date
FROM (SELECT order_id, review_score, review_creation_date,
             ROW_NUMBER() OVER (PARTITION BY order_id
                                ORDER BY review_answer_timestamp DESC) AS rn
      FROM reviews) x
WHERE rn = 1;

SELECT COUNT(*) AS rows_in_view, COUNT(DISTINCT order_id) AS unique_orders
FROM clean_reviews;
USE olist;

CREATE OR REPLACE VIEW clean_reviews AS
SELECT order_id, review_score, review_creation_date
FROM (SELECT order_id, review_score, review_creation_date,
             ROW_NUMBER() OVER (PARTITION BY order_id
                                ORDER BY review_answer_timestamp DESC) AS rn
      FROM reviews) x
WHERE rn = 1;  

SELECT COUNT(*) AS rows_in_view,
       COUNT(DISTINCT order_id) AS unique_orders
FROM clean_reviews;

SELECT * FROM cohort_retention;

SELECT COUNT(*) FROM customers;       -- expect 99441
SELECT COUNT(*) FROM customers_raw;   -- expect 99441; if 0, run the next 2 lines
DROP TABLE customers_raw;
CREATE TABLE customers_raw AS SELECT * FROM customers;


SELECT COUNT(*) AS null_dates,
       MIN(order_estimated_delivery_date) AS earliest,
       MAX(order_estimated_delivery_date) AS latest
FROM orders;

WITH order_flag AS (
  SELECT co.customer_unique_id, co.order_id,
         CASE WHEN co.order_delivered_customer_date > co.order_estimated_delivery_date
              THEN 'Late' ELSE 'On time' END AS delivery_status,
         r.review_score,
         ROW_NUMBER() OVER (PARTITION BY co.customer_unique_id
                            ORDER BY co.order_purchase_timestamp) AS order_no
  FROM clean_orders co
  JOIN clean_reviews r ON co.order_id = r.order_id
  WHERE co.order_delivered_customer_date IS NOT NULL
),
repeat_flag AS (
  SELECT customer_unique_id, COUNT(*) > 1 AS is_repeat
  FROM clean_orders GROUP BY customer_unique_id
)
SELECT o.delivery_status,
       COUNT(*) AS customers,
       ROUND(AVG(o.review_score),2) AS avg_review,
       ROUND(100*AVG(rf.is_repeat),2) AS repeat_rate_pct
FROM order_flag o
JOIN repeat_flag rf ON o.customer_unique_id = rf.customer_unique_id
WHERE o.order_no = 1
GROUP BY o.delivery_status;

SELECT COUNT(*) AS total_customers,
       SUM(frequency > 1) AS repeat_customers,
       ROUND(100 * AVG(frequency > 1), 2) AS repeat_rate_pct,
       ROUND(SUM(monetary) / SUM(frequency), 2) AS avg_order_value
FROM rfm;