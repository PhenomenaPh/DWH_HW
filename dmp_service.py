import hashlib
import json
import logging
from datetime import datetime

import psycopg2
from kafka import KafkaConsumer

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configurations
DWH_CONFIG = {
    "dbname": "airline_tickets_dwh",
    "user": "admin",
    "password": "adminpassword",
    "host": "db_dwh",
    "port": "5432",
}

# Kafka configuration
KAFKA_BOOTSTRAP_SERVERS = ["kafka:29092"]
SOURCE_SYSTEM_ID = 1
RECORD_SOURCE = "airline_tickets_db"


def create_hash(data_dict):
    """Create a hash from dictionary values"""
    sorted_items = sorted(data_dict.items())
    data_str = "".join(str(v) for k, v in sorted_items)
    return hashlib.md5(data_str.encode()).hexdigest()


def connect_to_dwh():
    """Create connection to DWH"""
    return psycopg2.connect(**DWH_CONFIG)


def process_airport_message(data, operation, conn):
    """Process airport messages and update DWH"""
    cur = conn.cursor()
    try:
        if operation in ["c", "u"]:  # create or update
            # Generate hash key
            airport_hash = create_hash({"airport_code": data["airport_code"]})

            # Insert into hub_airports if not exists
            cur.execute(
                """
                INSERT INTO dwh_detailed.hub_airports 
                (airport_hash_key, airport_code, load_date, record_source, source_system_id)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (airport_hash_key) DO NOTHING
                RETURNING airport_hub_id
            """,
                (
                    airport_hash,
                    data["airport_code"],
                    datetime.now(),
                    RECORD_SOURCE,
                    SOURCE_SYSTEM_ID,
                ),
            )

            result = cur.fetchone()
            if not result:
                cur.execute(
                    "SELECT airport_hub_id FROM dwh_detailed.hub_airports WHERE airport_hash_key = %s",
                    (airport_hash,),
                )
                result = cur.fetchone()

            airport_hub_id = result[0]

            # Insert into sat_airport_details
            hash_diff = create_hash(data)
            cur.execute(
                """
                INSERT INTO dwh_detailed.sat_airport_details 
                (airport_hub_id, load_date, airport_name, city, coordinates_lon, coordinates_lat, 
                timezone, record_source, source_system_id, hash_diff)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
                (
                    airport_hub_id,
                    datetime.now(),
                    data["airport_name"],
                    data["city"],
                    data["coordinates_lon"],
                    data["coordinates_lat"],
                    data["timezone"],
                    RECORD_SOURCE,
                    SOURCE_SYSTEM_ID,
                    hash_diff,
                ),
            )

        conn.commit()
        logger.info(f"Successfully processed airport {operation} operation")
    except Exception as e:
        conn.rollback()
        logger.error(f"Error processing airport message: {str(e)}")
        raise
    finally:
        cur.close()


def process_aircraft_message(data, operation, conn):
    """Process aircraft messages and update DWH"""
    cur = conn.cursor()
    try:
        if operation in ["c", "u"]:
            aircraft_hash = create_hash({"aircraft_code": data["aircraft_code"]})

            cur.execute(
                """
                INSERT INTO dwh_detailed.hub_aircrafts 
                (aircraft_hash_key, aircraft_code, load_date, record_source, source_system_id)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (aircraft_hash_key) DO NOTHING
                RETURNING aircraft_hub_id
            """,
                (
                    aircraft_hash,
                    data["aircraft_code"],
                    datetime.now(),
                    RECORD_SOURCE,
                    SOURCE_SYSTEM_ID,
                ),
            )

            result = cur.fetchone()
            if not result:
                cur.execute(
                    "SELECT aircraft_hub_id FROM dwh_detailed.hub_aircrafts WHERE aircraft_hash_key = %s",
                    (aircraft_hash,),
                )
                result = cur.fetchone()

            aircraft_hub_id = result[0]

            hash_diff = create_hash(data)
            cur.execute(
                """
                INSERT INTO dwh_detailed.sat_aircraft_details 
                (aircraft_hub_id, load_date, model, range, record_source, source_system_id, hash_diff)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
                (
                    aircraft_hub_id,
                    datetime.now(),
                    json.dumps(data["model"]),
                    data["range"],
                    RECORD_SOURCE,
                    SOURCE_SYSTEM_ID,
                    hash_diff,
                ),
            )

        conn.commit()
        logger.info(f"Successfully processed aircraft {operation} operation")
    except Exception as e:
        conn.rollback()
        logger.error(f"Error processing aircraft message: {str(e)}")
        raise
    finally:
        cur.close()


def main():
    """Main function to consume Kafka messages and process them"""
    consumer = KafkaConsumer(
        "airline.public.airports",
        "airline.public.aircrafts",
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        value_deserializer=lambda x: json.loads(x.decode("utf-8")),
        auto_offset_reset="earliest",
        enable_auto_commit=False,
        group_id="dmp_consumer_group",
    )

    conn = connect_to_dwh()

    try:
        for message in consumer:
            try:
                topic = message.topic
                value = message.value

                if "payload" not in value:
                    continue

                payload = value["payload"]
                operation = payload.get("op")  # c=create, u=update, d=delete

                if operation not in ["c", "u", "d"]:
                    continue

                data = (
                    payload.get("after") if operation != "d" else payload.get("before")
                )

                if not data:
                    continue

                if topic == "airline.public.airports":
                    process_airport_message(data, operation, conn)
                elif topic == "airline.public.aircrafts":
                    process_aircraft_message(data, operation, conn)

                consumer.commit()
                logger.info(f"Successfully processed message from topic {topic}")

            except Exception as e:
                logger.error(f"Error processing message: {str(e)}")
                continue

    except Exception as e:
        logger.error(f"Fatal error: {str(e)}")
    finally:
        conn.close()
        consumer.close()


if __name__ == "__main__":
    while True:
        try:
            main()
        except Exception as e:
            logger.error(f"Main loop error: {str(e)}")
            continue
