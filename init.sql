-- airports table
CREATE TABLE airports (
    airport_code CHAR(3) PRIMARY KEY,
    airport_name TEXT NOT NULL,
    city TEXT NOT NULL,
    coordinates_lon DOUBLE PRECISION NOT NULL,
    coordinates_lat DOUBLE PRECISION NOT NULL,
    timezone TEXT NOT NULL
);

-- aircrafts table
CREATE TABLE aircrafts (
    aircraft_code CHAR(3) PRIMARY KEY,
    model JSONB NOT NULL,
    range INTEGER NOT NULL
);

-- seats table
CREATE TABLE seats (
    aircraft_code CHAR(3) REFERENCES aircrafts(aircraft_code),
    seat_no VARCHAR(4) NOT NULL,
    fare_conditions VARCHAR(10) NOT NULL,
    PRIMARY KEY (aircraft_code, seat_no)
);

-- flights table
CREATE TABLE flights (
    flight_id SERIAL PRIMARY KEY,
    flight_no CHAR(6) NOT NULL,
    scheduled_departure TIMESTAMPTZ NOT NULL,
    scheduled_arrival TIMESTAMPTZ NOT NULL,
    departure_airport CHAR(3) REFERENCES airports(airport_code),
    arrival_airport CHAR(3) REFERENCES airports(airport_code),
    status VARCHAR(20) NOT NULL,
    aircraft_code CHAR(3) REFERENCES aircrafts(aircraft_code),
    actual_departure TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ
);

-- bookings table
CREATE TABLE bookings (
    book_ref CHAR(6) PRIMARY KEY,
    book_date TIMESTAMPTZ NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL
);

-- tickets table
CREATE TABLE tickets (
    ticket_no CHAR(13) PRIMARY KEY,
    book_ref CHAR(6) REFERENCES bookings(book_ref),
    passenger_id VARCHAR(20) NOT NULL,
    passenger_name TEXT NOT NULL,
    contact_data JSONB
);

-- ticket_flights table
CREATE TABLE ticket_flights (
    ticket_no CHAR(13) REFERENCES tickets(ticket_no),
    flight_id INTEGER REFERENCES flights(flight_id),
    fare_conditions NUMERIC(10,2) NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (ticket_no, flight_id)
);

-- boarding_passes table
CREATE TABLE boarding_passes (
    ticket_no CHAR(13),
    flight_id INTEGER,
    boarding_no INTEGER NOT NULL,
    seat_no VARCHAR(4) NOT NULL,
    PRIMARY KEY (ticket_no, flight_id),
    FOREIGN KEY (ticket_no, flight_id) REFERENCES ticket_flights(ticket_no, flight_id)
);