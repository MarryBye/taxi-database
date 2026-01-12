CREATE OR REPLACE FUNCTION private.update_user_balance()
    RETURNS trigger
    LANGUAGE plpgsql
AS $$
DECLARE
    current_balance NUMERIC;
    adjust_amount NUMERIC;
BEGIN

    IF (NEW.payment_method = 'cash') THEN
        RETURN NEW;
    END IF;

    CASE NEW.transaction_type
        WHEN 'debit'   THEN adjust_amount := NEW.amount;
        WHEN 'credit'  THEN adjust_amount := -NEW.amount;
        WHEN 'refund'  THEN adjust_amount := NEW.amount;
        WHEN 'penalty' THEN adjust_amount := NEW.amount;
        ELSE
            RAISE EXCEPTION 'Неправильний тип транзакції!';
    END CASE;

    SELECT
        CASE
            WHEN NEW.balance_type = 'payment' THEN balances.payment
            WHEN NEW.balance_type = 'earning' THEN balances.earning
        END
    INTO current_balance
    FROM private.balances
    WHERE user_id = NEW.user_id;

    IF current_balance IS NULL THEN
        RAISE EXCEPTION 'У користувача % немає балансу!', NEW.user_id;
    END IF;

    IF NEW.balance_type = 'payment'
        AND current_balance < 0
        AND NEW.transaction_type = 'debit'
    THEN
        RAISE EXCEPTION
            'Баланс у мінусі. Необхідно поповнити рахунок.';
    END IF;

    IF NEW.balance_type = 'earning' AND NEW.transaction_type = 'credit'
    THEN
        IF NEW.amount < 100 THEN
            RAISE EXCEPTION 'Мінімальна сума виводу — 100 грн';
        END IF;

        IF current_balance + adjust_amount < 0 THEN
            RAISE EXCEPTION 'У вас не вистачає грошей для виводу!';
        END IF;
    END IF;

    IF NEW.balance_type = 'payment' THEN
        UPDATE private.balances
        SET payment = payment + adjust_amount
        WHERE user_id = NEW.user_id;
    ELSE
        UPDATE private.balances
        SET earning = earning + adjust_amount
        WHERE user_id = NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_user_balance
    BEFORE INSERT ON private.transactions
    FOR EACH ROW
EXECUTE FUNCTION private.update_user_balance();

CREATE OR REPLACE FUNCTION create_user_balance() RETURNS trigger AS $$
BEGIN
    INSERT INTO private.balances (user_id, payment, earning) VALUES (NEW.id, 0, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER create_balance_for_new_user
AFTER INSERT ON private.users
FOR EACH ROW EXECUTE PROCEDURE create_user_balance()