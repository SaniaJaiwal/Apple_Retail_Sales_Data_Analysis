-- Creating Table Stores

DROP TABLE IF EXISTS Stores;
CREATE TABLE Stores(
	Store_ID VARCHAR(6) PRIMARY KEY,
	Store_Name VARCHAR(50),
	City VARCHAR(25),
	Country VARCHAR(25)
);

-- Creating Table Category

DROP TABLE IF EXISTS Category;
CREATE TABLE Category(
	Category_ID VARCHAR(6) PRIMARY KEY,
	Category_Name VARCHAR(50)
);

-- Creating Table Products

DROP TABLE IF EXISTS Products;
CREATE TABLE Products(
	Product_ID VARCHAR(6) PRIMARY KEY,
	Product_Name VARCHAR(50),
	Category_ID VARCHAR(6) REFERENCES Category(Category_ID),
	Launch_Date DATE,
	Price Numeric(10,2)
);

-- Creating Table Sales

DROP TABLE IF EXISTS Sales;
CREATE TABLE Sales(
	Sale_ID VARCHAR(15) PRIMARY KEY,
	Sale_Date DATE,
	Store_ID VARCHAR(6) REFERENCES Stores(Store_ID),
	Product_ID VARCHAR(6) REFERENCES Products(Product_ID),
	Quantity INT
);

-- Creating Table Warranty

DROP TABLE IF EXISTS Warranty;
CREATE TABLE Warranty(
	Claim_ID VARCHAR(15) PRIMARY KEY,
	Claim_Date DATE,
	Sale_ID VARCHAR(15) REFERENCES Sales(Sale_ID),
	Repair_Status VARCHAR(25)
);

SELECT * FROM Stores;
SELECT * FROM Category;
SELECT * FROM Products;
SELECT * FROM Sales;
SELECT * FROM Warranty;


-- EDA
-- Improving Query Performance

CREATE INDEX Sales_Store_ID ON Sales(Store_ID);
CREATE INDEX Sales_Product_ID ON Sales(Product_ID);
CREATE INDEX Sales_Sale_Date ON Sales(Sale_Date);

-- et: 165.740 ms
-- et after: 9.002 ms

EXPLAIN ANALYZE
SELECT * FROM Sales
WHERE Store_ID = 'ST-63';

-- et: 115.941 ms
-- et after: 6.096 ms

EXPLAIN ANALYZE
SELECT * FROM Sales
WHERE Product_ID = 'P-38';

-- et: 72.522 ms
-- et after: 0.738 ms

EXPLAIN ANALYZE
SELECT * FROM Sales
WHERE Sale_Date = '13-04-2022';


-- Basic Queries

-- 1. Find the number of stores in each country.

SELECT Country, COUNT(*) AS Number_of_Stores
FROM Stores
GROUP BY Country;

-- 2. Calculate the total number of units sold by each store.

SELECT s.Store_ID, st.Store_Name, SUM(s.Quantity) AS Total_Quantity
FROM Sales s
JOIN Stores st ON s.Store_ID = st.Store_ID
GROUP BY s.Store_ID, st.Store_Name;

-- 3. Identify how many sales occurred in December 2023.

SELECT COUNT(Sale_ID) AS Total_Sales
FROM Sales
WHERE Sale_Date BETWEEN '01-12-2023' AND '31-12-2023';

-- 4. Determine how many stores have never had a warranty claim filed.

SELECT Count(*) AS Stores_Without_Claims
FROM Stores 
WHERE Store_ID NOT IN (SELECT DISTINCT Store_ID FROM Sales s JOIN Warranty w ON s.Sale_ID = w.Sale_ID);

-- 5. Calculate the percentage of warranty claims marked as "Rejected".

SELECT ROUND(COUNT(Repair_Status) / (SELECT COUNT(*) FROM Warranty)::NUMERIC * 100, 2) AS Percentage
FROM Warranty
WHERE Repair_Status = 'Rejected';

-- 6. Identify which store had the highest total units sold in the year 2024.

SELECT st.Store_ID, st.Store_Name, TO_CHAR(s.Sale_Date, 'YYYY') AS Year, SUM(s.Quantity) AS Total_Quantity
FROM Stores st
JOIN Sales s ON st.Store_ID = s.Store_ID
WHERE s.Sale_Date >= '2024-01-01' AND s.Sale_Date <'2025-01-01'
GROUP BY st.Store_ID, st.Store_Name, Year
ORDER BY Total_Quantity DESC LIMIT 1;

-- 7. Count the number of unique products sold in the year 2024.

SELECT COUNT(DISTINCT Product_ID) AS Number_of_Unique_Products
FROM Sales
WHERE Sale_Date >= '2024-01-01' AND Sale_Date < '2025-01-01';

-- 8. Find the average price of products in each category.

SELECT c.Category_ID, c.Category_Name, ROUND(AVG (p.Price)::NUMERIC, 2) AS Average_Price
FROM Category c
JOIN Products p ON c.Category_ID = p.Category_ID
GROUP BY c.Category_ID, c.Category_Name;

-- 9. How many warranty claims were filed in August 2024?

SELECT COUNT(Claim_ID) AS Total_Claims
FROM Warranty
WHERE EXTRACT(YEAR FROM Claim_Date) = '2024' AND EXTRACT(MONTH FROM Claim_Date) = '8';

-- 10. For each store, identify the best-selling day based on highest quantity sold.

WITH Selling_Day AS(
	SELECT Store_ID, TO_CHAR(Sale_Date,'day') AS Day_Name,
	SUM(Quantity) AS Total_Quantity, 
	RANK() OVER (PARTITION BY Store_ID ORDER BY SUM(Quantity) DESC) AS RANK
	FROM Sales
	GROUP BY Store_ID, Day_Name
)
SELECT Store_ID, Day_Name, Total_Quantity FROM Selling_Day
WHERE RANK = 1
ORDER BY CAST(SUBSTRING(Store_ID FROM 4) AS INTEGER);

-- Advanced Queries

-- 11. Identify the least selling product in each country for each year based on total units sold.

WITH Selling_Product AS(
	SELECT st.Country, EXTRACT(YEAR FROM s.Sale_Date) AS Year, s.Product_ID, p.Product_Name,
	SUM(s.Quantity) AS Total_Quantity,
	RANK() OVER (PARTITION BY st.Country, EXTRACT(YEAR FROM s.Sale_Date) ORDER BY SUM(s.Quantity) ASC) AS RANK
	FROM Stores st
	JOIN Sales s ON st.Store_ID = s.Store_ID
	JOIN Products p ON s.Product_ID = p.Product_ID
	GROUP BY st.Country, s.Product_ID, p.Product_Name, Year
)

SELECT Country, Product_ID, Product_Name, Year, Total_Quantity FROM Selling_Product
WHERE RANK = 1;

-- 12. Calculate how many warranty claims were filed within 180 days of a product sale.

SELECT COUNT(*) AS warranty_claims_within_180_days
FROM Warranty w
JOIN Sales s
ON w.Sale_ID = s.Sale_ID
WHERE w.Claim_Date - s.Sale_Date <= 180 AND w.Claim_Date >= s.Sale_Date;

-- 13. Determine how many warranty claims were filed for products launched in the last two years (2023 and 2024).

SELECT COUNT(*) AS warranty_claims_in_last_two_years
FROM Warranty w
JOIN Sales s
ON w.Sale_ID = s.Sale_ID
JOIN Products p 
ON s.Product_ID = p.Product_ID
WHERE p.Launch_Date >= '2023-01-01' AND p.Launch_Date < '2025-01-01';

-- 14. List the months in the last three years (2022, 2023 and 2024) where sales exceeded 5,000 units in the USA.

SELECT st.country, TO_CHAR(s.sale_date, 'Month') AS Month, SUM(s.quantity) AS Total_units_sold
FROM stores st
JOIN sales s
ON st.store_id = s.store_id
WHERE st.country = 'United States'
AND s.Sale_Date >= '2022-01-01' AND s.Sale_Date < '2025-01-01'
GROUP BY st.country, Month
HAVING SUM(s.quantity) >= 5000;

-- 15. Identify the product category with the most warranty claims filed in the last two years (2023 and 2024).

SELECT c.Category_Name, COUNT(w.Claim_ID) AS Total_Claims
FROM Category c
JOIN Products p ON c.Category_ID = p.Category_ID
JOIN Sales s ON p.Product_ID = s.Product_ID
JOIN Warranty w ON s.Sale_ID = w.Sale_ID
WHERE s.Sale_Date >= '2023-01-01' AND s.Sale_Date < '2025-01-01'
GROUP BY c.Category_Name
ORDER BY COUNT(w.Claim_ID) DESC LIMIT 1;

-- 16. Determine the percentage chance of receiving warranty claims after each purchase for each country.

SELECT st.Country, 
ROUND((COUNT(DISTINCT w.Claim_ID) * 100) / NULLIF(COUNT(DISTINCT s.Sale_ID),0),2) AS Warranty_Claims_Percentage
FROM Stores st
JOIN Sales s  ON st.Store_ID = s.Store_ID
LEFT JOIN Warranty w ON s.Sale_ID = w.Sale_ID
GROUP BY st.Country
ORDER BY Warranty_Claims_Percentage DESC;

-- 17. Analyze the year-by-year growth ratio for each store.

WITH Yearly_Sales AS(
	SELECT st.Store_ID, st.Store_Name, TO_CHAR(s.Sale_Date, 'YYYY') AS Year,
	SUM(s.Quantity * p.price) AS Current_Year_Revenue,
	LAG(SUM(s.Quantity * p.price)) OVER (PARTITION BY st.Store_ID) AS Previous_Year_Revenue
	FROM Stores st
	RIGHT JOIN Sales s ON st.Store_ID = s.Store_ID
	JOIN Products p ON s.Product_ID = p.Product_ID
	GROUP BY st.Store_ID, st.Store_Name, Year
)

SELECT Store_ID, Store_Name, Year, Current_Year_Revenue, Previous_Year_Revenue,
COALESCE(Current_Year_Revenue - Previous_Year_Revenue) AS Difference,
ROUND(((Current_Year_Revenue - Previous_Year_Revenue)/NULLIF(Previous_Year_Revenue,0) * 100)::NUMERIC, 2) AS Percent_Growth_Ratio
FROM Yearly_Sales;

-- 18. Calculate the correlation between product price and warranty claims for products sold in the last five years (2020-2025), segmented by price range.

WITH Product_Claims AS (
	SELECT p.Product_ID, p.Price, SUM(s.Quantity) AS Total_Units_Sold,
	COUNT(w.Claim_ID) AS Total_Claims
	FROM Sales s
	JOIN Products p ON s.Product_ID = p.Product_ID
	LEFT JOIN Warranty w ON s.Sale_ID = w.Sale_ID
	WHERE s.Sale_Date >= '2020-01-01' AND s.Sale_Date < '2025-01-01'
	GROUP BY p.Product_ID, p.Price
),

Product_Price_Range AS (
	SELECT Product_ID, Price, Total_Units_Sold, Total_Claims,
		CASE 
			WHEN Price < 500 THEN 'Low Price'
			WHEN Price BETWEEN 500 AND 1000 THEN 'Moderate Price'
			WHEN Price BETWEEN 1001 AND 1500 THEN 'High Price'
			ELSE 'Expensive'
		END AS Price_Range
	FROM Product_Claims
)

SELECT Price_Range, ROUND(CORR(Price, Total_Claims)::Numeric, 2) AS Price_Claim_Correlation
FROM Product_Price_Range
GROUP BY Price_Range
ORDER BY Price_Claim_Correlation DESC;

-- 19. Identify the store with the highest percentage of "Rejected" claims relative to total claims filed.

WITH Rejected_Claims AS(
	SELECT s.Store_ID, st.Store_Name, COUNT(w.Claim_ID) AS Total_Claims, 
	COUNT(CASE WHEN w.repair_Status = 'Rejected' THEN 1 END) AS Total_Rejected_Claims
	FROM Stores st
	JOIN Sales s ON st.Store_ID = s.Store_ID
	JOIN Warranty w ON s.Sale_ID = w.Sale_ID
	GROUP BY s.Store_ID, st.Store_Name
)
SELECT Store_ID, Store_Name, Total_Claims, Total_Rejected_Claims,
ROUND((Total_Rejected_Claims::NUMERIC * 100)/Total_Claims::NUMERIC, 2) AS Rejected_Claims_Percentage
FROM Rejected_Claims
ORDER BY Rejected_Claims_Percentage DESC LIMIT 1;

-- 20. Write a query to calculate the monthly running total of sales for each store over the past four years(2021-2025) and compare trends during this period.

WITH Monthly_Sales AS (
	SELECT s.Store_ID, st.Store_Name, DATE_TRUNC('Month', s.Sale_Date) AS Month, SUM(p.Price * s.Quantity) AS Monthly_Revenue
	FROM Stores st
	JOIN Sales s ON st.Store_ID = s.Store_ID
	JOIN Products p ON s.Product_ID = p.Product_ID
	WHERE s.Sale_Date >= '2021-01-01' AND s.Sale_Date < '2025-01-01'
	GROUP BY s.Store_ID, st.Store_Name, Month
)

SELECT Store_ID, Store_Name, TO_CHAR(Month, 'Mon YYYY') AS Month_Year, Monthly_Revenue, 
SUM(Monthly_Revenue) OVER (PARTITION BY Store_ID ORDER BY Month) AS Running_Total
FROM Monthly_Sales;

-- 21. Analyze product sales trends over time, segmented into key periods: from launch to 6 months, 6-12 months, 12-18 months, and beyond 18 months.

WITH Product_Sales_With_Period AS (
	SELECT s.Product_ID, p.Product_Name, s.Sale_Date, SUM(p.Price * s.Quantity) AS Revenue,
	(DATE_PART('year', AGE(s.sale_date, p.launch_date)) * 12 + DATE_PART('month', AGE(s.sale_date, p.launch_date))) AS months_since_launch
	FROM Sales s
	JOIN Products p ON s.Product_ID = p.Product_ID 
	GROUP BY s.Product_ID, p.Product_Name, s.Sale_Date, months_since_launch
)

SELECT Product_ID, Product_Name, 
CASE
	WHEN months_since_launch < 6 THEN '0-6 Months'
	WHEN months_since_launch < 12 THEN '6-12 Months'
	WHEN months_since_launch < 18 THEN '12-18 Months'
	ELSE 'Beyond 18 Months'
END AS Sales_Periods,
SUM(Revenue) AS Total_Revenue,
ROUND((SUM(Revenue)/ COUNT(DISTINCT Sale_Date))::NUMERIC, 2) as Avg_Revenue
FROM Product_Sales_With_Period
GROUP BY Product_ID, Product_Name, Sales_Periods
ORDER BY Product_ID, Total_Revenue desc;
