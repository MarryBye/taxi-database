CREATE OR REPLACE PROCEDURE admin.create_psql_user(
    p_login VARCHAR(32),
    p_hashed_password VARCHAR(512)
) SECURITY DEFINER AS $$
BEGIN
    EXECUTE FORMAT('CREATE USER %I WITH PASSWORD %L;', p_login, p_hashed_password);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE admin.set_psql_user_role(
    p_login VARCHAR(32),
    p_role public.user_roles
) SECURITY DEFINER AS $$
BEGIN
    IF p_login = 'postgres' THEN
        RAISE EXCEPTION 'You cannot change role for postgres user';
    END IF;
    EXECUTE FORMAT('REVOKE client, driver, admin FROM %I;', p_login);
    EXECUTE FORMAT('GRANT %I TO %I;', p_role, p_login);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE admin.change_psql_user_password(
    p_login VARCHAR(32),
    p_hashed_password VARCHAR(512)
) SECURITY DEFINER AS $$
BEGIN
    IF p_login = 'postgres' THEN
        RAISE EXCEPTION 'You cannot change password for postgres user';
    END IF;
    EXECUTE FORMAT('ALTER USER %I WITH PASSWORD %L;', p_login, p_hashed_password);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE admin.delete_psql_user(
    p_login VARCHAR(32)
) SECURITY DEFINER AS $$
BEGIN
    IF p_login = 'postgres' THEN
        RAISE EXCEPTION 'You cannot delete postgres user';
    END IF;
    EXECUTE FORMAT('DROP USER %I;', p_login);
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin.create_user(
    p_login VARCHAR(32),
    p_password VARCHAR(32),
    p_first_name VARCHAR(32),
    p_last_name VARCHAR(32),
    p_email VARCHAR(64),
    p_tel_number VARCHAR(32),
    p_city_id BIGINT,
    p_role public.user_roles
) RETURNS SETOF admin.users_view SECURITY DEFINER AS $$
DECLARE
    created_user_id BIGINT;
BEGIN
    INSERT INTO private.users (
         login,
         password_hash,
         first_name,
         last_name,
         email,
         tel_number,
         city_id,
         role
    )
    VALUES (
        p_login,
        p_password,
        p_first_name,
        p_last_name,
        p_email,
        p_tel_number,
        p_city_id,
        p_role
    ) RETURNING id INTO created_user_id;

    CALL admin.create_psql_user(p_login, p_password);
    CALL admin.set_psql_user_role(p_login, p_role);

    RETURN QUERY
        SELECT * FROM admin.users_view AS users WHERE users.id = created_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_users()
RETURNS SETOF admin.users_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
        SELECT * FROM admin.users_view;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_user(
    p_user_id BIGINT
) RETURNS SETOF admin.users_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
        SELECT * FROM admin.users_view WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.delete_user(
    p_user_id BIGINT
) RETURNS VOID SECURITY DEFINER AS $$
DECLARE
    user_login VARCHAR(32);
BEGIN
    SELECT users.login INTO user_login FROM private.users AS users WHERE users.id = p_user_id;
    DELETE FROM private.users WHERE id = p_user_id;
    CALL admin.delete_psql_user(user_login);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.update_user(
    p_user_id BIGINT,
    p_first_name VARCHAR(32) DEFAULT NULL,
    p_last_name VARCHAR(32) DEFAULT NULL,
    p_email VARCHAR(64) DEFAULT NULL,
    p_tel_number VARCHAR(16) DEFAULT NULL,
    p_city_id BIGINT DEFAULT NULL,
    p_role public.user_roles DEFAULT NULL
) RETURNS SETOF admin.users_view SECURITY DEFINER AS $$
DECLARE
    user_login VARCHAR(32);
BEGIN

    SELECT users.login INTO user_login FROM private.users AS users WHERE users.id = p_user_id;

    UPDATE private.users AS users
        SET
        first_name   = COALESCE(p_first_name, users.first_name),
        last_name    = COALESCE(p_last_name,  users.last_name),
        email        = COALESCE(p_email,      users.email),
        tel_number   = COALESCE(p_tel_number, users.tel_number),
        city_id      = COALESCE(p_city_id,    users.city_id),
        role         = COALESCE(p_role,         users.role)
    WHERE users.id = p_user_id;

    IF p_role IS NOT NULL THEN
        CALL admin.set_psql_user_role(user_login, p_role);
    END IF;

    RETURN QUERY
        SELECT * FROM admin.users_view AS users WHERE users.id = p_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_client_statistics(
    p_user_id BIGINT
) RETURNS SETOF admin.clients_stat_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM admin.clients_stat_view WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_driver_statistics(
    p_user_id BIGINT
) RETURNS SETOF admin.drivers_stat_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM admin.drivers_stat_view WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin.create_car(
    p_mark VARCHAR(32),
    p_model VARCHAR(32),
    p_number_plate VARCHAR(32),
    p_city_id BIGINT,
    p_color public.colors,
    p_car_class public.car_classes,
    p_car_status public.car_statuses,
    p_driver_id BIGINT DEFAULT NULL
) RETURNS SETOF admin.cars_view SECURITY DEFINER AS $$
DECLARE
    created_car_id BIGINT;
BEGIN
    INSERT INTO private.cars (mark, model, number_plate, city_id, color, car_class, car_status, driver_id)
    VALUES (p_mark, p_model, p_number_plate, p_city_id, p_color, p_car_class, p_car_status, p_driver_id)
    RETURNING id INTO created_car_id;

    RETURN QUERY
        SELECT * FROM admin.cars_view WHERE id = created_car_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_cars()
RETURNS SETOF admin.cars_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
        SELECT * FROM admin.cars_view;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_car(
    p_car_id BIGINT
) RETURNS SETOF admin.cars_view SECURITY DEFINER AS $$
BEGIN
RETURN QUERY
        SELECT * FROM admin.cars_view WHERE id = p_car_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.delete_car(
    p_car_id BIGINT
) RETURNS VOID SECURITY DEFINER AS $$
BEGIN
    DELETE FROM private.cars WHERE id = p_car_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.update_car(
    p_car_id BIGINT,
    p_mark VARCHAR(32) DEFAULT NULL,
    p_model VARCHAR(32) DEFAULT NULL,
    p_number_plate VARCHAR(32) DEFAULT NULL,
    p_city_id BIGINT DEFAULT NULL,
    p_color public.colors DEFAULT NULL,
    p_car_class public.car_classes DEFAULT NULL,
    p_car_status public.car_statuses DEFAULT NULL,
    p_driver_id BIGINT DEFAULT NULL
) RETURNS SETOF admin.cars_view SECURITY DEFINER AS $$
BEGIN
    UPDATE private.cars SET
        mark         = COALESCE(p_mark, mark),
        model        = COALESCE(p_model, model),
        number_plate = COALESCE(p_number_plate, number_plate),
        city_id      = COALESCE(p_city_id, city_id),
        color        = COALESCE(p_color, color),
        car_class    = COALESCE(p_car_class, car_class),
        car_status   = COALESCE(p_car_status, car_status),
        driver_id    = p_driver_id
    WHERE id = p_car_id;

    RETURN QUERY
        SELECT * FROM admin.cars_view WHERE id = p_car_id;
END;
$$ LANGUAGE plpgsql;

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin.get_orders()
RETURNS SETOF admin.orders_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
        SELECT * FROM admin.orders_view;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_order(
    p_order_id BIGINT
) RETURNS SETOF admin.orders_view SECURITY DEFINER AS $$
BEGIN
RETURN QUERY
        SELECT * FROM admin.orders_view WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_order_statistics(
    p_order_id BIGINT
) RETURNS SETOF admin.orders_stat_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM admin.orders_stat_view WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin.create_maintenance(
    p_car_id BIGINT,
    p_description VARCHAR(2048),
    p_cost NUMERIC,
    p_status public.maintenance_statuses,
    p_maintenance_start TIMESTAMP,
    p_maintenance_end TIMESTAMP
) RETURNS SETOF admin.maintenances_view SECURITY DEFINER AS $$
DECLARE
    maintenance_id BIGINT;
BEGIN
    INSERT INTO private.maintenances (car_id, description, cost, status, maintenance_start, maintenance_end)
    VALUES (p_car_id, p_description, p_cost, p_status, p_maintenance_start, p_maintenance_end)
    RETURNING id INTO maintenance_id;
    RETURN QUERY SELECT * FROM admin.maintenances_view WHERE id = maintenance_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_maintenances()
RETURNS SETOF admin.maintenances_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM admin.maintenances_view;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_maintenance(
    p_maintenance_id BIGINT
) RETURNS SETOF admin.maintenances_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM admin.maintenances_view WHERE id = p_maintenance_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.update_maintenance(
    p_maintenance_id BIGINT,
    p_status public.maintenance_statuses
) RETURNS SETOF admin.maintenances_view SECURITY DEFINER AS $$
BEGIN
    UPDATE private.maintenances SET status = p_status WHERE id = p_maintenance_id;
    RETURN QUERY SELECT * FROM admin.maintenances_view WHERE id = p_maintenance_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.delete_maintenance(
    p_maintenance_id BIGINT
) RETURNS VOID SECURITY DEFINER AS $$
BEGIN
    DELETE FROM private.maintenances WHERE id = p_maintenance_id;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin.create_transaction(
    p_user_id BIGINT,
    p_balance_type public.balance_types,
    p_transaction_type public.transaction_type,
    p_payment_method public.payment_methods,
    p_amount NUMERIC
) RETURNS SETOF admin.transactions_view SECURITY DEFINER AS $$
DECLARE
    created_transaction_id BIGINT;
BEGIN
    INSERT INTO private.transactions (user_id, balance_type, transaction_type, payment_method, amount)
    VALUES (p_user_id, p_balance_type, p_transaction_type, p_payment_method, p_amount)
    RETURNING id INTO created_transaction_id;
    RETURN QUERY SELECT * FROM admin.transactions_view WHERE id = created_transaction_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_transactions()
RETURNS SETOF admin.transactions_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM admin.transactions_view;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION admin.get_transaction(
    p_transaction_id BIGINT
) RETURNS SETOF admin.transactions_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM admin.transactions_view WHERE id = p_transaction_id;
END;
$$ LANGUAGE plpgsql;