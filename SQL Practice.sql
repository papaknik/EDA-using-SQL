/* We begin by examining the columns' data types for the tables to ensure that
the data is correctly formatted and to understand the structure of the dataset. This step
is crucial for validating data integrity and preparing for subsequent analysis. */
   
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'orders';

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'details';

/* Next, we check for missing values in the columns of both tables. This will help us identify
any gaps in the dataset that need to be addressed before proceeding with the analysis. */

-- Check for missing values in the orders table
SELECT
COUNT(*) AS total_rows,
COUNT(order_id) AS non_null_order_id,
COUNT(customername) AS non_null_customername,
COUNT(state) AS non_null_state,
COUNT(city) AS non_null_city
FROM orders;

-- Check for missing values in the details table
SELECT
COUNT(*) AS total_rows,
COUNT(order_id) AS non_null_order_id,
COUNT(amount) AS non_null_amount,
COUNT(quantity) AS non_null_quantity,
COUNT(profit) AS non_null_profit,
COUNT(sub_category) AS non_null_sub_category
FROM details;
--No NULL values were found in the tables

/* Check for orphan records in the details table: 
   Orders in the details table that do not have a corresponding entry in the orders table. */
SELECT COUNT(*)
FROM details d
LEFT JOIN orders o ON d.order_id = o.order_id
WHERE o.order_id IS NULL;

/* Check for orphan records in the orders table: 
   Orders in the orders table that do not have a corresponding entry in the details table. */
SELECT COUNT(*)
FROM orders o
LEFT JOIN details d ON o.order_id = d.order_id
WHERE d.order_id IS NULL;


/* List the states along with their corresponding total amount of orders made, from highest to
lowest*/
SELECT 
o.state, sum(d.amount) as total_amount
FROM details as d
INNER JOIN orders as o
ON d.order_id = o.order_id
GROUP BY state
ORDER BY total_amount DESC;

/* Find the customer with the highest total amount of order, along with his/her order_id, state 
and city*/
WITH order_totals AS (
    SELECT 
        o.order_id,
        SUM(d.amount) AS total_amount
    FROM orders AS o
    INNER JOIN details AS d 
    ON o.order_id = d.order_id
    GROUP BY o.order_id
),
max_order AS (
    SELECT 
        order_id
    FROM order_totals
    WHERE total_amount = (SELECT MAX(total_amount) FROM order_totals)
)
SELECT 
    o.order_id, 
    o.customername, 
    SUM(d.amount) as total_amount, 
    o.state, 
    o.city
FROM details AS d
INNER JOIN orders AS o 
ON d.order_id = o.order_id
INNER JOIN max_order AS mo
ON o.order_id = mo.order_id
GROUP BY o.order_id, o.customername, o.state, o.city;

-- Find the top 3 most profitable customers in each state
WITH customers_profit AS (
    SELECT
        o.state,
        o.city,
        o.customername,
        SUM(d.profit) AS total_profit
    FROM orders AS o
    INNER JOIN details AS d
    ON o.order_id = d.order_id
    GROUP BY o.state, o.city, o.customername
),
ranked_customers AS (
    SELECT
        state,
        city,
        customername,
        total_profit,
        DENSE_RANK() OVER (PARTITION BY state ORDER BY total_profit DESC) AS profit_rank
    FROM customers_profit
)
SELECT
    state,
    city,
    customername,
    total_profit
FROM ranked_customers
WHERE profit_rank <= 3
ORDER BY state, city, profit_rank;

-- List the top 5 cities with the highest volume of orders
SELECT 
city, count(order_id) as no_of_orders
FROM orders
GROUP BY city
ORDER BY no_of_orders DESC
LIMIT 5;

-- Which state appears to be the most profitable? List it along with the least profitable state
WITH states_profit AS (
		SELECT o.state, SUM(d.profit) AS total_profit
		FROM details AS d
		INNER JOIN orders AS o
		ON d.order_id = o.order_id
    	GROUP BY o.state
)
SELECT s.state, s.total_profit
FROM states_profit AS s
WHERE s.total_profit = (SELECT MAX(total_profit) FROM states_profit)
   OR s.total_profit = (SELECT MIN(total_profit) FROM states_profit);


/* Which subcategories of products appear as the top 10 Sellers, with rescept to the volume of
orders(total quantity of products)? List them along with their total profit*/
SELECT 
sub_category, sum(quantity) as order_volume, sum(profit) as total_profit
FROM details
GROUP BY sub_category
ORDER BY order_volume DESC
LIMIT 10;

/* It seems that something went probably wrong in the 'Electronic Games' and 'Furnishings' 
subcategories. Let's compare the average profits for this top 10*/
SELECT 
sub_category, ROUND(AVG(profit), 2) AS avg_profit
FROM details
WHERE sub_category IN (
    SELECT sub_category
    FROM (
        SELECT sub_category
        FROM details
        GROUP BY sub_category
        ORDER BY SUM(quantity) DESC
        LIMIT 10
    ) AS top_subcategories
)
GROUP BY sub_category
ORDER BY avg_profit DESC;

/* Among the top 10 subcategory sellers, only 'Electronic Games' and 'Furnishings' exhibit a 
negative average profit, indicating an average operational loss. Aggressive discounts, 
sell-offs on specific titles within these subcategories could be a reasonable cause. Further 
investigation is needed to review the pricing policy and promotional tactics. Adjustments should
be considered to avoid similar issues in the future. */

	-- Which payment method is more popular in total?
CREATE VIEW payment_method_frequencies AS
WITH payments_table AS (
    SELECT 
		d.order_id,
        paymentmode,
        CASE WHEN paymentmode = 'COD' THEN 'Cash' ELSE NULL END AS cash_method,
        CASE WHEN paymentmode = 'Credit Card' THEN 'Credit Card' ELSE NULL END AS credit_card,
        CASE WHEN paymentmode = 'UPI' THEN 'UPI' ELSE NULL END AS web_payment,
        CASE WHEN paymentmode = 'Debit Card' THEN 'Debit Card' ELSE NULL END AS debit_card,
        CASE WHEN paymentmode = 'EMI' THEN 'EMI' ELSE NULL END AS monthly_instalments
    FROM details as d
)
SELECT 
	order_id,
    COUNT(paymentmode) AS no_of_transcations,
    ROUND(COUNT(cash_method) * 100.0 / COUNT(*), 2) AS cash_percentage,
    ROUND(COUNT(credit_card) * 100.0 / COUNT(*), 2) AS credit_card_percentage,
    ROUND(COUNT(web_payment) * 100.0 / COUNT(*), 2) AS web_payment_percentage,
    ROUND(COUNT(debit_card) * 100.0 / COUNT(*), 2) AS debit_card_percentage,
    ROUND(COUNT(monthly_instalments) * 100.0 / COUNT(*), 2) AS monthly_instalments_percentage
FROM payments_table
GROUP BY order_id;

SELECT round(avg(cash_percentage), 2) as cash_percentage, 
round(avg(credit_card_percentage), 2) as credit_card_percentage,
round(avg(web_payment_percentage), 2) as web_payment_percentage, 
round(avg(debit_card_percentage), 2) as debit_card_percentage, 
round(avg(monthly_instalments_percentage), 2) as monthly_instalments_percentage
FROM payment_method_frequencies;

/* Nearly half of the transactions are performed in cash, with the second most popular method 
being web payments(likely through mobile or internet banking), at around 22%. */

-- Does the payment method frequency change across the states and cities?
SELECT 
    o.state, 
    ROUND(AVG(m.cash_percentage),2) AS cash_percentage,
    ROUND(AVG(m.credit_card_percentage),2) AS credit_card_percentage,
    ROUND(AVG(m.web_payment_percentage),2) AS web_payment_percentage,
    ROUND(AVG(m.debit_card_percentage),2) AS debit_card_percentage,
    ROUND(AVG(m.monthly_instalments_percentage),2) AS monthly_instalments_percentage 
FROM orders AS o
INNER JOIN payment_method_frequencies AS m
ON o.order_id = m.order_id
GROUP BY o.state;

/* There appears to be a significant variation in payment methods across different states. 
This can be quantified by calculating the standard deviation, as well as the minimum and 
maximum average percentages for each payment method across the states. */

WITH state_averages AS (
    SELECT 
        o.state,
        AVG(m.cash_percentage) AS avg_cash_p,
        AVG(m.credit_card_percentage) AS avg_credit_card_p,
        AVG(m.web_payment_percentage) AS avg_web_payment_p,
        AVG(m.debit_card_percentage) AS avg_debit_card_p,
        AVG(m.monthly_instalments_percentage) AS avg_monthly_instalments_p
    FROM orders AS o
    INNER JOIN payment_method_frequencies AS m
    ON o.order_id = m.order_id
    GROUP BY o.state
)
SELECT 
    ROUND(STDDEV(avg_cash_p), 2) AS std_cash_p,
    ROUND(MIN(avg_cash_p), 2) AS min_cash_p,
    ROUND(MAX(avg_cash_p), 2) AS max_cash_p,
    ROUND(STDDEV(avg_credit_card_p), 2) AS std_credit_card_p,
    ROUND(MIN(avg_credit_card_p), 2) AS min_credit_p,
    ROUND(MAX(avg_credit_card_p), 2) AS max_credit_card_p,
    ROUND(STDDEV(avg_web_payment_p), 2) AS std_web_payment_p,
    ROUND(MIN(avg_web_payment_p), 2) AS min_web_payment_p,
    ROUND(MAX(avg_web_payment_p), 2) AS max_web_payment_p,
    ROUND(STDDEV(avg_debit_card_p), 2) AS std_debit_card_p,
    ROUND(MIN(avg_debit_card_p), 2) AS min_debit_card_p,
    ROUND(MAX(avg_debit_card_p), 2) AS max_debit_card_p,
    ROUND(STDDEV(avg_monthly_instalments_p), 2) AS std_monthly_instalments_p,
    ROUND(MIN(avg_monthly_instalments_p), 2) AS min_monthly_instalments_p,
    ROUND(MAX(avg_monthly_instalments_p), 2) AS max_monthly_instalments_p
FROM state_averages;

/* There is a significant variation in all payment methods across the states. Additional data 
related to demographics and financial status of every state and its residents is needed if we 
wish further granularity*/

/* Do the product categories also affect payment methods. Let see how the payment methods
ratios are distributed across the product categories*/
SELECT d.category,
       COUNT(m.order_id) AS total_orders,
       ROUND(AVG(m.cash_percentage), 2) AS avg_cash_percentage,
       ROUND(AVG(m.credit_card_percentage), 2) AS avg_credit_card_percentage,
       ROUND(AVG(m.web_payment_percentage), 2) AS avg_web_payment_percentage,
       ROUND(AVG(m.debit_card_percentage), 2) AS avg_debit_card_percentage,
       ROUND(AVG(m.monthly_instalments_percentage), 2) AS avg_monthly_instalments_percentage
FROM payment_method_frequencies AS m
INNER JOIN details AS d
ON m.order_id = d.order_id
GROUP BY d.category
ORDER BY d.category;

/* No significant difference is observed in the average percentage of payment methods across
the different categories of products. */

-- Could the amount of order affect the choice of payment method used?
SELECT
    CASE
        WHEN d.amount < 100 THEN 'Small'
        WHEN d.amount BETWEEN 100 AND 1000 THEN 'Medium'
        ELSE 'High'
    END AS amount_category,
    COUNT(m.order_id) AS total_orders,
    ROUND(AVG(m.cash_percentage), 2) AS avg_cash_percentage,
    ROUND(AVG(m.credit_card_percentage), 2) AS avg_credit_card_percentage,
    ROUND(AVG(m.web_payment_percentage), 2) AS avg_web_payment_percentage,
    ROUND(AVG(m.debit_card_percentage), 2) AS avg_debit_card_percentage,
    ROUND(AVG(m.monthly_instalments_percentage), 2) AS avg_monthly_instalments_percentage
FROM payment_method_frequencies AS m
INNER JOIN details AS d
ON m.order_id = d.order_id
GROUP BY amount_category
ORDER BY amount_category;

/* The results are interesting but somewhat anticipated. 
As the order amount increases, the use of cash payments decreases. 
Conversely, credit card usage increases with higher order amounts, becoming a more preferred 
method. 
Debit cards and web payments show minimal changes for small and medium amounts but slightly 
decline for higher amounts. 
Finally, the need for and use of monthly instalments nearly triples when the order amount 
becomes very high. */

-- Rank the top 5 customers in each state from the most to lease profitable ones
WITH RankedCustomers AS (
    SELECT 
        customername, 
        state, 
        profit,
        DENSE_RANK() OVER (PARTITION BY state ORDER BY profit DESC) AS profit_rank
    FROM orders AS o
    INNER JOIN details AS d
    ON o.order_id = d.order_id
)
SELECT 
customername, state, profit, profit_rank
FROM RankedCustomers
WHERE profit_rank <= 5
ORDER BY state, profit_rank;

-- How has the profit evolved throughout the year, quarter by quarter?
WITH quarter_profit AS (
    SELECT
        EXTRACT(QUARTER FROM TO_DATE(order_date, 'DD-MM-YYYY')) AS quarter,
        SUM(profit) AS total_quarter_profit
    FROM details AS d
    INNER JOIN orders AS o
    ON d.order_id = o.order_id
    GROUP BY
        EXTRACT(QUARTER FROM TO_DATE(order_date, 'DD-MM-YYYY'))
),
cumulative_profits AS (
    SELECT 
        quarter,
        total_quarter_profit,
        SUM(total_quarter_profit) OVER (ORDER BY quarter) AS cumulative_quarter_profit
    FROM quarter_profit
)
SELECT
quarter, total_quarter_profit, cumulative_quarter_profit
FROM cumulative_profits
ORDER BY quarter;

/* The first quarter significantly impacts overall profitability, accounting for about  70% of 
the total profit. Profitability declines in the second quarter and turns into a loss in the 
third quarter. The company returns to profitability in the fourth quarter. Without more 
information/data about the company's main activity, we cannot explore the causes of this
seasonality further. Also diving deeper and computing the company's result over time across all
19 states will not be an easy task without the aid of visualisaztions. 
One more think we can do is to check monthly profit trends and examine how profitability 
varies across different product categories.*/

-- How has the profit of the company evolved during the year, month by month? 
WITH MonthlyProfits AS (
    SELECT
        EXTRACT(MONTH FROM TO_DATE(order_date, 'DD-MM-YYYY')) AS month,
        SUM(profit) AS total_monthly_profit
    FROM orders AS o
    INNER JOIN details AS d
    ON o.order_id = d.order_id
    GROUP BY EXTRACT(MONTH FROM TO_DATE(order_date, 'DD-MM-YYYY'))
),
CumulativeProfits AS (
    SELECT
        month,
        total_monthly_profit,
        SUM(total_monthly_profit) OVER (ORDER BY month) AS cumulative_profit
    FROM MonthlyProfits
)
SELECT
month, total_monthly_profit, cumulative_profit
FROM CumulativeProfits
ORDER BY month;

/* During the months of May, July, September, and December, the company produced a negative
result(loss). Let's move one step down and see what happened during these months. */
SELECT 
SUM(profit) AS total_profit, category
FROM details AS d
INNER JOIN orders AS o 
ON d.order_id = o.order_id
WHERE EXTRACT(MONTH FROM TO_DATE(order_date, 'DD-MM-YYYY')) IN (5, 7, 9, 12)
GROUP BY category;

/*The result of the above query indicates a severe loss impact associated with the 'Electronics'
category. This issue has been previously identified in earlier queries. A detailed investigation
into this category is recommended to address the underlying causes and develop targeted 
strategies for improvement.


/* Based on the exploratory data analysis, we recommend the following business proposals:
Re-evaluate Pricing Policy: Conduct a thorough assessment of the current pricing strategy to
ensure alignment with profitability objectives. Consider adjusting pricing structures to 
improve margins.
Adjust Promotional Campaigns: Review and optimize promotional strategies, with particular 
attention to discount practices. Ensure that discount strategies are effective in attracting
customers while maintaining profitability.
Promote Non-Cash Payment Methods: Increase efforts to promote non-cash payment methods, which
are associated with higher order amounts. This could involve providing incentives for using
credit cards, web payments, or monthly installments.*/



