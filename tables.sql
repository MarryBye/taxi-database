CREATE TABLE IF NOT EXISTS private.countries (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR(2) NOT NULL UNIQUE,
    full_name VARCHAR(32) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS private.cities (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_id BIGINT NOT NULL REFERENCES private.countries(id),
    name VARCHAR(32) NOT NULL UNIQUE,
    UNIQUE(country_id, name)
);

CREATE TABLE IF NOT EXISTS private.users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    login VARCHAR(32) NOT NULL UNIQUE,
    password_hash VARCHAR(512) NOT NULL,
    first_name VARCHAR(32) NOT NULL,
    last_name VARCHAR(32) NOT NULL,
    email VARCHAR(128) NOT NULL UNIQUE CHECK (public.check_email(email)),
    tel_number VARCHAR(32) NOT NULL UNIQUE CHECK (public.check_tel(tel_number)),
    city_id BIGINT NOT NULL REFERENCES private.cities(id),
    role public.user_roles NOT NULL DEFAULT 'client',

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.cars (
	id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    driver_id BIGINT UNIQUE REFERENCES private.users(id) ON DELETE SET NULL,
	mark VARCHAR(32) NOT NULL,
	model VARCHAR(32) NOT NULL,
	number_plate VARCHAR(32) UNIQUE NOT NULL CHECK (public.check_car_number(number_plate)),
    city_id BIGINT NOT NULL REFERENCES private.cities(id),
    color public.colors NOT NULL,
	car_class public.car_classes NOT NULL DEFAULT 'standard',
    car_status public.car_statuses NOT NULL DEFAULT 'available',

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.transactions (
	id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	user_id BIGINT NOT NULL REFERENCES private.users(id) ON DELETE CASCADE,
    balance_type public.balance_types NOT NULL,
    transaction_type public.transaction_type NOT NULL,
    payment_method public.payment_methods NOT NULL,
    amount NUMERIC NOT NULL DEFAULT 0 CHECK (amount >= 0),

    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.orders (
	id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	client_id BIGINT NOT NULL REFERENCES private.users(id) ON DELETE CASCADE,
    driver_id BIGINT REFERENCES private.users(id) ON DELETE SET NULL,
    transaction_id BIGINT NOT NULL UNIQUE REFERENCES private.transactions(id),
    status public.order_statuses NOT NULL DEFAULT 'searching_for_driver',
    order_class public.car_classes NOT NULL DEFAULT 'standard',
    finished_at TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.order_ratings (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES private.orders(id) ON DELETE CASCADE,
    mark_by BIGINT NOT NULL REFERENCES private.users(id) ON DELETE CASCADE,
    mark NUMERIC NOT NULL CHECK (mark >= 0 AND mark <= 5),
    comment VARCHAR(256),
    UNIQUE (order_id, mark_by),

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.order_cancels (
	id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	order_id BIGINT NOT NULL UNIQUE REFERENCES private.orders(id) ON DELETE CASCADE,
	canceled_by BIGINT NOT NULL REFERENCES private.users(id) ON DELETE CASCADE,
	comment VARCHAR(256),

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    changed_at TIMESTAMP NOT NULL DEFAULT NOW(),

    UNIQUE(order_id, canceled_by)
);

CREATE TABLE IF NOT EXISTS private.order_client_tags (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES private.orders(id) ON DELETE CASCADE,
    tag VARCHAR(32) NOT NULL,
    UNIQUE(order_id, tag),

    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.order_driver_tags (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES private.orders(id) ON DELETE CASCADE,
    tag VARCHAR(32) NOT NULL,
    UNIQUE(order_id, tag),

    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.balances (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE REFERENCES private.users(id) ON DELETE CASCADE,
    payment NUMERIC NOT NULL DEFAULT 0 CHECK (payment >= 0),
    earning NUMERIC NOT NULL DEFAULT 0 CHECK (earning >= 0),

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.routes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL UNIQUE REFERENCES private.orders(id) ON DELETE CASCADE,
    start_location public.address NOT NULL,
    end_location public.address NOT NULL,
    distance NUMERIC NOT NULL CHECK (distance >= 0)
);

CREATE TABLE IF NOT EXISTS private.route_points (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id BIGINT NOT NULL REFERENCES private.routes(id) ON DELETE CASCADE,
    position_index INT NOT NULL CHECK (position_index >= 0),
    location public.address NOT NULL,
    UNIQUE (route_id, position_index)
);

CREATE TABLE IF NOT EXISTS private.maintenances (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    car_id BIGINT NOT NULL REFERENCES private.cars(id) ON DELETE CASCADE,
    description VARCHAR(2048) NOT NULL,
    cost NUMERIC NOT NULL DEFAULT 0 CHECK (cost >= 0),
    status public.maintenance_statuses NOT NULL DEFAULT 'diagnosis',
    maintenance_start TIMESTAMP NOT NULL DEFAULT NOW(),
    maintenance_end TIMESTAMP NOT NULL DEFAULT NOW() + INTERVAL '7 DAY',

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);