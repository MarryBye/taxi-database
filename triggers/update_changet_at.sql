CREATE OR REPLACE FUNCTION private.update_changed_at()
    RETURNS trigger AS $$
BEGIN
    IF NEW IS DISTINCT FROM OLD THEN
        NEW.changed_at := now();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_changed_at_balances
    BEFORE UPDATE ON private.balances
    FOR EACH ROW EXECUTE FUNCTION private.update_changed_at();

CREATE TRIGGER trg_update_changed_at_cars
    BEFORE UPDATE ON private.cars
    FOR EACH ROW EXECUTE FUNCTION private.update_changed_at();

CREATE TRIGGER trg_update_changed_at_maintenances
    BEFORE UPDATE ON private.maintenances
    FOR EACH ROW EXECUTE FUNCTION private.update_changed_at();

CREATE TRIGGER trg_update_changed_at_order_cancels
    BEFORE UPDATE ON private.order_cancels
    FOR EACH ROW EXECUTE FUNCTION private.update_changed_at();

CREATE TRIGGER trg_update_changed_at_order_ratings
    BEFORE UPDATE ON private.order_ratings
    FOR EACH ROW EXECUTE FUNCTION private.update_changed_at();

CREATE TRIGGER trg_update_changed_at_orders
    BEFORE UPDATE ON private.orders
    FOR EACH ROW EXECUTE FUNCTION private.update_changed_at();

CREATE TRIGGER trg_update_changed_at_users
    BEFORE UPDATE ON private.users
    FOR EACH ROW EXECUTE FUNCTION private.update_changed_at();