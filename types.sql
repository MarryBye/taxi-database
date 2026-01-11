CREATE TYPE public.car_statuses AS ENUM (
    'available',
    'on_maintenance',
    'busy',
    'not_working'
);

CREATE TYPE public.car_classes AS ENUM (
    'standard',
    'comfort',
    'business'
);

CREATE TYPE public.maintenance_statuses AS ENUM (
    'diagnosis',
    'in_progress',
    'completed'
);

CREATE TYPE public.order_statuses AS ENUM (
    'searching_for_driver',
    'waiting_for_driver',
    'waiting_for_client',
    'in_progress',
    'waiting_for_marks',
    'canceled',
    'completed'
);

CREATE TYPE public.transaction_type AS ENUM (
    'debit',
    'credit',
    'refund',
    'penalty'
);

CREATE TYPE public.payment_methods AS ENUM (
    'credit_card',
    'cash'
);

CREATE TYPE public.balance_types AS ENUM (
    'payment',
    'earning'
);

CREATE TYPE public.user_roles AS ENUM (
    'admin',
    'driver',
    'client',
    'guest'
);

CREATE TYPE public.client_tags AS ENUM (
    'accurate',
    'friendly',
    'respectful',
    'communicative',
    'polite',
    'on_time',
    'clear_instructions',
    'calm',
    'helpful',
    'other'
);


CREATE TYPE public.driver_tags AS ENUM (
    'accurate',
    'fast',
    'friendly',
    'clean',
    'modern_car',
    'polite',
    'communicative',
    'helpful',
    'smooth_driving',
    'safe_driving',
    'good_navigation',
    'other'
);


CREATE TYPE public.driver_cancel_tags AS ENUM (
    'client_not_responding',
    'client_not_at_pickup_point',
    'vehicle_breakdown',
    'traffic_accident',
    'unsafe_pickup_location',
    'route_unreachable',
    'emergency',
    'other'
);


CREATE TYPE public.client_cancel_tags AS ENUM (
    'driver_too_far',
    'long_wait_time',
    'changed_plans',
    'wrong_pickup_location',
    'found_another_transport',
    'driver_not_responding',
    'price_too_high',
    'emergency',
    'other'
);

CREATE TYPE public.colors AS ENUM (
    'red',
    'blue',
    'green',
    'black',
    'white',
    'yellow',
    'orange',
    'purple',
    'brown',
    'pink',
    'gray',
    'silver',
    'gold'
);

CREATE TYPE public.address AS (
	country VARCHAR(32),
	city VARCHAR(32),
	street VARCHAR(32),
	house VARCHAR(9)
);