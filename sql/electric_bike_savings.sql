-- Get savings for commutes done with electric bike --
-- COPY (
    WITH bikeumeter_electric_activities AS (
        SELECT name, date, public_transport_fare, ride_duration_minutes
        FROM read_csv_auto('data/bikeumeter_activities.csv') AS activities
        WHERE name LIKE'%swapfiets%' -- activities done with the electric bike are named like this in the dataset
    ),

    -- 1) Date manipulation
        -- a) Keep only date portion of timestamp
    clean_date AS (
        SELECT *,
                CAST(date AS DATE) AS date_only -- strip out the time portion
        FROM bikeumeter_electric_activities
    ),

    -- b) Turn date into month -- monthname(date) function
    -- c) Group activities by date
    monthly_activities AS (
        SELECT date_part('year', date_only) AS year, date_part('month', date_only) AS month_number, MONTHNAME(date_only) AS month, 
                public_transport_fare, ride_duration_minutes
        FROM clean_date
        ORDER BY date_only -- always order by date not by month name
    ),
    -- remove the € symbol
    clean_fare_euros AS (
        SELECT year, month_number, month, ride_duration_minutes, 
                REPLACE(public_transport_fare, '€', '') AS clean_fare_euros
        FROM monthly_activities
    ),
    -- 2) Public transport fare sum
        -- a) Sum of fare per month
    monthly_e_rides AS (
        SELECT  year, month_number, month,
                COUNT(*) AS e_rides,
                ROUND(SUM(ride_duration_minutes) / 60, 2) AS e_hours_ridden,
                SUM(CAST(clean_fare_euros AS DECIMAL(10,2))) AS total_transport_fare_euros
        FROM clean_fare_euros
        WHERE NOT month = 'June' -- June is not yet completed
        GROUP BY year, month_number, month
    ),

    -- 3) Did the bike 'pay for itself'? As this is a rented bike, I want to know if I covered the rental fee.
    -- Bike rental is 64.90 euros per month with the plan I have
    e_savings AS (
        SELECT year, month_number, month,
            e_rides, e_hours_ridden,
            total_transport_fare_euros,
            64.90 AS bike_rental, -- bike rental fee
            ROUND(total_transport_fare_euros - 64.90, 2) AS saved_money_euros,
        FROM monthly_e_rides
    ),

    e_final_savings AS (
        SELECT *,
            CASE 
                WHEN saved_money_euros >= 0 THEN 'YES!'
                ELSE 'NO'
            END AS paid_for_itself
        FROM e_savings
        ORDER BY year ASC, month_number ASC
    )

    SELECT * FROM e_final_savings;
-- )
-- TO 'results/e_bike_savings.csv'
-- WITH (HEADER, DELIMETER ',');