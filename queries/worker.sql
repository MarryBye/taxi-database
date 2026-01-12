CREATE OR REPLACE FUNCTION workers.orders_history()
RETURNS SETOF admin.orders_view
SECURITY DEFINER
SET search_path = private, admin, workers, public
AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN QUERY
        SELECT *
        FROM admin.orders_view AS orders
        WHERE (orders.driver->>'id')::BIGINT = user_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION workers.acceptable_orders()
    RETURNS SETOF admin.orders_view
    SECURITY DEFINER
    SET search_path = private, admin, workers, public
AS $$
DECLARE
    v_user_id BIGINT := public.get_current_user_from_session();
    v_city_id BIGINT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    SELECT u.city_id
    INTO v_city_id
    FROM private.users u
    WHERE u.id = v_user_id;

    IF v_city_id IS NULL THEN
        RAISE EXCEPTION 'Driver city not found';
    END IF;

    RETURN QUERY
        SELECT o.*
        FROM admin.orders_view o
        WHERE
            o.driver IS NULL
          AND o.status = 'searching_for_driver'
          AND (o.client->'city'->>'id')::BIGINT = v_city_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workers.get_driver_order(
    p_order_id BIGINT
)
    RETURNS admin.orders_view
    SECURITY DEFINER
    SET search_path = private, admin, workers, public
AS $$
DECLARE
    v_user_id BIGINT := public.get_current_user_from_session();
    v_city_id BIGINT;
    v_order admin.orders_view;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    SELECT u.city_id
    INTO v_city_id
    FROM private.users u
    WHERE u.id = v_user_id;

    IF v_city_id IS NULL THEN
        RAISE EXCEPTION 'Driver city not found';
    END IF;

    SELECT o.*
    INTO v_order
    FROM admin.orders_view o
    WHERE
        o.id = p_order_id
      AND (
        (o.driver IS NOT NULL AND (o.driver->>'id')::BIGINT = v_user_id) OR
        (
            o.driver IS NULL
                AND o.status = 'searching_for_driver'
                AND (o.client->'city'->>'id')::BIGINT = v_city_id
            )
        );

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Access denied or order not found';
    END IF;

    RETURN v_order;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION workers.accept_order(
    p_order_id BIGINT
)
RETURNS SETOF admin.orders_view
SECURITY DEFINER
SET search_path = private, admin, workers, public
AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    UPDATE private.orders AS o
    SET
        driver_id = user_id,
        status = 'waiting_for_driver',
        changed_at = NOW()
    WHERE
        o.id = p_order_id
        AND o.driver_id IS NULL
        AND o.status = 'searching_for_driver';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order cannot be accepted';
    END IF;

    RETURN QUERY
        SELECT * FROM admin.orders_view
        WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION workers.cancel_order(
    p_order_id BIGINT,
    p_comment VARCHAR(256),
    p_tags VARCHAR(32)[]
)
RETURNS SETOF admin.orders_stat_view
SECURITY DEFINER
SET search_path = private, admin, workers, public
AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
    tag VARCHAR(32);
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM private.orders
        WHERE id = p_order_id
          AND driver_id = user_id
    ) THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF array_length(p_tags, 1) NOT BETWEEN 1 AND 3 THEN
        RAISE EXCEPTION 'Invalid number of tags';
    END IF;

    UPDATE private.orders
    SET status = 'canceled',
        changed_at = NOW()
    WHERE id = p_order_id
      AND driver_id = user_id;

    INSERT INTO private.order_cancels(order_id, canceled_by, comment)
    VALUES (p_order_id, user_id, p_comment);

    FOREACH tag IN ARRAY p_tags LOOP
        INSERT INTO private.order_driver_tags(order_id, tag)
        VALUES (p_order_id, tag);
    END LOOP;

    RETURN QUERY
        SELECT *
        FROM admin.orders_stat_view
        WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION workers.current_order()
RETURNS SETOF admin.orders_view
SECURITY DEFINER
SET search_path = private, admin, workers, public
AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN QUERY
        SELECT *
        FROM admin.orders_view
        WHERE
            (driver->>'id')::BIGINT = user_id
            AND status NOT IN ('completed', 'canceled');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workers.order_stat(
    p_order_id BIGINT
)
RETURNS SETOF admin.orders_stat_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN QUERY
        SELECT * FROM admin.orders_stat_view AS orders WHERE orders.id = p_order_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workers.rate_order(
    p_order_id BIGINT,
    p_mark INT,
    p_comment VARCHAR(256),
    p_tags VARCHAR(32)[]
)
RETURNS SETOF admin.orders_stat_view
SECURITY DEFINER
SET search_path = private, admin, workers, public
AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
    tag VARCHAR(32);
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    IF NOT (SELECT EXISTS(
        SELECT 1 FROM private.orders AS orders WHERE orders.id = p_order_id AND orders.driver_id = user_id
    )) THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF (array_length(p_tags, 1) < 1) OR (array_length(p_tags, 1) > 3) THEN
        RAISE EXCEPTION 'Invalid number of tags';
    END IF;

    INSERT INTO private.order_ratings(order_id, mark_by, mark, comment)
    VALUES (p_order_id, user_id, p_mark, p_comment);

    FOREACH tag IN ARRAY p_tags LOOP
        INSERT INTO private.order_client_tags(order_id, tag)
        VALUES (p_order_id, tag);
    END LOOP;

    RETURN QUERY
        SELECT * FROM admin.orders_stat_view WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workers.submit_arrival()
RETURNS SETOF admin.orders_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
    current_order admin.orders_view%ROWTYPE := workers.current_order();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    UPDATE private.orders AS orders
    SET
        status = 'waiting_for_client'
    WHERE orders.id = current_order.id AND orders.driver_id = user_id;

    RETURN QUERY SELECT * FROM admin.orders_view WHERE id = current_order.id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workers.submit_start()
RETURNS SETOF admin.orders_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
    current_order admin.orders_view%ROWTYPE := workers.current_order();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    UPDATE private.orders AS orders
    SET
        status = 'in_progress'
    WHERE orders.id = current_order.id AND orders.driver_id = user_id;

    RETURN QUERY SELECT * FROM admin.orders_view WHERE id = current_order.id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workers.submit_finish()
RETURNS SETOF admin.orders_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
    current_order admin.orders_view%ROWTYPE := workers.current_order();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    UPDATE private.orders AS orders
    SET
        status = 'waiting_for_marks'
    WHERE orders.id = current_order.id AND orders.driver_id = user_id;

    RETURN QUERY SELECT * FROM admin.orders_view WHERE id = current_order.id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workers.stats()
RETURNS SETOF admin.drivers_stat_view
SECURITY DEFINER
SET search_path = private, admin, workers, public
AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN QUERY
        SELECT *
        FROM admin.drivers_stat_view
        WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workers.withdraw_cash(
    p_amount NUMERIC
)
    RETURNS VOID SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    INSERT INTO private.transactions AS transactions
        (user_id, balance_type, transaction_type, payment_method, amount)
    VALUES
        (user_id, 'earning', 'credit', 'credit_card', p_amount);
END;
$$ LANGUAGE plpgsql;