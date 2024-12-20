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
    "frequent_flyer_mart",
    default_args=default_args,
    description="Frequent Flyer Data Mart",
    schedule_interval="0 0 * * *",  # Run daily at midnight
    start_date=days_ago(1),
    catchup=False,
    tags=["datamart", "frequent_flyers"],
    doc_md="""
    # Frequent Flyer Data Mart
    
    This DAG generates the frequent flyer data mart by analyzing passenger flight history.
    
    ## Source Tables
    - tickets
    - passengers
    - ticket_flights
    - flights
    
    ## Target Table
    - presentation.frequent_flyers
    
    ## Schedule
    Daily full refresh at midnight UTC
    """,
) as dag:
    create_schema = PostgresOperator(
        task_id="create_schema",
        postgres_conn_id="PROD_DB",
        sql="""
            CREATE SCHEMA IF NOT EXISTS presentation;
            
            CREATE TABLE IF NOT EXISTS presentation.frequent_flyers (
                created_at TIMESTAMP NOT NULL,
                passenger_id VARCHAR(20) NOT NULL,
                passenger_name TEXT NOT NULL,
                flights_number INTEGER NOT NULL,
                purchase_sum NUMERIC(10,2) NOT NULL,
                home_airport CHAR(3) NOT NULL,
                customer_group VARCHAR(3) NOT NULL,
                PRIMARY KEY (passenger_id)
            );
            
            -- Index for efficient customer group calculations
            CREATE INDEX IF NOT EXISTS idx_frequent_flyers_purchase_sum 
            ON presentation.frequent_flyers(purchase_sum DESC);
            
            -- Index for airport analysis
            CREATE INDEX IF NOT EXISTS idx_frequent_flyers_home_airport
            ON presentation.frequent_flyers(home_airport);
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
            
            WITH flight_stats AS (
                SELECT 
                    t.passenger_id,
                    COALESCE(p.passenger_name, 'Unknown') as passenger_name,
                    COUNT(DISTINCT f.flight_id) as flights_number,
                    SUM(tf.amount) as purchase_sum,
                    FIRST_VALUE(f.departure_airport) OVER (
                        PARTITION BY t.passenger_id 
                        ORDER BY COUNT(*) DESC, 
                                -- If counts are equal, prefer airport with more recent activity
                                MAX(COALESCE(f.actual_departure, f.scheduled_departure)) DESC,
                                f.departure_airport
                    ) as home_airport
                FROM tickets t
                LEFT JOIN passengers p ON t.passenger_id = p.passenger_id
                JOIN ticket_flights tf ON t.ticket_no = tf.ticket_no
                JOIN flights f ON tf.flight_id = f.flight_id
                WHERE f.status IN ('Arrived', 'Departed')  -- Only count completed or in-progress flights
                  AND f.scheduled_departure >= CURRENT_DATE - INTERVAL '1 year'  -- Consider last year's data
                GROUP BY t.passenger_id, p.passenger_name
                HAVING COUNT(DISTINCT f.flight_id) > 0  -- Only include passengers with actual flights
            ),
            percentiles AS (
                SELECT 
                    passenger_id,
                    passenger_name,
                    flights_number,
                    purchase_sum,
                    home_airport,
                    CASE 
                        WHEN PERCENT_RANK() OVER (ORDER BY purchase_sum DESC) <= 0.05 THEN '5'
                        WHEN PERCENT_RANK() OVER (ORDER BY purchase_sum DESC) <= 0.10 THEN '10'
                        WHEN PERCENT_RANK() OVER (ORDER BY purchase_sum DESC) <= 0.25 THEN '25'
                        WHEN PERCENT_RANK() OVER (ORDER BY purchase_sum DESC) <= 0.50 THEN '50'
                        ELSE '50+'
                    END as customer_group
                FROM flight_stats
            )
            INSERT INTO presentation.frequent_flyers
            SELECT 
                CURRENT_TIMESTAMP as created_at,
                passenger_id,
                passenger_name,
                flights_number,
                purchase_sum,
                home_airport,
                customer_group
            FROM percentiles
            ON CONFLICT (passenger_id) DO UPDATE 
            SET 
                created_at = EXCLUDED.created_at,
                passenger_name = EXCLUDED.passenger_name,
                flights_number = EXCLUDED.flights_number,
                purchase_sum = EXCLUDED.purchase_sum,
                home_airport = EXCLUDED.home_airport,
                customer_group = EXCLUDED.customer_group;
                
            -- Verify data consistency
            DO $$
            DECLARE
                invalid_data BOOLEAN;
            BEGIN
                SELECT EXISTS (
                    SELECT 1
                    FROM presentation.frequent_flyers
                    WHERE flights_number <= 0 
                       OR purchase_sum < 0
                       OR passenger_name IS NULL
                       OR home_airport IS NULL
                ) INTO invalid_data;
                
                IF invalid_data THEN
                    RAISE EXCEPTION 'Data validation failed: invalid values detected';
                END IF;
            END $$;
            
            COMMIT;
        """,
        retries=3,
    )

    create_schema >> load_data
