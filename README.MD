# Система бронирования авиабилетов с репликацией PostgreSQL

Этот проект представляет собой систему бронирования авиабилетов, использующую PostgreSQL с настроенной репликацией, хранилищем данных (DWH) и системой CDC, работающую в Docker.

## Структура проекта

- `docker-compose.yml`: Конфигурация Docker Compose для всех сервисов
- `init.sql`: SQL-скрипт для инициализации репликации
- `schema.sql`: SQL-скрипт для создания структуры базы данных
- `create_views.sql`: SQL-скрипт для создания представления статистики аэропортов
- `dwh_schema.sql`: SQL-скрипт для создания структуры хранилища данных
- `connector.json`: Конфигурация Debezium коннектора
- `dmp_service.py`: Сервис обработки данных для DWH
- `requirements.txt`: Зависимости Python для DMP сервиса

## Установка и запуск

### Шаги установки

1. Клонировать репозиторий:
```bash
git clone <repository-url>
cd <repository-name>
```

2. Запустить все сервисы:
```bash
docker-compose up -d
```

3. Дождаться полной инициализации (обычно 1-2 минуты). Все компоненты системы запустятся автоматически:
   - PostgreSQL Primary DB
   - PostgreSQL Replica DB
   - PostgreSQL DWH
   - Zookeeper
   - Kafka
   - Debezium с автоматической настройкой коннектора
   - DMP сервис

### Проверка работоспособности

1. Проверка статуса баз данных:
```bash
# Primary DB
psql -h localhost -p 5432 -U admin -d airline_tickets -c "SELECT version();"

# Replica DB
psql -h localhost -p 5433 -U admin -d airline_tickets -c "SELECT version();"

# DWH
psql -h localhost -p 5434 -U admin -d airline_tickets_dwh -c "SELECT version();"
```

2. Проверка репликации:
```bash
# На Primary DB
psql -h localhost -p 5432 -U admin -d airline_tickets -c "INSERT INTO airports VALUES ('XXX', 'Test Airport', 'Test City', 0, 0, 'UTC');"

# На Replica DB (должна появиться новая запись)
psql -h localhost -p 5433 -U admin -d airline_tickets -c "SELECT * FROM airports WHERE airport_code = 'XXX';"
```

3. Проверка CDC и DWH:
```bash
# Проверка топиков Kafka
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092

# Проверка данных в DWH
psql -h localhost -p 5434 -U admin -d airline_tickets_dwh -c "SELECT * FROM dwh_detailed.hub_airports;"
```

4. Проверка представления статистики:
```bash
# На Primary DB
psql -h localhost -p 5432 -U admin -d airline_tickets -c "SELECT * FROM airport_traffic;"

# На Replica DB (результаты должны совпадать)
psql -h localhost -p 5433 -U admin -d airline_tickets -c "SELECT * FROM airport_traffic;"
```

### Доступы к сервисам

1. База данных (Primary и Replica):
   - Пользователь: admin
   - Пароль: adminpassword
   - База данных: airline_tickets

2. Хранилище данных (DWH):
   - Пользователь: admin
   - Пароль: adminpassword
   - База данных: airline_tickets_dwh

3. Kafka:
   - Порт: 9092
   - Bootstrap сервер: localhost:9092

4. Debezium:
   - REST API: http://localhost:8083
   - Топики: airline.public.*

### Мониторинг

1. Логи сервисов:
```bash
# Логи DMP сервиса
docker logs dmp_service

# Логи Debezium
docker logs debezium

# Логи Primary DB
docker logs postgres_primary
```

2. Статус Debezium коннектора:
```bash
curl -X GET http://localhost:8083/connectors/airline-connector/status
```

### Остановка и очистка

1. Остановка всех сервисов:
```bash
docker-compose down
```

2. Полная очистка (включая данные):
```bash
docker-compose down -v
```

## Проверка работоспособности

1. Подключитесь к первичной базе данных:
   ```
   docker exec -it postgres_primary psql -U admin -d airline_tickets
   ```

2. Выполните запрос к представлению статистики аэропортов:
   ```sql
   SELECT * FROM airport_traffic;
   ```

   Вы должны увидеть статистику по трафику для каждого аэропорта.

3. Проверьте репликацию, подключившись к реплике и выполнив тот же запрос:
   ```
   docker exec -it postgres_replica psql -U admin -d airline_tickets
   ```
   ```sql
   SELECT * FROM airport_traffic;
   ```

   Результа��ы должны совпадать с результатами на первичном сервере.

## Структура базы данных

База данных содержит следующие таблицы:
- `airports`: информация об аэропортах
- `aircrafts`: данные о самолетах
- `seats`: информация о местах в самолетах
- `flights`: данные о рейсах
- `bookings`: информация о бронированиях
- `tickets`: данные о билетах
- `ticket_flights`: связь между билетами и рейсами
- `boarding_passes`: информация о посадочных талонах

## Представление `airport_traffic`

Представление `airport_traffic` предоставляет статистику по каждому аэропорту в формате:
```
airport_code | departure_flights_num | departure_psngr_num | arrival_flights_num | arrival_psngr_num
```

Где:
- `airport_code`: код аэропорта
- `departure_flights_num`: количество вылетающих рейсов
- `departure_psngr_num`: количество вылетающих пассажиров
- `arrival_flights_num`: количество прибывающих рейсов
- `arrival_psngr_num`: количество прибывающих пассажиров

## Дополнительная информация

- Первичный сервер PostgreSQL доступен на порту 5432
- Реплика PostgreSQL доступна на порту 5433
- Пользователь базы данных: admin
- Пароль: adminpassword
- Имя базы данных: airline_tickets

## Дополнение
- Особая благодарность этой статье [тык](https://medium.com/@eremeykin/how-to-setup-single-primary-postgresql-replication-with-docker-compose-98c48f233bbf) за вдохновление и избавления от головной боли.

## Архитектура хранилища данных (DWH)

Для реализации детального слоя хранилища данных была выбрана архитектура Data Vault 2.0. Данный выбор обоснован следующими причинами:

1. **Историчность данных**: Data Vault 2.0 обеспечивает полное сохранение истории изменений данных, что критично для систем бронирования билетов.

2. **Масштабируемость**: Архитектура легко расширяется ��ри добавлении новых источников данных или изменении бизнес-требований.

3. **Аудит и отслеживание**: Встроенная поддержка метаданных и отслеживания происхождения данных позволяет точно определить источник и время каждого изменения.

4. **Производительность**: Оптимизирована для параллельной загрузки данных, что важно при работе с большим количеством транзакций бронирования.

5. **Гибкость интеграции**: Позволяет легко интегрировать данные из различных источников, сохраняя их целостность и происхождение.

Структура DWH размещена в схеме `dwh_detailed` и включает в себя:
- Хабы (Hubs) для основных бизнес-сущностей (аэропорты, самолеты, пассажиры)
- Линки (Links) для связей между сущностями
- Сателлиты (Satellites) для хранения атрибутов и их изменений во времени

Каждая таблица в DWH содержит технические поля:
- `source_system_id`: идентификатор системы-источника
- `load_date`: дата и время загрузки записи
- `record_source`: источник записи
- `hash_key`: уникальный хеш-ключ для обеспечения целостности данных

ER-диаграмма структуры DWH доступна в файле `dwh_schema.png`.

## Интеграция с Debezium для CDC (Change Data Capture)

В проект добавлена система отслеживания изменений данных с использованием Debezium. Это позволяет в реальном времени отслеживать все изменения в основной базе данных и передавать их в Kafka для дальнейшей обработки.

### Компоненты системы CDC

- **Apache Kafka** (порт 9092)
  - Брокер сообщений для хранения и передачи событий изменения данных
  - Обеспечивает масштабируемость и надежность доставки сообщений

- **Zookeeper** (порт 2181)
  - Координационный се��вис для Kafka
  - Управляет конфигурацией и состоянием кластера

- **Debezium Connect** (порт 8083)
  - Коннектор для захвата изменений из PostgreSQL
  - Преобразует изменения в события Kafka
  - Поддерживает отслеживание INSERT, UPDATE и DELETE операций

### Конфигурация

Основная база данных настроена для поддержки логической репликации:
```
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
```

Debezium коннектор настроен для отслеживания схемы `public` и публикации событий в топики формата:
```
airline.public.<имя_таблицы>
```

### Проверка работоспособности

Для проверки статуса коннектора:
```bash
curl -X GET http://localhost:8083/connectors/airline-connector/status
```

Для просмотра топиков Kafka:
```bash
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092
```

## Сервис DMP (Data Management Platform)

Для обработки данных из Kafka и загрузки их в хранилище данных реализован Python-сервис DMP. Сервис работает в отдельном контейнере и выполняет следующие функции:

- Чтение данных об изменениях из Kafka топиков
- Преобразование данных в формат Data Vault 2.0
- Загрузка данных в хранилище с учетом историчности

### Архитектура сервиса

Сервис реализует следующую логику обработки данных:
1. Подключение к Kafka и просл��шивание топиков с изменениями
2. Обработка сообщений о создании/обновлении/удалении записей
3. Формирование хеш-ключей для Hub и Satellite таблиц
4. Загрузка данных в соответствующие таблицы DWH

### Обработка данных

Для каждой сущности реализована своя логика обработки:
- Создание записи: добавление в Hub (если новая) и добавление в Satellite
- Обновление записи: добавление новой версии в Satellite
- Удаление: не удаляе�� данные физически (соблюдение принципа историчности)