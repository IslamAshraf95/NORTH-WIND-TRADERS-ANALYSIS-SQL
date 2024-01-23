--Extract Month and Year from ORDER DATE
Alter table orders add order_Month  varchar(50)
Alter table orders add order_Year  varchar(50)


update orders 
set order_Month = FORMAT (CONVERT(DATE, orderdate),'MM-yy')
update orders 
set order_Year = FORMAT (CONVERT(DATE, orderdate),'yyyy')

select * from order_details
select * from orders

--Total cost (product price X Quantity )- discount = Gross Revenue

Alter table order_details add Total_Cost  money

update order_details 
set Total_cost=(unitprice-(unitprice*discount))*quantity

select * from order_details 

-------------------------------------------------------------------
-------------------------------------------------------------------

--CUSTOMER DISTRIBUTION
--Frist step is to extract the best Market countries and cities
--count customers per CITY OR COUNTRY

create or alter proc customer_count
	@type varchar(50)
as
		if @type ='city'
		select c.city,count(distinct c.[companyName]) as 'CUST Count',sum (od.Total_Cost) as Total_sales
		from order_details od join orders o
		on o.orderID =od.orderID
		join customers c
		on c.customerID=o.customerID
		group by c.city
		order by Total_sales desc
	else if @type= 'country'
			select c.country,count(distinct c.[companyName]) as 'CUST_Count',sum (od.Total_Cost) as Total_sales
			from order_details od join orders o
			on o.orderID =od.orderID
			join customers c
			on c.customerID=o.customerID
			group by c.country
			order by CUST_Count desc
	

customer_count @type='City'
customer_count @type='country'

--It seems that USA, Germany and France have The hieghst num of customers

--Sales per country
-------

select c.country,avg(o.freight)as avg_ship,sum (od.Total_Cost) as Total_sales
from order_details od join orders o
on o.orderID =od.orderID
join customers c
on c.customerID=o.customerID
group by c.country
order by Total_sales desc
--USA, Germany and Austria represents best markets with sales as 
--((245584.6105) fro USA,230284.6335 for Germany and 128003.8385 for Austria
--Prioritize markets based on total sales, giving special attention 
--to the USA, Germany, Austria, and Brazil.

--------------------------------
--Most popular category in best market countries 
create or alter proc cat_country
as
WITH RankedSales AS (
    SELECT
		c.customerID,
(select sum (odr.Total_Cost) as Total_sales
from order_details odr join orders oo
on oo.orderID =odr.orderID
join customers cs
on cs.customerID=oo.customerID
where c.country =cs.country

) as Tatal_sales,
        c.country,
        cr.categoryName,
        SUM(od.Total_cost) AS total_cat_sales,
        RANK() OVER (PARTITION BY c.country ORDER BY SUM(od.Total_cost) DESC) AS sales_rank
    FROM
        customers c
        JOIN orders o ON c.customerid = o.customerid
        JOIN order_details od ON o.orderid = od.orderid
        JOIN products p ON od.productid = p.productid
        JOIN categories cr ON cr.categoryID = p.categoryID
    GROUP BY
        c.country, cr.categoryName,c.customerID
)

SELECT
	Tatal_sales,
    country,
	total_cat_sales,
    categoryName AS best_category
    ,(total_cat_sales / sum(Tatal_sales) OVER (PARTITION BY country)) * 100 AS percentage_of_sales
FROM
    RankedSales rs
WHERE
    sales_rank = 1
order by Tatal_sales desc

cat_country

--After this analysis we can identify best selling category in best market countries 
--Germany's ((2nd Best market)) best category is "Beverages" accounting for 15.72% of total sales.
--Austria's top category is "Dairy Products," with a significant contribution of 19.13%.
--we can pay attention to promote these category in best markets
-------------
--Small numbers in France and UK means that these markets 
--have varying preferences for product categories

--we can notice that France is the 3rd in customer number and have varying preferences

----------------------------------------------------------------------


--count customers per SPECIFIED CITY OR COUNTRY
create or alter proc customers_count_spec

	@type varchar(50),
	@city_country varchar(50)
	as
	begin
	if @type ='city'
		select city,count(*) as 'Customer_count'
		from [dbo].[customers]
		group by city
		having city=@city_country
	else if @type= 'country'
		select country,count(*) as 'Customer_count'
		from [dbo].[customers]
		group by country
		having country= @city_country

		end

customers_count_spec @type='country',@city_country='mexico'
--This is used to know num of customers in PECIFIED CITY OR COUNTRY
---------------------------------------------------------------



--key customer 

--we can inform decision-making around creating targeted  offers or promotions 
--to incentivize these customers to make additional purchases

--Customer Rank per Orders & Sales
--this query will show FREQUENCY baes on num of orders and Monetary absed on total sales

select c.companyName,c.country ,COUNT(o.orderID) as Total_Orders,
SUM(od.Total_Cost) as Total_revenue
from orders o
join customers c
on c.customerID=o.customerID
join order_details od
on od.orderID=o.orderID
group by c.companyName,c.country
order by Total_revenue desc
--order by Total_Orders desc

--QUICK-Stop, Ernst Handel and Save-a-lot Markets are the most paying clients
--with total revenue 110277.305, 104874.9785 and 104361.95 

-- Save-a-lot Markets, Ernst Handel and QUICK-Stop are most ordering clients 

-- Calculating Recency -- the time from the last order for each company
select
    c.customerid,c.[companyName],
    max(o.orderDate) AS last_transaction_date,
    datediff(month, max(o.orderDate), getdate()) as recency_month
from
    orders o
	join [dbo].[customers] c
	on c.customerID=o.customerID
group by 
    c.customerid,c.companyName
order by recency_month
-----------------------------------------------

create or alter proc Customer_Segmentation
as
--calculating RFM (Recency,FREQUENCY,Monetary) 
with RFM as(
select c.customerId, [companyName],
    (datediff(month, max(o.orderDate), getdate()) ) as Recency,
	COUNT(o.orderID) as Total_Orders,
	SUM(od.Total_Cost) as Total_revenue

from orders o join customers c
on c.customerID=o.customerID

join order_details od
on od.orderID=o.orderID
group by 
    c.customerid,c.companyName
),
--select * from RFM;

 RFM_Score as(
select customerId, [companyName],
--NTILE(5)over ( order by Total_revenue  desc) as Monetary,
NTILE(5)over ( order by Recency  desc) as Recency,
NTILE(5)over ( order by Total_Orders  desc,Total_revenue desc) as F_M_score
from RFM
)
--select * from RFM_Score

select * ,
case 
		WHEN Recency > 3 AND F_M_score >3 THEN 'A-Super Customer'
        WHEN Recency >= 3 AND F_M_score >= 2 THEN 'B-Loyal Customers'
        WHEN Recency = 5 AND F_M_score = 1 THEN 'C-Recent Customers'
        WHEN Recency >= 3 AND F_M_score = 1 THEN 'E-Promising'
        WHEN Recency >= 2 AND F_M_score >= 2 THEN 'F-Customers Needing Attention'
        WHEN Recency <= 2 AND F_M_score >= 3 THEN 'G-At Risk'
        WHEN Recency = 1 AND F_M_score > 3 THEN 'H-Can''t Lose Them'
        WHEN Recency <= 2 AND F_M_score <= 2 THEN 'I-Lost'
end as Segment
from RFM_score 
order by Segment



customer_segmentation

--Recency, frequency, Monetary


--The volume of sales for each company over a period of 3 years

select  *
from (
    select  c.companyName ,sum(od.Total_Cost)as totalCost,o.Order_year
    from orders o
    join customers c on c.customerID = o.customerID
	join order_details od
	on od.orderID=o.orderID
	group by c.companyName,o.Order_year
	--order by totalCost desc
) as Sourcetable

pivot (
    sum (totalCost) for Order_year IN ([2013], [2014], [2015])
) as Pivottable
--where [2015]>[2014] 
order by [2015]desc,[2014]desc,[2013]desc

--We can notice customers with positive growth 
--EX:Ernst Handel,QUICK-Stop,Save-a-lot Markets

--Companies with Negative Growth:
--Great Lakes Food Market,LINO-Delicateses,France restauration


-----------------------------------------------------------
--PRUDCTS--ORDERS
--------------------------------------------------------------
--Total Revenue---Gross Revenue
select  sum (Total_Cost) as Gross_revenue
from order_details
--1265793.0395
---------------------------------------------------------------
--AVerage revenue per order
select  avg (Total_Cost) as avg_Revenue_perOrder
from order_details
--587.3749
------------------------------------------------------------------------------------

select country ,count(*) as Num_of_Orders
from customers c join orders od
on od.[customerID]=c.customerID
group by country
order by Num_of_Orders desc

--Germany	122 ,USA	122,Brazil	83 ,France	77
--These countries have the most order numbers 
--So we can Provide best ship cost

--products with the highest and lowest sales.

create or alter proc trendy_product 
@n int, 
@analysis varchar(20)
as
	if @analysis ='Less'
		select *
		from (
		select 
		rank() over (order by sum(od.Total_cost) asc) AS Salesrank,
		p.ProductID,
        p.ProductName,
        sum(od.Total_cost) AS Totalsales 
   
		from products p
		join order_details od
		on od.productID=p.productID
		group by p.ProductID,p.ProductName
		) as rank_view

		where rank_view.Salesrank <=@n

	else if @analysis ='Most'
		select * from
		(select p.ProductID,
            p.ProductName,
            sum(od.Total_cost) as TotalSales,
            rank() over (order by sum(od.Total_cost) desc) as Salesrank
			from products p
			join order_details od
			on od.productID=p.productID
			group by p.ProductID,p.ProductName
			 ) as rank_view
			where rank_view.Salesrank <= @n

trendy_product @n=4 ,@analysis='Most'
trendy_product @n=4 ,@analysis='Less'

--Côte de Blaye, Thüringer Rostbratwurst and Raclette Courdavault
--represents highst sale revenue

--Chocolade, Geitost,Genen Shouyu are lowest 

--Top trendy products--count

declare @n int=4
select top(@n) 
            p.ProductName,
			c.categoryName,
            sum(od.quantity ) as Total_quantity
			from products p join categories c
			on c.categoryID=p.productID
			join order_details od
			on od.productID=p.productID
			group by p.ProductName,c.categoryName
			--order by total_quantity desc
			order by total_quantity 

--Chang,Chai and Uncle Bob's Organic Dried Pears are most trendy products

--Chef Anton's Gumbo Mix ,Grandma's Boysenberry Spread and Aniseed Syrup
--representes less trendy products


--------------------------------------------------------------------
--AVerage order cost in each country
select c.country ,avg (Total_Cost) as avg_Revenue_perOrder
from order_details od
join orders o
on o.orderID =od.orderID
join customers c
on c.customerID= o.customerID
group by c.country
order by avg_Revenue_perOrder desc
--Austria,Ireland,Denmark Have Best average order price


---------------------------------------------------------------
--avg ship cost
select  avg(freight)
from orders 
--Average Revenue  VS Average Shipment cost ( by Country)


select c.country ,avg (Total_Cost) as Avg_Revenue_perOrder
,avg(o.freight) as AVG_ship_cost,
(avg(o.freight)/avg (Total_Cost)) Shipp_Percentage
from order_details od
join orders o
on o.orderID =od.orderID
join customers c
on c.customerID= o.customerID
group by c.country
order by Shipp_Percentage
--Switzerland and Canada representes the best business Scenario 
--as ship cost is low compared to avg order revenue
 
---------------------------------------------------------------------------
--AVG shipping cost and time per shipping country
select sh.companyName,avg( datediff(day,o.shippedDate,o.requiredDate)) as AVG_Ship_Time
,avg(o.freight) as AVG_ship_cost
from orders o
join shippers sh
on sh.shipperID=o.shipperID
group by sh.companyName
--------------------------------------------------------------------
--Average ship cost and time per country
select c.country ,avg( datediff(day,o.shippedDate,o.requiredDate)) as AVG_Ship_Time
,avg(o.freight) as AVG_ship_cost
from orders o
join customers c
on c.customerID=o.customerID
group by c.country
order by AVG_ship_cost

--Speedy Express is the lowest shipp company 
-- we can deal with it more in the futuer

--Austria,USA , Ireland and Germany Has hieghst Average ship cost
--These countries have the hieghst sales and  hieghst orders num

--SO we can Consider negotiating better deals with shipping providers
--------------------------------------------------------------

--total sales per month
create or alter proc Total_sales_month 
@month varchar(10)
as
	select sum(od.Total_cost) 
	from order_details od
	join orders o
	on o.orderID=od.orderid
	where order_month =@month
Total_sales_month @month='09-14'
-----------------------------------------------------

--selecting top n months in sales

create or alter proc top_month @n int
as

	select top (@n) order_month ,sum(od.Total_cost) as sales
	from order_details od
	join orders o 
	on o.orderID=od.orderID
	group by order_month 
	order by sum(od.Total_cost) 

top_month @n =3

-- 05-15 , 08-13 ,09-13 Best 3 month in sales
----------------------------------
----------------------------------------------------------------
--Best trendy categories
select c.categoryName,SUM (od.quantity) as Total_orders
from order_details od
join products p
on p.productID=od.productID
join categories c
on c.categoryID = p.categoryID
group by c.categoryName
 order by Total_orders desc
 
--Beverages, Dairy Products and Confections
-- WE can make offers in these categories specialy they are also trendy in Best seeling countries


--Revenue per product
/*
select
	p.productName,
	od.unitPrice,
    p.unitPrice AS CurrentUnitPrice,
    sum(quantity) as total_quantity
    ,max(p.unitPrice - od.unitPrice)  as margin_unit
from
    order_details od
JOIN
    products p on od.productID = p.productID
group by p.productName,p.unitPrice,od.unitPrice
order by margin_unit desc
*/
-------------------------------------------------------

--------------------------------------------------------
--Trendy products 

select sum (od.quantity)
from order_details od


--sales per month
with monthsales AS (
    select
        od.productID,
		p.productName,
        o.Order_Month AS sale_month,
        sum(od.quantity) AS total_quantity
    from
        orders o
    join
        order_details od on o.orderid = od.orderid
	join products p on p.productID= od.productID
    group by
        od.productID, o.Order_Month,p.productName
),
RankedSales as (
    select
        productID,
		productname,
        sale_month,
        total_quantity,
        row_number() OVER (partition by sale_month order by total_quantity desc) as ranking
    from
        monthsales
)
select 
    r.productID,
    p.productName,
    r.sale_month,
    r.total_quantity
from
    RankedSales r
join
    products p ON p.productid = r.productID
where
    r.ranking = 1 
	
---------------------------------------------------

--List products in each category
--Category

select 
(case when c.categoryName='Beverages' then p.productName end)as Beverages,
(case when c.categoryName='Condiments' then p.productName end)as Condiments,
(case when c.categoryName='Confections' then p.productName end)as Confections,
(case when c.categoryName='Dairy Products' then p.productName end)as Dairy_Products,
(case when c.categoryName='Grains & Cereals' then p.productName end)as Grains_Cereals,
(case when c.categoryName='Meat & Poultry' then p.productName end)as Meat_Poultry,
(case when c.categoryName='Seafood' then p.productName end)as  Seafood

from products p
join categories c
on p.categoryID=c.categoryID
--where c.categoryName is not null
order by c.categoryName 

------------------------------------------------------------
------------------------------------------------------------

select e.employeename,e.employeeid,count(*) as Num_of_orders
from [dbo].[employees] e join orders o
on o.employeeID =e.employeeid
group by e.employeename,e.employeeid
order by Num_of_orders desc

--EMPs (Margaret Peacock),(Janet Leverling) and (Nancy Davolio)
--achiev most order target
--We can reward them to achieve more success

--Michael Suyama,Anne Dodsworth,Steven Buchanan
--For employees with lower order counts, consider implementing performance improvement plans
--additional training, or mentorship to enhance their sales or order processing skills.

select city,count(*) as Num_of_orders
from [dbo].[employees] e join orders o
on o.employeeID =e.employeeid
group by city

--we can think about challenges with London team 
-- and provide additional training, or mentorship to enhance their sales or order processing skills.

