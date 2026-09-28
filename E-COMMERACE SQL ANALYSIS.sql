CREATE TABLE customers (
    Customer_ID VARCHAR(50),
    Customer_Name VARCHAR(50),
    Gender VARCHAR(20),
    Age INT,
    Age_Group VARCHAR(20),
    Date_of_Birth DATE,
    Email VARCHAR(100),
    Phone VARCHAR(20),
    City VARCHAR(50),
    State VARCHAR(50),
    Pincode INT,
    Registration_Date DATE,
    Customer_Tier VARCHAR(50),
    Total_Orders INT,
    Total_Spent NUMERIC(12,2)
);
CREATE TABLE product (
    Product_ID VARCHAR(50),
    Product_Name VARCHAR(100),
    Category VARCHAR(50),
    Brand VARCHAR(50),
    Original_Price NUMERIC(12,2),
    Discount_Percent NUMERIC(5,2),
    Discount_Amount NUMERIC(12,2),
    Selling_Price NUMERIC(12,2),
    Stock_Quantity INT,
    Weight_kg NUMERIC(8,2),
    Avg_Rating NUMERIC(3,2),
    Total_Reviews INT
);
CREATE TABLE sales (
    Order_ID VARCHAR(50),
    Customer_ID VARCHAR(50),
    Product_ID VARCHAR(50),
    Order_Date DATE,
    Order_Time TIME,
    Delivery_Date DATE,
    Quantity INT,
    Unit_Price NUMERIC(12,2),
    Order_Value NUMERIC(12,2),
    Shipping_Cost NUMERIC(10,2),
    Coupon_Code VARCHAR(50),
    Coupon_Discount NUMERIC(10,2),
    Total_Amount NUMERIC(12,2),
    Payment_Mode VARCHAR(50),
    Order_Status VARCHAR(50),
    Rating NUMERIC(3,2),
    Review_Text TEXT,
    City VARCHAR(50),
    State VARCHAR(50),
    Customer_Age INT,
    Customer_Age_Group VARCHAR(20)
);
--Busniess problem analysis
--Q. Which state have high canacellation reates ?
select state ,
count(*) as total_orders,
sum(
   case
    when Order_Status ='Cancelled' then 1 
	else 0
  END) Cancelled_Orders,
ROUND(
100* sum(
   case
    when Order_Status ='Cancelled' then 1 
	else 0
 END)/count(*),2
)as cancellation_rate
from sales 
group by state
order by cancellation_rate dESC;

--Q.Which product genrates most revenue?
select p.Product_name,
sum(p.Selling_price*s.Quantity) as Total_Revenue 
from sales s
join product p
on s.Product_ID = p.Product_ID
group by Product_name
order by Total_Revenue desc;

--Q.Which product have high ratings but low sales?
select p.product_name,
p.Avg_Rating ,
sum(s.Quantity) as Total_units_sold,
sum(s.Total_Amount) as Total_revenue
from product p
join sales s
on s.Product_ID = p.Product_ID
GROUP BY p.product_name,
p.Avg_Rating
order by
p.Avg_Rating desc,
Total_units_sold asc;

--Q Does higher discounting corrospond to higher quantity to sold?
SELECT
    CASE
        WHEN p.Discount_Percent < 10 THEN 'Low Discount'
        WHEN p.Discount_Percent < 25 THEN 'Medium Discount'
        WHEN p.Discount_Percent < 50 THEN 'High Discount'
        ELSE 'Very High Discount'
    END AS Discount_Category,

    SUM(s.Quantity) AS Total_Units_Sold,
    SUM(s.Total_Amount) AS Total_Revenue

FROM product p
JOIN sales s
    ON p.Product_ID = s.Product_ID

GROUP BY
    CASE
        WHEN p.Discount_Percent < 10 THEN 'Low Discount'
        WHEN p.Discount_Percent < 25 THEN 'Medium Discount'
        WHEN p.Discount_Percent < 50 THEN 'High Discount'
        ELSE 'Very High Discount'
    END

ORDER BY Total_Units_Sold DESC;

--Q Which categories receive highest discounts?
select category ,
sum(discount_amount)as total_discount
from product 
group by category 
order by total_discount desc ;

--Q Are Highly discounted products actually genrating more revenue?
select p.product_name,
p.discount_percent,
sum(p.discount_amount) as total_discount ,
sum(s.Quantity * p.Selling_price) as total_revenue
from product p 
join sales s 
on s.ProducT_ID = p.Product_ID
GROUP BY p.product_name,
p.discount_percent
order by p.discount_percent desc;

-- =========================================================
-- RFM CUSTOMER SEGMENTATION
-- STEP 1: Remove old RFM table if it already exists
DROP TABLE IF EXISTS rfm;
-- STEP 2: Create RFM table
CREATE TABLE rfm AS
WITH customer_rfm AS (
    SELECT
        Customer_ID,
 -- Recency:
 -- Number of days since the customer's last purchase
        (
            MAX(MAX_DATE) - MAX(Order_Date)
        ) AS Recency,

-- Frequency:
-- Number of unique orders
        COUNT(DISTINCT Order_ID) AS Frequency,
-- Monetary:
-- Total amount spent
        SUM(Total_Amount) AS Monetary

    FROM (
        SELECT
            Customer_ID,
            Order_ID,
            Order_Date,
            Total_Amount,
            MAX(Order_Date) OVER () + 1 AS MAX_DATE
        FROM sales
        WHERE LOWER(Order_Status) = 'delivered'
    ) t

    GROUP BY Customer_ID
)

SELECT *
FROM customer_rfm;


-- STEP 3: Add RFM score columns

ALTER TABLE rfm
ADD COLUMN R_Score INT,
ADD COLUMN F_Score INT,
ADD COLUMN M_Score INT,
ADD COLUMN RFM_Score INT,
ADD COLUMN Customer_Segment VARCHAR(30);

-- STEP 4: Calculate R, F and M scores

WITH scores AS (

    SELECT
        Customer_ID,
 -- Lower Recency = better
 -- Therefore reverse the Recency ranking
        6 - NTILE(5) OVER (
            ORDER BY Recency
        ) AS R_Score,
-- Higher Frequency = better
        NTILE(5) OVER (
            ORDER BY Frequency
        ) AS F_Score,
-- Higher Monetary = better
        NTILE(5) OVER (
            ORDER BY Monetary
        ) AS M_Score

    FROM rfm
)

UPDATE rfm AS r

SET
    R_Score = s.R_Score,
    F_Score = s.F_Score,
    M_Score = s.M_Score,

    RFM_Score =
        s.R_Score +
        s.F_Score +
        s.M_Score

FROM scores AS s

WHERE r.Customer_ID = s.Customer_ID;


-- STEP 5: Create customer segments

UPDATE rfm

SET Customer_Segment =
    CASE

        WHEN RFM_Score >= 13
            THEN 'Champions'

        WHEN RFM_Score >= 10
            THEN 'Loyal Customers'

        WHEN RFM_Score >= 7
            THEN 'Potential Loyal'

        WHEN RFM_Score >= 5
            THEN 'At Risk'

        ELSE 'Lost Customers'

    END;


-- STEP 6: View the final RFM table

SELECT *
FROM rfm
ORDER BY RFM_Score DESC;

--Q  How many customers are in each segment?
SELECT
    Customer_Segment,
    COUNT(*) AS Number_of_Customers
FROM rfm
GROUP BY Customer_Segment
ORDER BY Number_of_Customers DESC;

--2.Which segment generates the most revenue?
SELECT
    Customer_Segment,
    SUM(Monetary) AS Total_Revenue
FROM rfm
GROUP BY Customer_Segment
ORDER BY Total_Revenue DESC;

--Q Which customers are at risk?
SELECT
    Customer_ID,
    Recency,
    Frequency,
    Monetary,
    RFM_Score
FROM rfm
WHERE Customer_Segment = 'At Risk'
ORDER BY RFM_Score ASC;

--Q Which customer segments buy which categories?
SELECT
    r.Customer_Segment,
    p.Category,
    SUM(s.Quantity) AS Total_Units_Sold,
    SUM(s.Total_Amount) AS Total_Revenue
FROM sales s

JOIN rfm r
    ON s.Customer_ID = r.Customer_ID

JOIN product p
    ON s.Product_ID = p.Product_ID

WHERE LOWER(s.Order_Status) = 'delivered'

GROUP BY
    r.Customer_Segment,
    p.Category

ORDER BY
    r.Customer_Segment,
    Total_Revenue DESC;