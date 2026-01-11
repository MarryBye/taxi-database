CREATE OR REPLACE FUNCTION public.register(
    p_login VARCHAR(32),
    p_password VARCHAR(32),
    p_first_name VARCHAR(32),
    p_last_name VARCHAR(32),
    p_email VARCHAR(32),
    p_tel_number VARCHAR(32),
    p_city_id BIGINT
) RETURNS SETOF admin.users_view SECURITY DEFINER AS $$
DECLARE
    created_user_id BIGINT;
    hashed_password VARCHAR(512);
BEGIN

    IF (NOT public.check_password(p_password)) THEN
        RAISE EXCEPTION 'Password must contain at least 8 characters!';
    END IF;

    hashed_password := crypto.crypt(p_password, crypto.gen_salt('bf', 12));

    INSERT INTO private.users (
         login,
         password_hash,
         first_name,
         last_name,
         email,
         tel_number,
         city_id
    )
    VALUES (
        p_login,
        hashed_password,
        p_first_name,
        p_last_name,
        p_email,
        p_tel_number,
        p_city_id
    ) RETURNING id INTO created_user_id;

    CALL admin.create_psql_user(p_login, p_password);
    CALL admin.set_psql_user_role(p_login, 'client');

    RETURN QUERY
        SELECT * FROM admin.users_view AS users WHERE users.id = created_user_id;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.authenticate(
    p_login VARCHAR(32),
    p_password VARCHAR(32)
) RETURNS TABLE(
    id BIGINT,
    role public.user_roles
) SECURITY DEFINER AS $$
DECLARE
    is_password_correct BOOLEAN := FALSE;
BEGIN

    SELECT crypto.crypt(p_password, users.password_hash) = users.password_hash
    FROM private.users AS users
    WHERE users.login = p_login INTO is_password_correct;

    IF (is_password_correct IS NULL OR NOT is_password_correct) THEN
        RAISE EXCEPTION 'Invalid login or password!';
    END IF;

    RETURN QUERY
        SELECT users.id, users.role FROM private.users AS users WHERE users.login = p_login;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_current_user_from_session() RETURNS BIGINT SECURITY DEFINER AS $$
DECLARE
    user_id BIGINT;
BEGIN
    user_id := (SELECT users.id FROM private.users AS users WHERE users.login = SESSION_USER);
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    RETURN user_id;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM register('MarryBye', 'Ukraine555U', 'Viktor', 'Lukianov', 'vlukianov04@gmail.com', '+380660734348', 1);
SELECT * FROM authenticate('MarryBye', 'Ukraine555U');