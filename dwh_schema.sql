-- schema for detailed layer
CREATE SCHEMA IF NOT EXISTS dwh_detailed;

-- sequence for surrogate keys
CREATE SEQUENCE dwh_detailed.global_seq;

-- Hubs
CREATE TABLE dwh_detailed.hub_airports (
    airport_hub_id BIGINT DEFAULT nextval('dwh_detailed.global_seq') PRIMARY KEY,
    airport_hash_key CHAR(32) NOT NULL UNIQUE,
    airport_code CHAR(3) NOT NULL,
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL
);

CREATE TABLE dwh_detailed.hub_aircrafts (
    aircraft_hub_id BIGINT DEFAULT nextval('dwh_detailed.global_seq') PRIMARY KEY,
    aircraft_hash_key CHAR(32) NOT NULL UNIQUE,
    aircraft_code CHAR(3) NOT NULL,
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL
);

CREATE TABLE dwh_detailed.hub_passengers (
    passenger_hub_id BIGINT DEFAULT nextval('dwh_detailed.global_seq') PRIMARY KEY,
    passenger_hash_key CHAR(32) NOT NULL UNIQUE,
    passenger_id VARCHAR(20) NOT NULL,
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL
);

CREATE TABLE dwh_detailed.hub_bookings (
    booking_hub_id BIGINT DEFAULT nextval('dwh_detailed.global_seq') PRIMARY KEY,
    booking_hash_key CHAR(32) NOT NULL UNIQUE,
    book_ref CHAR(6) NOT NULL,
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL
);

CREATE TABLE dwh_detailed.hub_flights (
    flight_hub_id BIGINT DEFAULT nextval('dwh_detailed.global_seq') PRIMARY KEY,
    flight_hash_key CHAR(32) NOT NULL UNIQUE,
    flight_id INTEGER NOT NULL,
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL
);

-- Links
CREATE TABLE dwh_detailed.link_flight_leg (
    flight_leg_link_id BIGINT DEFAULT nextval('dwh_detailed.global_seq') PRIMARY KEY,
    flight_leg_hash_key CHAR(32) NOT NULL UNIQUE,
    flight_hub_id BIGINT REFERENCES dwh_detailed.hub_flights(flight_hub_id),
    departure_airport_hub_id BIGINT REFERENCES dwh_detailed.hub_airports(airport_hub_id),
    arrival_airport_hub_id BIGINT REFERENCES dwh_detailed.hub_airports(airport_hub_id),
    aircraft_hub_id BIGINT REFERENCES dwh_detailed.hub_aircrafts(aircraft_hub_id),
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL
);

CREATE TABLE dwh_detailed.link_ticket_booking (
    ticket_booking_link_id BIGINT DEFAULT nextval('dwh_detailed.global_seq') PRIMARY KEY,
    ticket_booking_hash_key CHAR(32) NOT NULL UNIQUE,
    booking_hub_id BIGINT REFERENCES dwh_detailed.hub_bookings(booking_hub_id),
    passenger_hub_id BIGINT REFERENCES dwh_detailed.hub_passengers(passenger_hub_id),
    ticket_no CHAR(13) NOT NULL,
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL
);

CREATE TABLE dwh_detailed.link_ticket_flight (
    ticket_flight_link_id BIGINT DEFAULT nextval('dwh_detailed.global_seq') PRIMARY KEY,
    ticket_flight_hash_key CHAR(32) NOT NULL UNIQUE,
    ticket_booking_link_id BIGINT REFERENCES dwh_detailed.link_ticket_booking(ticket_booking_link_id),
    flight_hub_id BIGINT REFERENCES dwh_detailed.hub_flights(flight_hub_id),
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL
);

-- Satellites
CREATE TABLE dwh_detailed.sat_airport_details (
    airport_hub_id BIGINT REFERENCES dwh_detailed.hub_airports(airport_hub_id),
    load_date TIMESTAMP NOT NULL,
    airport_name TEXT NOT NULL,
    city TEXT NOT NULL,
    coordinates_lon DOUBLE PRECISION NOT NULL,
    coordinates_lat DOUBLE PRECISION NOT NULL,
    timezone TEXT NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL,
    hash_diff CHAR(32) NOT NULL,
    PRIMARY KEY (airport_hub_id, load_date)
);

CREATE TABLE dwh_detailed.sat_aircraft_details (
    aircraft_hub_id BIGINT REFERENCES dwh_detailed.hub_aircrafts(aircraft_hub_id),
    load_date TIMESTAMP NOT NULL,
    model JSONB NOT NULL,
    range INTEGER NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL,
    hash_diff CHAR(32) NOT NULL,
    PRIMARY KEY (aircraft_hub_id, load_date)
);

CREATE TABLE dwh_detailed.sat_passenger_details (
    passenger_hub_id BIGINT REFERENCES dwh_detailed.hub_passengers(passenger_hub_id),
    load_date TIMESTAMP NOT NULL,
    passenger_name TEXT NOT NULL,
    contact_data JSONB,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL,
    hash_diff CHAR(32) NOT NULL,
    PRIMARY KEY (passenger_hub_id, load_date)
);

CREATE TABLE dwh_detailed.sat_booking_details (
    booking_hub_id BIGINT REFERENCES dwh_detailed.hub_bookings(booking_hub_id),
    load_date TIMESTAMP NOT NULL,
    book_date TIMESTAMPTZ NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL,
    hash_diff CHAR(32) NOT NULL,
    PRIMARY KEY (booking_hub_id, load_date)
);

CREATE TABLE dwh_detailed.sat_flight_details (
    flight_hub_id BIGINT REFERENCES dwh_detailed.hub_flights(flight_hub_id),
    load_date TIMESTAMP NOT NULL,
    flight_no CHAR(6) NOT NULL,
    scheduled_departure TIMESTAMPTZ NOT NULL,
    scheduled_arrival TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL,
    actual_departure TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL,
    hash_diff CHAR(32) NOT NULL,
    PRIMARY KEY (flight_hub_id, load_date)
);

CREATE TABLE dwh_detailed.sat_ticket_flight_details (
    ticket_flight_link_id BIGINT REFERENCES dwh_detailed.link_ticket_flight(ticket_flight_link_id),
    load_date TIMESTAMP NOT NULL,
    fare_conditions NUMERIC(10,2) NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    boarding_no INTEGER,
    seat_no VARCHAR(4),
    record_source VARCHAR(100) NOT NULL,
    source_system_id INTEGER NOT NULL,
    hash_diff CHAR(32) NOT NULL,
    PRIMARY KEY (ticket_flight_link_id, load_date)
); 