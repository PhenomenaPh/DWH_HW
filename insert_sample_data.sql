INSERT INTO airports (airport_code, airport_name, city, coordinates_lon, coordinates_lat, timezone) VALUES
('SFO', 'San Francisco International', 'San Francisco', -122.3789, 37.6190, 'America/Los_Angeles'),
('JFK', 'John F. Kennedy International', 'New York', -73.7781, 40.6413, 'America/New_York'),
('LAX', 'Los Angeles International', 'Los Angeles', -118.4085, 33.9416, 'America/Los_Angeles');

INSERT INTO aircrafts (aircraft_code, model, range) VALUES
('773', '{"en": "Boeing 777-300", "ru": "Боинг 777-300"}', 11100),
('763', '{"en": "Boeing 767-300", "ru": "Боинг 767-300"}', 7900),
('SU9', '{"en": "Sukhoi Superjet-100", "ru": "Сухой Суперджет-100"}', 3000);

INSERT INTO seats (aircraft_code, seat_no, fare_conditions) VALUES
('773', '1A', 'business'),
('773', '1B', 'business'),
('773', '10A', 'economy'),
('763', '1A', 'business'),
('763', '10A', 'economy'),
('SU9', '1A', 'business'),
('SU9', '10A', 'economy');

INSERT INTO flights (flight_no, scheduled_departure, scheduled_arrival, departure_airport, arrival_airport, status, aircraft_code) VALUES
('PG0001', '2023-08-15 09:00:00+00', '2023-08-15 12:00:00+00', 'SFO', 'JFK', 'Scheduled', '773'),
('PG0002', '2023-08-15 13:00:00+00', '2023-08-15 15:00:00+00', 'JFK', 'LAX', 'Scheduled', '763'),
('PG0003', '2023-08-15 16:00:00+00', '2023-08-15 17:30:00+00', 'LAX', 'SFO', 'Scheduled', 'SU9');

INSERT INTO bookings (book_ref, book_date, total_amount) VALUES
('ABC123', '2023-08-01 10:00:00+00', 500.00),
('DEF456', '2023-08-02 11:00:00+00', 600.00),
('GHI789', '2023-08-03 12:00:00+00', 550.00);

INSERT INTO tickets (ticket_no, book_ref, passenger_id, passenger_name, contact_data) VALUES
('1234567890123', 'ABC123', 'PS001', 'John Doe', '{"phone": "+1234567890", "email": "john@example.com"}'),
('2345678901234', 'DEF456', 'PS002', 'Jane Smith', '{"phone": "+0987654321", "email": "jane@example.com"}'),
('3456789012345', 'GHI789', 'PS003', 'Bob Johnson', '{"phone": "+1122334455", "email": "bob@example.com"}');

INSERT INTO ticket_flights (ticket_no, flight_id, fare_conditions, amount) VALUES
('1234567890123', 1, 200.00, 300.00),
('2345678901234', 2, 250.00, 350.00),
('3456789012345', 3, 150.00, 200.00);

INSERT INTO boarding_passes (ticket_no, flight_id, boarding_no, seat_no) VALUES
('1234567890123', 1, 1, '1A'),
('2345678901234', 2, 1, '1A'),
('3456789012345', 3, 1, '10A');