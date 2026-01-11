CREATE OR REPLACE FUNCTION update_user_balance()
    RETURNS trigger
    LANGUAGE plpgsql
AS $$
DECLARE
    current_balance NUMERIC;
    adjust_amount NUMERIC;
BEGIN
    current_balance := (
        SELECT
            CASE
                WHEN NEW.balance_type = 'payment' THEN balances.payment
                WHEN NEW.balance_type = 'earning' THEN balances.earning
                END
        FROM private.balances AS balances
        WHERE balances.user_id = NEW.user_id
    );

    IF NEW.transaction_type = 'debit' THEN
        adjust_amount := NEW.amount;
    ELSIF NEW.transaction_type = 'credit' THEN
        adjust_amount := -NEW.amount;
    ELSIF NEW.transaction_type = 'refund' THEN
        adjust_amount := NEW.amount;
    ELSIF NEW.transaction_type = 'penalty' THEN
        adjust_amount := -NEW.amount;
    END IF;

    IF (current_balance + adjust_amount) < 0
        AND NEW.transaction_type <> 'penalty' THEN
        RAISE NOTICE 'Insufficient funds! You need to add money to your account.';
        RETURN NULL;
    END IF;

    IF NEW.balance_type = 'payment' THEN
        UPDATE private.balances
        SET payment = payment + adjust_amount
        WHERE user_id = NEW.user_id;
    ELSIF NEW.balance_type = 'earning' THEN
        UPDATE private.balances
        SET earning = earning + adjust_amount
        WHERE user_id = NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER update_user_balance_trigger
BEFORE INSERT OR UPDATE ON private.transactions
FOR EACH ROW EXECUTE PROCEDURE update_user_balance();

CREATE OR REPLACE FUNCTION create_user_balance() RETURNS trigger AS $$
BEGIN
    INSERT INTO private.balances (user_id, payment, earning) VALUES (NEW.id, 0, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER create_balance_for_new_user
AFTER INSERT ON private.users
FOR EACH ROW EXECUTE PROCEDURE create_user_balance()