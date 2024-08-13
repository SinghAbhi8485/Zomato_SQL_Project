drop table if exists goldusers_signup;
CREATE TABLE goldusers_signup(userid integer,gold_signup_date date); 

INSERT INTO goldusers_signup(userid,gold_signup_date) 
 VALUES (1,'09-22-2017'),
(3,'04-21-2017');

drop table if exists users;
CREATE TABLE users(userid integer,signup_date date); 

INSERT INTO users(userid,signup_date) 
 VALUES (1,'09-02-2014'),
(2,'01-15-2015'),
(3,'04-11-2014');

drop table if exists sales;
CREATE TABLE sales(userid integer,created_date date,product_id integer); 

INSERT INTO sales(userid,created_date,product_id) 
 VALUES (1,'04-19-2017',2),
(3,'12-18-2019',1),
(2,'07-20-2020',3),
(1,'10-23-2019',2),
(1,'03-19-2018',3),
(3,'12-20-2016',2),
(1,'11-09-2016',1),
(1,'05-20-2016',3),
(2,'09-24-2017',1),
(1,'03-11-2017',2),
(1,'03-11-2016',1),
(3,'11-10-2016',1),
(3,'12-07-2017',2),
(3,'12-15-2016',2),
(2,'11-08-2017',2),
(2,'09-10-2018',3);


drop table if exists product;
CREATE TABLE product(product_id integer,product_name text,price integer); 

INSERT INTO product(product_id,product_name,price) 
 VALUES
(1,'p1',980),
(2,'p2',870),
(3,'p3',330);


select * from sales;
select * from product;
select * from goldusers_signup;
select * from users;


-- Q1. what is the total amount each customer spent on Zomato?
Select s.userid , sum(price) as amount_spent
from sales s
join 
product p
on s.product_id = p.product_id
group by s.userid

-- Q2. How many days has each customer visited Zomato?
Select userid , count(distinct created_date) as days_visited 
from 
sales
group by userid;

-- Q3. What was the first product purchased by each customer?
with cte as 
(Select *, ROW_NUMBER() over(partition by userid order by created_date asc) as row_no
from sales) 

Select c.userid ,c.created_date , p.product_name from cte c
join product p
on c.product_id = p.product_id
where row_no =1
-- here p1 is product is purchased first i.e. best sku for the catalog

-- Q4 . What is the most purchased item on the menu and how many times was it purchased by all customers?
Select distinct userid,product_id, count(product_id) over(partition by userid , product_id order by userid) as cnt
from sales
where product_id in 
(Select top 1 product_id 
from sales
group by product_id
order by count(product_id) desc)
-- from table we know that 1,3 our gold memebers and there might be they would be getting extra benefit from product id 2


-- Q5. Which item is most popular for each customer
with cte as 
(Select userid,product_id, count(product_id) as cnt
from sales
group by userid,product_id)
,
cte2 as (
Select * , RANK() over(partition by userid order by cnt desc) as rnk
from cte )

Select userid, product_id from cte2 
where rnk =1


-- Q6 . Which item was purchased first by the customer after they became a member?
with cte as
(Select s.userid,s.product_id,s.created_date,gs.gold_signup_date from
sales s
join 
goldusers_signup gs
on s.userid = gs.userid and s.created_date >= gs.gold_signup_date)
, cte2 as
(Select * , rank() over(partition by userid order by created_date asc) as rnk
from cte)
Select userid , product_id from cte2 where rnk =1

--Q7. Which item was purchased just before cutomer became a memeber?
with cte as 
(Select s.userid,s.product_id,s.created_date,gs.gold_signup_date from
sales s
join 
goldusers_signup gs
on s.userid = gs.userid  and created_date<gs.gold_signup_date)
, cte2 as (
Select * , rank() over(partition by userid order by created_date desc) as rnk
from cte)

Select userid , product_id , created_date as recent_dt_before_mem
from cte2 
where rnk = 1;

-- Q8. total Orders and amount spent for each memeber before they became memeber
with cte as 
(Select s.userid,s.product_id,s.created_date,gs.gold_signup_date from
sales s
join 
goldusers_signup gs
on s.userid = gs.userid  and created_date<gs.gold_signup_date)
, cte2 as(
Select c.*, p.price
from cte c
join 
product p 
on c.product_id = p.product_id)

Select userid,  count(created_date) as total_orders , sum(price) as amount_spent
from cte2
group by userid ;

/*  Q9. If buying each product generates points for eg 5rs = 2 zomato points
and each product has different purchasing points 
p1 5rs = 1 zomato point
p2 10rs = 5 zomato point
p3 5rs  = 1 zomato point

Calculate points collected by each customers and for which product most points 
have been given till now

*/ 
with cte as (
Select s.* ,p.price
from sales s
join 
product p
on s.product_id = p.product_id ), 

cte2 as (
Select userid, product_id ,sum(price) as amount
from cte
group by userid , product_id) ,

cte3 as (
Select * , 
case when product_id = 1 then 5 
when product_id = 2 then 2
when product_id = 3 then 5 
else 0 end as points
from cte2)
, cte4 as (
Select * , amount/points as total_points , (amount/points)*2.5 as cashback_earned
from cte3)
Select userid , sum(total_points) as total_points , sum(cashback_earned) as total_cashback
from cte4
group by userid ; 

-- one part missing

with cte as (
Select s.* ,p.price
from sales s
join 
product p
on s.product_id = p.product_id ), 

cte2 as (
Select userid, product_id ,sum(price) as amount
from cte
group by userid , product_id) ,

cte3 as (
Select * , 
case when product_id = 1 then 5 
when product_id = 2 then 2
when product_id = 3 then 5 
else 0 end as points
from cte2)
, cte4 as (
Select * , amount/points as total_points 
from cte3) ,
cte5 as (
Select product_id , sum(total_points) as total_points 
from cte4
group by product_id )
Select product_id , total_points from (
Select cte5.* , rank() over(order by total_points desc) as rnk
from cte5) a
where rnk =1

/* Q10 . In the first one year after a customer joins the gold program , 
(including their join date) irrespective of what the customer has purchased
they earn 5 zomato points for every 10rs spent who earned more 1 or 3 and 
what was their points earning in their first yr?
*/
with  cte as (
Select s.userid ,s.created_date , s.product_id , gs.gold_signup_date
from sales s
join 
goldusers_signup gs
on s.userid = gs.userid and s.created_date>=gs.gold_signup_date and s.created_date<DATEADD(year,1,gs.gold_signup_date))

Select c.userid, p.price/2 as total_points
from cte c
join 
product p
on  c.product_id = p.product_id


-- Q11. Rank all the transactions of the customers.
Select *  ,
rank() over(partition by userid order by created_date ) rnk from sales;


/* Q12. Rank all the transactions for each member whenever they are a 
zomato gold memeber for every non gold member transaction mark NA */
with cte as (
Select s.* , gs.gold_signup_date from
sales s
left join 
goldusers_signup gs
on s.userid = gs.userid and s.created_date > gs.gold_signup_date) ,
cte2 as
(
Select *  , 
cast((case when gold_signup_date is null then 0 else
rank() over(partition by userid order by created_date desc) end) as varchar) as rnk 
from cte )

Select cte2.*,
case when rnk = 0 then 'na' else rnk end as rnkk
from cte2






