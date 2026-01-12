CREATE OR REPLACE FUNCTION authorized.get_profile()
RETURNS SETOF admin.users_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    RETURN QUERY
        SELECT * FROM admin.users_view AS users WHERE users.id = user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authorized.update_profile(
    p_first_name VARCHAR(32) DEFAULT NULL,
    p_last_name VARCHAR(32) DEFAULT NULL,
    p_email VARCHAR(64) DEFAULT NULL,
    p_tel_number VARCHAR(16) DEFAULT NULL,
    p_city_id BIGINT DEFAULT NULL,
    p_password VARCHAR(64) DEFAULT NULL
) RETURNS SETOF admin.users_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    UPDATE private.users AS users
        SET
        first_name   = COALESCE(p_first_name, users.first_name),
        last_name    = COALESCE(p_last_name,  users.last_name),
        email        = COALESCE(p_email,      users.email),
        tel_number   = COALESCE(p_tel_number, users.tel_number),
        city_id      = COALESCE(p_city_id,    users.city_id),
        password_hash = COALESCE(p_password,    users.password_hash)
    WHERE users.id = user_id;

    IF (p_password IS NOT NULL) THEN
        CALL admin.change_psql_user_password(SESSION_USER::VARCHAR(32), p_password);
    END IF;

    RETURN QUERY
        SELECT * FROM admin.users_view AS users WHERE users.id = user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authorized.make_order(
    p_order_class public.car_classes,
    p_payment_method public.payment_methods,
    p_addresses address[]
) RETURNS SETOF admin.orders_view SECURITY DEFINER AS $$
DECLARE
    has_current_order BOOLEAN := (SELECT EXISTS(
        SELECT 1 FROM authorized.current_order()
    ));
    user_id BIGINT := public.get_current_user_from_session();
    transaction_id BIGINT;
    order_id BIGINT;
    route_id BIGINT;
    i INT := 1;
    ad address;
    real_address BOOLEAN;
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    IF (ARRAY_LENGTH(p_addresses, 1) < 2) OR (ARRAY_LENGTH(p_addresses, 1) > 10) THEN
        RAISE EXCEPTION 'Invalid number of addresses';
    END IF;

    IF (p_addresses IS NULL) THEN
        RAISE EXCEPTION 'Invalid addresses';
    END IF;

    IF has_current_order THEN
        RAISE EXCEPTION 'You already have an active order';
    END IF;

    FOREACH ad IN ARRAY p_addresses LOOP
        real_address := (SELECT EXISTS(
            SELECT 1 FROM private.cities AS cities
            JOIN private.countries AS countries ON cities.country_id = countries.id
            WHERE cities.name = ad.city AND countries.full_name = ad.country
        ));
        IF NOT real_address THEN
            RAISE EXCEPTION 'Invalid address';
        END IF;
    END LOOP;

    INSERT INTO private.transactions(user_id, balance_type, transaction_type, payment_method)
    VALUES (user_id, 'payment', 'credit', p_payment_method)
    RETURNING id INTO transaction_id;

    INSERT INTO private.orders(client_id, transaction_id, status, order_class)
    VALUES (user_id, transaction_id, 'searching_for_driver', p_order_class)
    RETURNING id INTO order_id;

    INSERT INTO private.routes(order_id, start_location, end_location, distance)
    VALUES (order_id, p_addresses[1], p_addresses[array_length(p_addresses, 1)], random() * (50 - 3) + 3)
    RETURNING id INTO route_id;

    FOREACH ad IN ARRAY p_addresses LOOP
        INSERT INTO private.route_points(route_id, position_index, location)
        VALUES (route_id, i, ad);
        i := i + 1;
    END LOOP;

    RETURN QUERY
        SELECT * FROM admin.orders_view WHERE id = order_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authorized.orders_history()
RETURNS SETOF admin.orders_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN QUERY
        SELECT * FROM admin.orders_view AS orders WHERE (orders.client->>'id')::BIGINT = user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authorized.current_order()
RETURNS SETOF admin.orders_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN QUERY
        SELECT * FROM admin.orders_view AS orders
        WHERE (orders.client->>'id')::BIGINT = user_id AND NOT orders.status IN ('completed', 'canceled');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authorized.get_client_order(
    p_order_id BIGINT
)
    RETURNS admin.orders_view
    SECURITY DEFINER
    SET search_path = private, admin, authorized, public
AS $$
DECLARE
    v_user_id BIGINT := public.get_current_user_from_session();
    v_order admin.orders_view;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    SELECT o.*
    INTO v_order
    FROM admin.orders_view o
    WHERE
        o.id = p_order_id
      AND (o.client->>'id')::BIGINT = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Access denied or order not found';
    END IF;

    RETURN v_order;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION authorized.order_stat(
    p_order_id BIGINT
)
RETURNS SETOF admin.orders_stat_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    IF NOT (SELECT EXISTS(
        SELECT 1 FROM private.orders AS orders WHERE orders.id = p_order_id AND orders.client_id = user_id
    )) THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    RETURN QUERY
        SELECT * FROM admin.orders_stat_view AS orders WHERE orders.id = p_order_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authorized.cancel_order(
    p_order_id BIGINT,
    p_comment VARCHAR(256),
    p_tags VARCHAR(32)[]
) RETURNS SETOF admin.orders_stat_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
    tag VARCHAR(32);
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    IF NOT (SELECT EXISTS(
        SELECT 1 FROM private.orders AS orders WHERE orders.id = p_order_id AND orders.client_id = user_id
    )) THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF (array_length(p_tags, 1) < 1) OR (array_length(p_tags, 1) > 3) THEN
        RAISE EXCEPTION 'Invalid number of tags';
    END IF;

    UPDATE private.orders
    SET status = 'canceled'
    WHERE id = p_order_id
      AND client_id = user_id;

    INSERT INTO private.order_cancels(order_id, canceled_by, comment)
    VALUES (p_order_id, user_id, p_comment);

    FOREACH tag IN ARRAY p_tags LOOP
        INSERT INTO private.order_driver_tags(order_id, tag) VALUES (p_order_id, tag);
    END LOOP;

    RETURN QUERY
        SELECT * FROM admin.orders_stat_view AS orders WHERE orders.id = p_order_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authorized.rate_order(
    p_order_id BIGINT,
    p_mark INT,
    p_comment VARCHAR(256),
    p_tags VARCHAR(32)[]
) RETURNS SETOF admin.orders_stat_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
    tag VARCHAR(32);
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    IF NOT (SELECT EXISTS(
        SELECT 1 FROM private.orders AS orders WHERE orders.id = p_order_id AND orders.client_id = user_id
    )) THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF (array_length(p_tags, 1) < 1) OR (array_length(p_tags, 1) > 3) THEN
        RAISE EXCEPTION 'Invalid number of tags';
    END IF;

    INSERT INTO private.order_ratings(order_id, mark_by, mark, comment)
    VALUES (p_order_id, user_id, p_mark, p_comment);

    FOREACH tag IN ARRAY p_tags LOOP
        INSERT INTO private.order_driver_tags(order_id, tag) VALUES (p_order_id, tag);
    END LOOP;

    RETURN QUERY
        SELECT * FROM admin.orders_stat_view AS orders WHERE orders.id = p_order_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authorized.stats()
RETURNS SETOF admin.clients_stat_view SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT := public.get_current_user_from_session();
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN QUERY
        SELECT * FROM admin.clients_stat_view AS clients WHERE clients.id = user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authorized.add_funds(
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
        (user_id, 'payment', 'debit', 'credit_card', p_amount);
END;
$$ LANGUAGE plpgsql;