CREATE OR REPLACE FUNCTION update_changed_at() RETURNS trigger AS $$
BEGIN
    NEW.changed_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER update_changed_at_trigger
BEFORE UPDATE ON private.balances
FOR EACH ROW EXECUTE PROCEDURE update_changed_at();

CREATE OR REPLACE TRIGGER update_changed_at_trigger
BEFORE UPDATE ON private.cars
FOR EACH ROW EXECUTE PROCEDURE update_changed_at();

CREATE OR REPLACE TRIGGER update_changed_at_trigger
BEFORE UPDATE ON private.maintenances
FOR EACH ROW EXECUTE PROCEDURE update_changed_at();

CREATE OR REPLACE TRIGGER update_changed_at_trigger
BEFORE UPDATE ON private.order_cancels
FOR EACH ROW EXECUTE PROCEDURE update_changed_at();

CREATE OR REPLACE TRIGGER update_changed_at_trigger
BEFORE UPDATE ON private.order_ratings
FOR EACH ROW EXECUTE PROCEDURE update_changed_at();

CREATE OR REPLACE TRIGGER update_changed_at_trigger
BEFORE UPDATE ON private.orders
FOR EACH ROW EXECUTE PROCEDURE update_changed_at();

CREATE OR REPLACE TRIGGER update_changed_at_trigger
BEFORE UPDATE ON private.users
FOR EACH ROW EXECUTE PROCEDURE update_changed_at();