-- Use only one year of data, 2010-12-01 to 2011-12-01.
-- Calculate recency from date 2011-12-01.
-- Segment customers into Best Customers, Loyal Customers, Big Spenders, Lost Customers and other categories.

-- About Data (period 2010-12-01 to 2011-12-01):
-- 4,331 distinct customers
-- 8 CustomerID have two different countries (12417, 12431, 12394, 12455, 12422, 12370, 12457, 12429)
-- 37 distinct countries

-- 127,216 (out of 516,384) records had null CustomerID.


WITH
-- Create date parameters
date_param AS (
    SELECT
      TIMESTAMP('2010-12-01 00:00:00', 'UTC') AS start_date,
      TIMESTAMP('2011-12-01 00:00:00', 'UTC') AS end_date,
      TIMESTAMP('2011-12-01 00:00:00', 'UTC') AS reference_date
),

-- Compute for F & M
t1 AS (
    SELECT
      ROW_NUMBER() OVER() cust_id_new, -- There are several customers with a different country on the same customer_id
      CustomerID as customer_id,
      country,
      DATE(MAX(InvoiceDate)) AS last_purchase_date,
      COUNT(DISTINCT InvoiceNo) AS frequency,
      ROUND(SUM(Quantity * UnitPrice), 2) AS monetary
    FROM `tc-da-1.turing_data_analytics.rfm` rfm, date_param
    WHERE 1=1
      AND CustomerID IS NOT NULL
      AND InvoiceDate BETWEEN start_date AND end_date
      AND UnitPrice >= 0.01
      AND Quantity >= 1
    GROUP BY CustomerID, Country
),

-- Compute for R
t2 AS (
    SELECT 
      t1.*,
      DATE_DIFF(DATE(reference_date), last_purchase_date, DAY) AS recency
    FROM t1, date_param
),

-- Determine quartiles for RFM
t3 AS (
    SELECT 
       APPROX_QUANTILES(recency, 100)[OFFSET(25)] AS r25
      ,APPROX_QUANTILES(recency, 100)[OFFSET(50)] AS r50
      ,APPROX_QUANTILES(recency, 100)[OFFSET(75)] AS r75
      ,APPROX_QUANTILES(recency, 100)[OFFSET(100)] AS r100
      ,APPROX_QUANTILES(frequency, 100)[OFFSET(25)] AS f25
      ,APPROX_QUANTILES(frequency, 100)[OFFSET(50)] AS f50
      ,APPROX_QUANTILES(frequency, 100)[OFFSET(75)] AS f75
      ,APPROX_QUANTILES(frequency, 100)[OFFSET(100)] AS f100
      ,APPROX_QUANTILES(monetary, 100)[OFFSET(25)] AS m25
      ,APPROX_QUANTILES(monetary, 100)[OFFSET(50)] AS m50
      ,APPROX_QUANTILES(monetary, 100)[OFFSET(75)] AS m75
      ,APPROX_QUANTILES(monetary, 100)[OFFSET(100)] AS m100
    FROM t2
),

-- Assign scores for R F M
t4 AS (
    SELECT
      t2.*,
      CASE 
        WHEN monetary <= m25 THEN 1
        WHEN monetary <= m50 AND monetary > m25 THEN 2 
        WHEN monetary <= m75 AND monetary > m50 THEN 3 
        ELSE 4 
      END AS m_score,
      CASE 
        WHEN frequency <= f25 THEN 1
        WHEN frequency <= f50 AND frequency > f25 THEN 2 
        WHEN frequency <= f75 AND frequency > f50 THEN 3 
        ELSE 4 
      END AS f_score,
      CASE 
        WHEN recency <= r25 THEN 4
        WHEN recency <= r50 AND recency > r25 THEN 3 
        WHEN recency <= r75 AND recency > r50 THEN 2 
        ELSE 1 
      END AS r_score,
    FROM t2, t3
),

-- Cocatinate r, f & m scores
t5 AS (
    SELECT *,
      CONCAT(r_score, f_score, m_score) AS rfm
    FROM t4  
),

-- Define RFM segments
t6 AS (
    SELECT
      t5.*,
      CASE 
        WHEN rfm IN ('444', '344', '434', '443') THEN 'Champions' 
        WHEN rfm IN ('244', '334', '343', '424', '433', '442', '324') THEN 'Loyal Customers' 
        WHEN rfm IN ('333', '342', '423', '441', '323') THEN 'Potential Loyalist' 
        WHEN rfm IN ('414', '413', '422', '314', '313', '412', '421', '312', '411', '321', '311') THEN 'New Customers' 
        WHEN rfm IN ('432', '332', '341', '431', '322', '331') THEN 'Promising'
        WHEN rfm IN ('243', '234', '224', '233') THEN 'Customers Needing Attention'
        WHEN rfm IN ('242', '142', '223', '232', '241', '141', '213', '231') THEN 'At Risk'
        WHEN rfm IN ('144', '134', '143', '124', '133', '214', '114', '113') THEN "Can't Lose Them But Losing"
        WHEN rfm IN ('123', '132', '222', '122', '212', '221') THEN 'Hibernating'
        WHEN rfm IN ('131', '112', '121', '211', '111') THEN 'Lost' 
      END AS rfm_segment 
    FROM t5
)

SELECT * FROM t6








