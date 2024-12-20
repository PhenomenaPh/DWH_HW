-- View for active airports in the last 30 days
CREATE OR REPLACE VIEW dwh_marts.v_active_airports_30d AS
WITH flight_airports AS (
    SELECT DISTINCT
        a.airport_code,
        ad.airport_name,
        fd.scheduled_departure::date as flight_date
    FROM dwh_detailed.hub_airports a
    JOIN dwh_detailed.sat_airport_details ad ON a.airport_hub_id = ad.airport_hub_id
    JOIN dwh_detailed.link_flight_leg fl ON 
        (a.airport_hub_id = fl.departure_airport_hub_id OR a.airport_hub_id = fl.arrival_airport_hub_id)
    JOIN dwh_detailed.hub_flights f ON fl.flight_hub_id = f.flight_hub_id
    JOIN dwh_detailed.sat_flight_details fd ON f.flight_hub_id = fd.flight_hub_id
    WHERE fd.scheduled_departure >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    flight_date,
    COUNT(DISTINCT airport_code) as active_airports
FROM flight_airports
GROUP BY flight_date
ORDER BY flight_date;

-- View for airport traffic share
CREATE OR REPLACE VIEW dwh_marts.v_airport_traffic_share AS
WITH airport_stats AS (
    SELECT 
        a.airport_code,
        ad.airport_name,
        COUNT(*) as total_flights,
        SUM(bd.total_amount) as total_revenue,
        COUNT(DISTINCT tb.passenger_hub_id) as total_passengers
    FROM dwh_detailed.hub_airports a
    JOIN dwh_detailed.sat_airport_details ad ON a.airport_hub_id = ad.airport_hub_id
    JOIN dwh_detailed.link_flight_leg fl ON 
        (a.airport_hub_id = fl.departure_airport_hub_id OR a.airport_hub_id = fl.arrival_airport_hub_id)
    JOIN dwh_detailed.hub_flights f ON fl.flight_hub_id = f.flight_hub_id
    JOIN dwh_detailed.sat_flight_details fd ON f.flight_hub_id = fd.flight_hub_id
    JOIN dwh_detailed.link_ticket_flight tf ON f.flight_hub_id = tf.flight_hub_id
    JOIN dwh_detailed.link_ticket_booking tb ON tf.ticket_booking_link_id = tb.ticket_booking_link_id
    JOIN dwh_detailed.hub_bookings b ON tb.booking_hub_id = b.booking_hub_id
    JOIN dwh_detailed.sat_booking_details bd ON b.booking_hub_id = bd.booking_hub_id
    WHERE fd.scheduled_departure >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY a.airport_code, ad.airport_name
)
SELECT 
    airport_code,
    airport_name,
    total_flights,
    ROUND(100.0 * total_flights / SUM(total_flights) OVER (), 2) as flight_share_percent,
    total_passengers,
    ROUND(100.0 * total_passengers / SUM(total_passengers) OVER (), 2) as passenger_share_percent
FROM airport_stats
ORDER BY total_flights DESC;

-- View for passenger metrics
CREATE OR REPLACE VIEW dwh_marts.v_passenger_metrics_30d AS
WITH passenger_stats AS (
    SELECT 
        p.passenger_id,
        fd.scheduled_departure::date as flight_date,
        COUNT(DISTINCT f.flight_id) as flights_count,
        SUM(bd.total_amount) as total_spent
    FROM dwh_detailed.hub_passengers p
    JOIN dwh_detailed.link_ticket_booking tb ON p.passenger_hub_id = tb.passenger_hub_id
    JOIN dwh_detailed.link_ticket_flight tf ON tb.ticket_booking_link_id = tf.ticket_booking_link_id
    JOIN dwh_detailed.hub_flights f ON tf.flight_hub_id = f.flight_hub_id
    JOIN dwh_detailed.sat_flight_details fd ON f.flight_hub_id = fd.flight_hub_id
    JOIN dwh_detailed.hub_bookings b ON tb.booking_hub_id = b.booking_hub_id
    JOIN dwh_detailed.sat_booking_details bd ON b.booking_hub_id = bd.booking_hub_id
    WHERE fd.scheduled_departure >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY p.passenger_id, fd.scheduled_departure::date
)
SELECT 
    flight_date,
    COUNT(DISTINCT passenger_id) as unique_passengers,
    ROUND(AVG(total_spent), 2) as avg_check,
    ROUND(AVG(flights_count), 2) as avg_flights_per_passenger,
    SUM(total_spent) as total_revenue
FROM passenger_stats
GROUP BY flight_date
ORDER BY flight_date;

-- View for passenger groups revenue share
CREATE OR REPLACE VIEW dwh_marts.v_passenger_groups_revenue AS
WITH passenger_categories AS (
    SELECT 
        p.passenger_id,
        CASE 
            WHEN COUNT(DISTINCT f.flight_id) >= 10 THEN 'Frequent Flyer'
            WHEN COUNT(DISTINCT f.flight_id) >= 5 THEN 'Regular Customer'
            ELSE 'Occasional Traveler'
        END as passenger_group,
        SUM(bd.total_amount) as total_spent
    FROM dwh_detailed.hub_passengers p
    JOIN dwh_detailed.link_ticket_booking tb ON p.passenger_hub_id = tb.passenger_hub_id
    JOIN dwh_detailed.link_ticket_flight tf ON tb.ticket_booking_link_id = tf.ticket_booking_link_id
    JOIN dwh_detailed.hub_flights f ON tf.flight_hub_id = f.flight_hub_id
    JOIN dwh_detailed.sat_flight_details fd ON f.flight_hub_id = fd.flight_hub_id
    JOIN dwh_detailed.hub_bookings b ON tb.booking_hub_id = b.booking_hub_id
    JOIN dwh_detailed.sat_booking_details bd ON b.booking_hub_id = bd.booking_hub_id
    WHERE fd.scheduled_departure >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY p.passenger_id
)
SELECT 
    passenger_group,
    COUNT(DISTINCT passenger_id) as passenger_count,
    SUM(total_spent) as group_revenue,
    ROUND(100.0 * SUM(total_spent) / SUM(SUM(total_spent)) OVER (), 2) as revenue_share_percent
FROM passenger_categories
GROUP BY passenger_group
ORDER BY group_revenue DESC; 