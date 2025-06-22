--1-	write a sql to find top 5 customers who did most number booking in the same city where they live
--. Display customer id and percent of those bookings compare to total number of bookings done by them. 
--In case of tie prefer the customers with higher same city booking percent.

select top 5 hb.customer_id , COUNT(*) as no_of_bookings
, COUNT(case when h.city_id = c.city_id then booking_id  end) as same_city_bookings
, COUNT(case when h.city_id = c.city_id then 1 end) as same_city_bookings1
, SUM(case when h.city_id = c.city_id then 1 end) as same_city_bookings2
, COUNT(case when h.city_id = c.city_id then booking_id  end)*100.0 / COUNT(*) as same_city_bookings_percent
from hotel_bookings hb
inner join hotels h on hb.hotel_id=h.id
inner join customers c on hb.customer_id=c.customer_id
--where h.city_id = c.city_id 
group by hb.customer_id
order by same_city_bookings desc, same_city_bookings_percent desc;

--2-write a sql to find percent contribution by females in terms of revenue and no of bookings both for each hotel
--method 1
with f_cte as (
select hb.hotel_id , COUNT(*) as no_of_bookings , sum(per_night_rate*number_of_nights) as female_revenue
from hotel_bookings hb
inner join customers c on hb.customer_id=c.customer_id
where c.gender='F'
group by hb.hotel_id
)
, t_cte as (
select hotel_id , COUNT(*) as total_bookings , sum(per_night_rate*number_of_nights) as total_revenue
from hotel_bookings
group by hotel_id
)
select t_cte.hotel_id , t_cte.total_bookings , f_cte.no_of_bookings as female_bookings
,female_revenue, total_revenue
,round(f_cte.no_of_bookings*100.0/t_cte.total_bookings,2) as female_booking_percent
,round(f_cte.female_revenue*100/t_cte.total_revenue,2) as female_revenue_percent
from t_cte 
left join f_cte on t_cte.hotel_id=f_cte.hotel_id;

--method 2
select hb.hotel_id , COUNT(*) as total_bookings 
, sum(case when c.gender='F' then 1 end) as female_bookings
, SUM(per_night_rate*number_of_nights) as total_revenue
, sum(case when c.gender='F' then per_night_rate*number_of_nights end) as female_revenue
, round(sum(case when c.gender='F' then 1 end) *100.0/ COUNT(*),2) as female_booking_percent
, round(sum(case when c.gender='F' then per_night_rate*number_of_nights end)*100/SUM(per_night_rate*number_of_nights),2) as female_revenue_percent
from hotel_bookings hb
inner join customers c on hb.customer_id=c.customer_id
group by hb.hotel_id;

--3-	for each hotel find number of bookings from customers who visit from a different state 
--similar to question 1

select hb.hotel_id, COUNT(*) as no_of_bookings 
from hotel_bookings hb
inner join hotels h on hb.hotel_id=h.id
inner join cities ch on ch.id=h.city_id
inner join customers c on hb.customer_id=c.customer_id
inner join cities cc on cc.id=c.city_id
where ch.state!=cc.state
group by hb.hotel_id
order by hb.hotel_id
;

--note creating a table for day wise booking data as it will be used in multiple questions
with cte as (
select hotel_id , customer_id 
,stay_start_date as start_date , DATEADD(day,number_of_nights-1,stay_start_date) as end_date
from hotel_bookings
)
, rcte as (
select hotel_id , customer_id, start_date as stay_date,end_date 
from cte
union all
select hotel_id , customer_id , DATEADD(day,1,stay_date) as stay_date, end_date
from rcte
where DATEADD(day,1,stay_date) <= end_date
)
select * into hotel_bookings_flatten from rcte

select * from hotel_bookings_flatten;

--4- for each hotel find the date when occupancy was maximum 
--(a customer should not be considered in hotel on the checkout date)

select * from (
select hotel_id,stay_date,COUNT(*) as no_of_guests 
, rank() over(partition by hotel_id order by COUNT(*) desc) as rn
from hotel_bookings_flatten
group by hotel_id,stay_date
) a
where rn=1;

--5- 	find customers who have booked hotels in atleast 3 different states
select hb.customer_id
from hotel_bookings hb
inner join hotels h on hb.hotel_id=h.id 
inner join cities c on h.city_id=c.id
group by hb.customer_id
having COUNT(distinct c.state)>=3


--6-calculate the occupancy rate (percentage of rooms booked in respect of total rooms available) for each hotel for each month

with cte as
(select hb.hotel_id , hb.stay_date, COUNT(*) as no_of_guests,h.capacity 
from hotel_bookings_flatten hb
inner join hotels h on hb.hotel_id=h.id
where hotel_id=101 
group by hb.hotel_id,stay_date ,h.capacity
)
select hotel_id, MONTH(stay_date) as stay_month , SUM(no_of_guests)*100.0/SUM(capacity) as ocr
from cte
group by 
hotel_id, MONTH(stay_date);

--7- 	for each hotel find dates when they were fully occupied
with cte as (
select hotel_id,stay_date,COUNT(*) as no_of_guests 
from hotel_bookings_flatten
group by hotel_id,stay_date
) 
select cte.*, h.capacity
from cte
inner join hotels h on cte.hotel_id=h.id
where cte.no_of_guests=h.capacity

--8- 	which booking channel has generated highest sales for each hotel in each month
with cte as (
select hotel_id, booking_channel, format(booking_date,'yyyyMM') as booking_month
,sum(number_of_nights*per_night_rate) as revenue
from hotel_bookings
group by hotel_id, booking_channel, format(booking_date,'yyyyMM') 
)
select * from (
select *
, ROW_NUMBER() over(partition by hotel_id,booking_month order by revenue desc ) as rn
from cte ) a
where rn=1;

--9- 	find percent share of number of bookings by each booking channel
select booking_channel, COUNT(*) as no_of_bookings
,round(count(*)*100.0 /sum(COUNT(*)) over(),2) as percent_of_total_bookings
from  hotel_bookings
group by booking_channel ;

--10-	for each hotel find the total revenue generated by millenials(born between 1980 and 1996) and  gen z (born after 1996)
select case when year(c.dob) between 1980 and 1996 then 'millenials' 
when year(c.dob) > 1996 then 'gen z' end as customer_category
, sum(per_night_rate*number_of_nights) as revenue
from hotel_bookings hb
inner join customers c on hb.customer_id=c.customer_id
group by case when year(c.dob) between 1980 and 1996 then 'millenials' 
when year(c.dob) > 1996 then 'gen z' end
;

--11-	For each hotel find  the average stay duration
select hotel_id , avg(number_of_nights*1.0) as avg_duration
from hotel_bookings
group by hotel_id;

--12-	find the average number of days customers book in advance for each hotel.
select hotel_id , avg(datediff(DAY,booking_date,stay_start_date)*1.0) as avg_advanced_booked_days
from hotel_bookings
group by hotel_id;

--13 find customers who never did any booking
select * from customers
where customer_id not in (select customer_id from hotel_bookings)

--14- 	find customers who stayed in atleast 3 distinct hotel in a same month
--Display  customer name , month and no of bookings.
select customer_id, MONTH(stay_date) as month_stay, COUNT(distinct hotel_id) as cnt
from hotel_bookings_flatten
group by customer_id ,MONTH(stay_date)
having COUNT(distinct hotel_id)>=3
order by cnt desc


