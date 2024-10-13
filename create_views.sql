CREATE OR REPLACE VIEW airport_traffic AS
SELECT 
    COALESCE(dep.airport_code, arr.airport_code) AS airport_code,
    COALESCE(dep.departure_flights_num, 0) AS departure_flights_num,
    COALESCE(dep.departure_psngr_num, 0) AS departure_psngr_num,
    COALESCE(arr.arrival_flights_num, 0) AS arrival_flights_num,
    COALESCE(arr.arrival_psngr_num, 0) AS arrival_psngr_num
FROM (
    SELECT 
        f.departure_airport AS airport_code,
        COUNT(DISTINCT f.flight_id) AS departure_flights_num,
        COUNT(t.ticket_no) AS departure_psngr_num
    FROM flights f
    LEFT JOIN ticket_flights tf ON f.flight_id = tf.flight_id
    LEFT JOIN tickets t ON tf.ticket_no = t.ticket_no
    GROUP BY f.departure_airport
) dep
FULL OUTER JOIN (
    SELECT 
        f.arrival_airport AS airport_code,
        COUNT(DISTINCT f.flight_id) AS arrival_flights_num,
        COUNT(t.ticket_no) AS arrival_psngr_num
    FROM flights f
    LEFT JOIN ticket_flights tf ON f.flight_id = tf.flight_id
    LEFT JOIN tickets t ON tf.ticket_no = t.ticket_no
    GROUP BY f.arrival_airport
) arr ON dep.airport_code = arr.airport_code;