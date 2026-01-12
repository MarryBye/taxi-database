CREATE OR REPLACE FUNCTION private.hash_user_password()
    RETURNS TRIGGER AS $$
BEGIN
    IF NEW.password_hash LIKE '$2%' THEN
        RETURN NEW;
    END IF;
    IF (NOT public.check_password(NEW.password_hash)) THEN
        RAISE EXCEPTION 'Пароль не відповідає вимогам! В ньому мають бути латинські літери, цифри та довжина від 8 символів!';
    END IF;
    NEW.password_hash := crypto.crypt(NEW.password_hash, crypto.gen_salt('bf', 12));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_hash_user_password
    BEFORE INSERT OR UPDATE OF password_hash ON private.users
    FOR EACH ROW
EXECUTE FUNCTION private.hash_user_password();

----------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.check_car_driver()
    RETURNS TRIGGER AS $$
DECLARE
     r public.user_roles;
BEGIN
    IF NEW.driver_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT users.role INTO r FROM private.users AS users WHERE id = NEW.driver_id;

    IF (r IS NULL) THEN
        RAISE EXCEPTION 'Користувача не існує!';
    END IF;

    IF (r != 'driver') THEN
        RAISE EXCEPTION 'Користувач не є водієм!';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_car_driver
    BEFORE INSERT OR UPDATE OF driver_id ON private.cars
    FOR EACH ROW
EXECUTE FUNCTION private.check_car_driver();

----------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.sync_car_status_by_driver()
    RETURNS TRIGGER AS $$
BEGIN
    IF OLD.car_status = 'on_maintenance' THEN
        RETURN NEW;
    END IF;

    IF OLD.driver_id IS NULL AND NEW.driver_id IS NOT NULL THEN
        NEW.car_status := 'busy';
        RETURN NEW;
    END IF;

    IF OLD.driver_id IS NOT NULL AND NEW.driver_id IS NULL THEN
        NEW.car_status := 'available';
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_car_status_by_driver
    BEFORE UPDATE OF driver_id
    ON private.cars
    FOR EACH ROW
EXECUTE FUNCTION private.sync_car_status_by_driver();

----------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.sync_car_status_by_maintenance()
    RETURNS TRIGGER AS $$
DECLARE
    has_driver BOOLEAN;
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE private.cars
        SET car_status = 'on_maintenance'
        WHERE id = NEW.car_id;

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.status = 'completed' THEN
        SELECT (driver_id IS NOT NULL)
        INTO has_driver
        FROM private.cars
        WHERE id = NEW.car_id;

        UPDATE private.cars
        SET car_status = CASE
             WHEN has_driver THEN 'busy'
             ELSE 'available'
        END
        WHERE id = NEW.car_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_car_status_by_maintenance
    AFTER INSERT OR UPDATE OF status
    ON private.maintenances
    FOR EACH ROW
EXECUTE FUNCTION private.sync_car_status_by_maintenance();

----------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.set_finished_at_when_completed()
    RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'waiting_for_marks' OR NEW.status = 'canceled' THEN
        NEW.finished_at := NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_finished_at_when_completed
    BEFORE UPDATE OF status
    ON private.orders
    FOR EACH ROW
EXECUTE FUNCTION private.set_finished_at_when_completed();

----------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.complete_order_when_both_rated()
    RETURNS TRIGGER AS $$
DECLARE
    has_both_marks BOOLEAN;
BEGIN

    SELECT (COUNT(rating.id) = 2)
    INTO has_both_marks
    FROM private.order_ratings AS rating
    WHERE rating.order_id = NEW.order_id;

    IF (has_both_marks) THEN
        UPDATE private.orders SET status = 'completed' WHERE id = NEW.order_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_complete_order_when_both_rated
    AFTER INSERT ON private.order_ratings
    FOR EACH ROW
EXECUTE FUNCTION private.complete_order_when_both_rated();

----------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.prevent_cancel_invalid_order()
    RETURNS TRIGGER AS $$
DECLARE
    current_status public.order_statuses;
BEGIN
    SELECT status
    INTO current_status
    FROM private.orders
    WHERE id = NEW.order_id;

    IF current_status IS NULL THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF current_status IN ('completed', 'canceled', 'waiting_for_marks') THEN
        RAISE EXCEPTION
            'Це замовлення не можна скасувати!';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_cancel_invalid_order
    BEFORE INSERT ON private.order_cancels
    FOR EACH ROW
EXECUTE FUNCTION private.prevent_cancel_invalid_order();

----------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.check_order_status_transition()
    RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    IF OLD.status IN ('canceled', 'completed') THEN
        RAISE EXCEPTION
            'Неможливо змінити статус закінченого замовлення!';
    END IF;

    IF OLD.status = 'searching_for_driver'
        AND NEW.status IN ('waiting_for_driver', 'canceled') THEN
        RETURN NEW;
    END IF;

    IF OLD.status = 'waiting_for_driver'
        AND NEW.status IN ('waiting_for_client', 'canceled') THEN
        RETURN NEW;
    END IF;

    IF OLD.status = 'waiting_for_client'
        AND NEW.status IN ('in_progress', 'canceled') THEN
        RETURN NEW;
    END IF;

    IF OLD.status = 'in_progress'
        AND NEW.status IN ('waiting_for_marks', 'canceled') THEN
        RETURN NEW;
    END IF;

    IF OLD.status = 'waiting_for_marks'
        AND NEW.status = 'completed' THEN
        RETURN NEW;
    END IF;

    RAISE EXCEPTION
        'Неможливо змінити статус замовлення: % → %', OLD.status, NEW.status;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_order_status_transition
    BEFORE UPDATE OF status
    ON private.orders
    FOR EACH ROW
EXECUTE FUNCTION private.check_order_status_transition();

----------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.pay_driver_on_trip_finish()
    RETURNS TRIGGER AS $$
DECLARE
    v_amount NUMERIC;
    v_payment_method public.payment_methods;
BEGIN
    IF (NEW.status != 'waiting_for_marks') THEN
        RETURN NEW;
    END IF;

    IF NEW.driver_id IS NULL THEN
        RAISE EXCEPTION 'Замовлення не має водія!';
    END IF;

    SELECT amount, payment_method
    INTO v_amount, v_payment_method
    FROM private.transactions
    WHERE id = NEW.transaction_id;

    IF v_amount IS NULL THEN
        RAISE EXCEPTION 'Не знайдена транзакція цього замовлення!';
    END IF;

    INSERT INTO private.transactions (
        user_id,
        balance_type,
        transaction_type,
        payment_method,
        amount
    ) VALUES (
         NEW.driver_id,
         'earning',
         'debit',
         v_payment_method,
         v_amount
     );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pay_driver_on_trip_finish
    AFTER UPDATE OF status
    ON private.orders
    FOR EACH ROW
EXECUTE FUNCTION private.pay_driver_on_trip_finish();