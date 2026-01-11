CREATE OR REPLACE VIEW admin.users_view AS
SELECT
    users.id,
    users.first_name,
    users.last_name,
    users.email,
    users.tel_number,

    (
        json_build_object(
            'id', cities.id,
            'country', json_build_object(
                'id', countries.id,
                'code', countries.code,
                'full_name', countries.full_name
            ),
            'name', cities.name
        )
    ) AS city,

    users.role,

    balances.payment AS payment_balance,
    balances.earning AS earning_balance,

    users.created_at,
    users.changed_at
FROM private.users AS users
JOIN private.cities AS cities ON users.city_id = cities.id
JOIN private.countries AS countries ON cities.country_id = countries.id
JOIN private.balances AS balances ON balances.user_id = users.id;

CREATE OR REPLACE VIEW admin.clients_stat_view AS
SELECT
    users.id,

    COUNT(orders.id) AS rides_count,
    COUNT(orders.id) FILTER (WHERE orders.status = 'completed') AS finished_rides_count,
    COUNT(orders.id) FILTER (WHERE orders.status = 'canceled') AS canceled_rides_count,
    AVG(routes.distance) AS average_distance,
    MAX(routes.distance) AS max_distance,
    AVG(order_ratings.mark) AS client_rating,
    ARRAY_AGG(order_client_tags.tag)
        FILTER (WHERE order_client_tags.tag IS NOT NULL)
        AS all_tags
FROM private.users AS users
LEFT JOIN private.orders AS orders ON orders.client_id = users.id
LEFT JOIN private.routes AS routes ON routes.order_id = orders.id
LEFT JOIN private.order_ratings AS order_ratings ON order_ratings.order_id = orders.id AND order_ratings.mark_by != orders.client_id
LEFT JOIN private.order_client_tags AS order_client_tags ON order_client_tags.order_id = orders.id
GROUP BY users.id;

CREATE OR REPLACE VIEW admin.drivers_stat_view AS
SELECT
    users.id,
    (
        CASE
            WHEN cars.id IS NULL THEN NULL
        ELSE
            json_build_object(
                'id', cars.id,
                'mark', cars.mark,
                'model', cars.model,
                'number_plate', cars.number_plate,
                'color', cars.color,
                'car_class', cars.car_class,
                'car_status', cars.car_status,
                'created_at', cars.created_at,
                'changed_at', cars.changed_at
            )
        END
    ) AS car,
    COUNT(orders.id) AS rides_count,
    COUNT(orders.id) FILTER (WHERE orders.status = 'completed') AS finished_rides_count,
    COUNT(orders.id) FILTER (WHERE orders.status = 'canceled') AS canceled_rides_count,
    AVG(routes.distance) AS average_distance,
    MAX(routes.distance) AS max_distance,
    AVG(order_ratings.mark) AS driver_rating,
    ARRAY_AGG(order_driver_tags.tag)
        FILTER (WHERE order_driver_tags.tag IS NOT NULL)
        AS all_tags
FROM private.users AS users
LEFT JOIN private.cars AS cars ON cars.driver_id = users.id
LEFT JOIN private.orders AS orders ON orders.driver_id = users.id
LEFT JOIN private.routes AS routes ON routes.order_id = orders.id
LEFT JOIN private.order_ratings AS order_ratings ON order_ratings.order_id = orders.id AND order_ratings.mark_by != orders.driver_id
LEFT JOIN private.order_driver_tags AS order_driver_tags ON order_driver_tags.order_id = orders.id
WHERE users.role = 'driver'
GROUP BY users.id, cars.id;

CREATE OR REPLACE VIEW admin.cars_view AS
SELECT
    cars.id,
    (
        CASE
            WHEN cars.driver_id IS NULL THEN NULL
        ELSE
            json_build_object(
                'id', users.id,
                'first_name', users.first_name,
                'last_name', users.last_name,
                'email', users.email,
                'tel_number', users.tel_number,
                'role', users.role,
                'payment_balance', users.payment_balance,
                'earning_balance', users.earning_balance,
                'created_at', users.created_at,
                'changed_at', users.changed_at
            )
        END
    ) AS driver,
    cars.mark,
    cars.model,
    cars.number_plate,
    (
        json_build_object(
            'id', cities.id,
            'country', json_build_object(
                'id', countries.id,
                'code', countries.code,
                'full_name', countries.full_name
            ),
            'name', cities.name
        )
    ) AS city,
    cars.color,
    cars.car_class,
    cars.car_status,
    cars.created_at,
    cars.changed_at
FROM private.cars AS cars
LEFT JOIN admin.users_view AS users ON users.id = cars.driver_id
JOIN private.cities AS cities ON cities.id = cars.city_id
JOIN private.countries AS countries ON countries.id = cities.country_id;

CREATE OR REPLACE VIEW admin.orders_view AS
SELECT
    orders.id,
    (
        json_build_object(
            'id', users.id,
            'first_name', users.first_name,
            'last_name', users.last_name,
            'email', users.email,
            'tel_number', users.tel_number,
            'city', users.city,
            'city', users.city,
            'role', users.role,
            'payment_balance', users.payment_balance,
            'earning_balance', users.earning_balance,
            'created_at', users.created_at,
            'changed_at', users.changed_at
        )
    ) AS client,
    (
        CASE
            WHEN drivers.id IS NULL THEN NULL
        ELSE
            json_build_object(
                'id', drivers.id,
                'first_name', drivers.first_name,
                'last_name', drivers.last_name,
                'email', drivers.email,
                'tel_number', drivers.tel_number,
                'city', drivers.city,
                'role', drivers.role,
                'payment_balance', drivers.payment_balance,
                'earning_balance', drivers.earning_balance,
                'created_at', drivers.created_at,
                'changed_at', drivers.changed_at
            )
        END
    ) AS driver,
    (
        json_build_object(
            'id', transactions.id,
            'balance_type', transactions.balance_type,
            'transaction_type', transactions.transaction_type,
            'payment_method', transactions.payment_method,
            'amount', transactions.amount,
            'created_at', transactions.created_at
        )
    ) AS transaction,
    (
        json_build_object(
            'id', routes.id,
            'start_location', routes.start_location,
            'end_location', routes.end_location,
            'distance', routes.distance,
            'all_addresses', route_points.all_addresses
        )
    ) AS route,
    orders.status,
    orders.order_class,
    orders.finished_at,
    orders.created_at,
    orders.changed_at
FROM private.orders AS orders
JOIN admin.users_view AS users ON orders.client_id = users.id
JOIN private.transactions AS transactions ON transactions.id = orders.transaction_id
JOIN private.routes AS routes ON routes.order_id = orders.id
JOIN LATERAL (
    SELECT ARRAY_AGG(route_points.location) AS all_addresses
    FROM private.route_points AS route_points
    WHERE route_points.route_id = routes.id
) AS route_points ON true
LEFT JOIN admin.users_view AS drivers ON orders.driver_id = drivers.id;

CREATE OR REPLACE VIEW admin.orders_stat_view AS
SELECT
    orders.id,
    (
        CASE
            WHEN client_rating.id IS NULL THEN NULL
        ELSE
            json_build_object(
                'id', client_rating.id,
                'mark', client_rating.mark,
                'created_at', client_rating.created_at
            )
        END
    ) rating_by_client,
    (
        CASE
            WHEN driver_rating.id IS NULL THEN NULL
        ELSE
            json_build_object(
                'id', driver_rating.id,
                'mark', driver_rating.mark,
                'created_at', driver_rating.created_at
            )
        END
    ) AS rating_by_driver,
    (
        CASE
            WHEN cancels.id IS NULL THEN NULL
        ELSE
            json_build_object(
                'id', cancels.id,
                'canceled_by', cancels.canceled_by,
                'comment', cancels.comment,
                'created_at', cancels.created_at
            )
        END
    ) AS cancel_info,
    (orders.finished_at - orders.created_at):: interval AS duration
FROM private.orders AS orders
LEFT JOIN private.order_ratings AS client_rating ON client_rating.order_id = orders.id AND client_rating.mark_by = orders.client_id
LEFT JOIN private.order_ratings AS driver_rating ON driver_rating.order_id = orders.id AND driver_rating.mark_by = orders.driver_id
LEFT JOIN private.order_cancels AS cancels ON cancels.order_id = orders.id;

CREATE OR REPLACE VIEW admin.maintenances_view AS
SELECT
    maintenances.id,
    (
        json_build_object(
            'id', cars.id,
            'mark', cars.mark,
            'driver', cars.driver,
            'model', cars.model,
            'number_plate', cars.number_plate,
            'city', cars.city,
            'color', cars.color,
            'car_class', cars.car_class,
            'car_status', cars.car_status,
            'created_at', cars.created_at,
            'changed_at', cars.changed_at
        )
    ) AS car,
    maintenances.description,
    maintenances.cost,
    maintenances.maintenance_start,
    maintenances.maintenance_end,
    maintenances.created_at,
    maintenances.changed_at,
    maintenances.status
FROM private.maintenances AS maintenances
JOIN admin.cars_view AS cars ON cars.id = maintenances.car_id;

CREATE OR REPLACE VIEW admin.transactions_view AS
SELECT
    transactions.id,
    (
        json_build_object(
            'id', users.id,
            'first_name', users.first_name,
            'last_name', users.last_name,
            'email', users.email,
            'tel_number', users.tel_number,
            'city', users.city,
            'role', users.role,
            'payment_balance', users.payment_balance,
            'earning_balance', users.earning_balance,
            'created_at', users.created_at,
            'changed_at', users.changed_at
        )
    ) AS "user",
    transactions.balance_type,
    transactions.transaction_type,
    transactions.payment_method,
    transactions.amount,
    transactions.created_at
FROM private.transactions AS transactions
JOIN admin.users_view AS users ON users.id = transactions.user_id;

CREATE OR REPLACE VIEW public.countries_view AS
SELECT
    id,
    code,
    full_name
FROM private.countries;

CREATE OR REPLACE VIEW public.cities_view AS
SELECT
    cities.id,
    json_build_object(
        'id', countries.id,
        'code', countries.code,
        'full_name', countries.full_name
    ) AS country,
    cities.name
FROM private.cities
JOIN private.countries ON cities.country_id = countries.id;