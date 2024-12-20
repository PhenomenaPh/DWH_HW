from datetime import timedelta

from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.utils.dates import days_ago

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "max_retry_delay": timedelta(minutes=30),
    "execution_timeout": timedelta(minutes=30),
    "sla": timedelta(hours=1),
}

with DAG(
    "airport_passenger_flow_mart",
    default_args=default_args,
    description="Airport Passenger Flow Data Mart",
    schedule_interval="0 1 * * *",  # Run daily at 1 AM
    start_date=days_ago(1),
    catchup=False,
    tags=["datamart", "airport_flow"],
    doc_md="""
    # Airport Passenger Flow Data Mart
    
    This DAG generates the airport passenger flow data mart by analyzing daily flight operations.
    
    ## Source Tables
    - flights
    - ticket_flights
    
    ## Target Table
    - presentation.airport_passenger_flow
    
    ## Schedule
    Daily update at 1 AM UTC for previous day's data
    """,
) as dag:
    create_schema = PostgresOperator(
        task_id="create_schema",
        postgres_conn_id="PROD_DB",
        sql="""
            CREATE SCHEMA IF NOT EXISTS presentation;
            
            CREATE TABLE IF NOT EXISTS presentation.airport_passenger_flow (
                created_at TIMESTAMP NOT NULL,
                flight_date DATE NOT NULL,
                airport_code CHAR(3) NOT NULL,
                linked_airport_code CHAR(3) NOT NULL,
                flights_in INTEGER NOT NULL,
                flights_out INTEGER NOT NULL,
                passengers_in INTEGER NOT NULL,
                passengers_out INTEGER NOT NULL,
                PRIMARY KEY (flight_date, airport_code, linked_airport_code)
            );
            
            -- Index for efficient date-based operations
            CREATE INDEX IF NOT EXISTS idx_airport_flow_date 
            ON presentation.airport_passenger_flow(flight_date DESC);
            
            -- Index for airport analysis
            CREATE INDEX IF NOT EXISTS idx_airport_flow_airports 
            ON presentation.airport_passenger_flow(airport_code, linked_airport_code);
        """,
        retries=5,  # More retries for schema creation
        retry_delay=timedelta(seconds=30),
    )

    load_data = PostgresOperator(
        task_id="load_data",
        postgres_conn_id="PROD_DB",
        sql="""
            -- Use a transaction for data consistency
            BEGIN;
            
            -- Delete existing data for previous day to avoid duplicates
            DELETE FROM presentation.airport_passenger_flow
            WHERE flight_date = (CURRENT_DATE AT TIME ZONE 'UTC') - INTERVAL '1 day';
            
            WITH flight_counts AS (
                -- Outbound flights
                SELECT 
                    -- Use actual_departure for completed flights, scheduled for in-progress
                    (COALESCE(
                        actual_departure AT TIME ZONE 'UTC',
                        scheduled_departure AT TIME ZONE 'UTC'
                    ))::date as flight_date,
                    departure_airport as airport_code,
                    arrival_airport as linked_airport_code,
                    COUNT(*) as flights_out,
                    COUNT(DISTINCT tf.ticket_no) as passengers_out
                FROM flights f
                LEFT JOIN ticket_flights tf ON f.flight_id = tf.flight_id
                WHERE 
                    -- Only include completed or in-progress flights
                    status IN ('Arrived', 'Departed')
                    -- Use UTC timestamp for consistent date handling
                    AND (COALESCE(
                        actual_departure AT TIME ZONE 'UTC',
                        scheduled_departure AT TIME ZONE 'UTC'
                    ))::date = (CURRENT_DATE AT TIME ZONE 'UTC') - INTERVAL '1 day'
                GROUP BY 
                    (COALESCE(
                        actual_departure AT TIME ZONE 'UTC',
                        scheduled_departure AT TIME ZONE 'UTC'
                    ))::date,
                    departure_airport,
                    arrival_airport
                HAVING COUNT(*) > 0  -- Only include routes with actual flights
            ),
            inbound_flights AS (
                -- Inbound flights (same as outbound but with swapped airports)
                SELECT 
                    flight_date,
                    linked_airport_code as airport_code,
                    airport_code as linked_airport_code,
                    flights_out as flights_in,
                    passengers_out as passengers_in
                FROM flight_counts
            )
            INSERT INTO presentation.airport_passenger_flow
            SELECT 
                CURRENT_TIMESTAMP AT TIME ZONE 'UTC' as created_at,
                fc.flight_date,
                fc.airport_code,
                fc.linked_airport_code,
                COALESCE(inf.flights_in, 0) as flights_in,
                fc.flights_out,
                COALESCE(inf.passengers_in, 0) as passengers_in,
                fc.passengers_out
            FROM flight_counts fc
            LEFT JOIN inbound_flights inf 
                ON fc.flight_date = inf.flight_date 
                AND fc.airport_code = inf.airport_code 
                AND fc.linked_airport_code = inf.linked_airport_code;
            
            -- Verify data consistency
            DO $$
            DECLARE
                invalid_data BOOLEAN;
                row_count INTEGER;
            BEGIN
                -- Check for invalid values
                SELECT EXISTS (
                    SELECT 1
                    FROM presentation.airport_passenger_flow
                    WHERE flight_date = (CURRENT_DATE AT TIME ZONE 'UTC') - INTERVAL '1 day'
                    AND (
                        flights_in < 0 OR flights_out < 0 OR
                        passengers_in < 0 OR passengers_out < 0 OR
                        airport_code IS NULL OR linked_airport_code IS NULL
                    )
                ) INTO invalid_data;
                
                IF invalid_data THEN
                    RAISE EXCEPTION 'Data validation failed: invalid values detected';
                END IF;
                
                -- Verify we have data for the target date
                SELECT COUNT(*)
                FROM presentation.airport_passenger_flow
                WHERE flight_date = (CURRENT_DATE AT TIME ZONE 'UTC') - INTERVAL '1 day'
                INTO row_count;
                
                IF row_count = 0 THEN
                    RAISE EXCEPTION 'No data found for target date';
                END IF;
            END $$;
            
            COMMIT;
        """,
        retries=3,
    )

    create_schema >> load_data
