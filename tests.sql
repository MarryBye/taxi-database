CREATE OR REPLACE PROCEDURE private.register_test_users()
    SECURITY DEFINER
AS $$
DECLARE
usr RECORD;
BEGIN
FOR usr IN
SELECT *
FROM (
         VALUES
             -- 👑 admin (один)
             ('admin_root', 'Qwerty12345', 'Admin', 'Root', 'admin@taxi.com', '+380000000001', 1, 'admin'),

             -- 👤 clients — Одесса
             ('client_od_1', 'Qwerty12345', 'Olena', 'Shevchenko', 'olena.od@gmail.com', '+380100000001', 1, 'client'),
             ('client_od_2', 'Qwerty12345', 'Mykola','Ivanenko',  'mykola.od@gmail.com','+380100000002', 1, 'client'),

             -- 👤 clients — Киев
             ('client_ky_1', 'Qwerty12345', 'Ivan',  'Petrenko',  'ivan.ky@gmail.com',  '+380200000001', 2, 'client'),
             ('client_ky_2', 'Qwerty12345', 'Anna',  'Koval',     'anna.ky@gmail.com',  '+380200000002', 2, 'client'),

             -- 👤 clients — Варшава
             ('client_wa_1', 'Qwerty12345', 'Piotr', 'Nowak',     'piotr.wa@gmail.com', '+48110000001',  3, 'client'),
             ('client_wa_2', 'Qwerty12345', 'Anna',  'Kowalska',  'anna.wa@gmail.com',  '+48110000002',  3, 'client'),

             -- 👤 clients — Люблин
             ('client_lu_1', 'Qwerty12345', 'Pawel', 'Mazur',     'pawel.lu@gmail.com', '+48120000001',  4, 'client'),
             ('client_lu_2', 'Qwerty12345', 'Maria', 'Zielinska', 'maria.lu@gmail.com', '+48120000002',  4, 'client'),

             -- 🚕 drivers — Одесса
             ('driver_od_1', 'Qwerty12345', 'Andrii','Bondar',    'andrii.od@taxi.com', '+380300000001', 1, 'driver'),
             ('driver_od_2', 'Qwerty12345', 'Oleh',  'Melnyk',    'oleh.od@taxi.com',   '+380300000002', 1, 'driver'),

             -- 🚕 drivers — Киев
             ('driver_ky_1', 'Qwerty12345', 'Taras', 'Ivanov',    'taras.ky@taxi.com',  '+380400000001', 2, 'driver'),
             ('driver_ky_2', 'Qwerty12345', 'Denys', 'Kravchenko','denys.ky@taxi.com',  '+380400000002', 2, 'driver'),

             -- 🚕 drivers — Варшава
             ('driver_wa_1', 'Qwerty12345', 'Marek', 'Kaczmarek', 'marek.wa@taxi.com',  '+48130000001',  3, 'driver'),
             ('driver_wa_2', 'Qwerty12345', 'Tomasz','Lewandowski','tomasz.wa@taxi.com', '+48130000002',  3, 'driver'),

             -- 🚕 drivers — Люблин
             ('driver_lu_1', 'Qwerty12345', 'Kamil', 'Dabrowski', 'kamil.lu@taxi.com',  '+48140000001',  4, 'driver'),
             ('driver_lu_2', 'Qwerty12345', 'Adam',  'Piotrowski','adam.lu@taxi.com',   '+48140000002',  4, 'driver')
     ) AS t(
            login,
            password,
            first_name,
            last_name,
            email,
            tel_number,
            city_id,
            role
    )
    LOOP
            PERFORM admin.create_user(
                    p_login      := usr.login::VARCHAR(32),
                    p_password   := usr.password::VARCHAR(32),
                    p_first_name := usr.first_name::VARCHAR(32),
                    p_last_name  := usr.last_name::VARCHAR(32),
                    p_email      := usr.email::VARCHAR(64),
                    p_tel_number := usr.tel_number::VARCHAR(32),
                    p_city_id    := usr.city_id::BIGINT,
                    p_role       := usr.role::public.user_roles
                    );
END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL private.register_test_users();

CREATE OR REPLACE PROCEDURE private.register_test_cars()
    SECURITY DEFINER
AS $$
DECLARE
    car RECORD;
    v_driver_id BIGINT;
BEGIN
    FOR car IN
        SELECT *
        FROM (
            VALUES
                ('driver_od_1', 'Toyota', 'Camry', 'BH001AA', 1, 'white', 'comfort'),
                ('driver_od_2', 'Hyundai', 'Elantra', 'BH002AA', 1, 'black', 'standard'),
                ('driver_ky_1', 'Skoda', 'Octavia', 'KA001AA', 2, 'silver', 'comfort'),
                ('driver_ky_2', 'Volkswagen', 'Passat', 'KA002AA', 2, 'blue', 'business'),
                ('driver_wa_1', 'Toyota', 'Corolla', 'WA001PL', 3, 'white', 'standard'),
                ('driver_wa_2', 'BMW', '320i', 'WA000PL', 3, 'black', 'business'),
                ('driver_lu_1', 'Renault', 'Megane', 'LU001PL', 4, 'red', 'standard'),
                ('driver_lu_2', 'Audi', 'A4', 'LU002PL', 4, 'gray', 'comfort')
        ) AS t(
            driver_login,
            mark,
            model,
            number_plate,
            city_id,
            color,
            car_class
        )
        LOOP
            SELECT u.id
            INTO v_driver_id
            FROM private.users u
            WHERE u.login = car.driver_login
              AND u.role = 'driver';

            IF v_driver_id IS NULL THEN
                RAISE NOTICE 'Driver % not found, skipping car %', car.driver_login, car.number_plate;
                CONTINUE;
            END IF;

            INSERT INTO private.cars (
                driver_id,
                mark,
                model,
                number_plate,
                city_id,
                color,
                car_class
            ) VALUES (
                v_driver_id,
                car.mark::VARCHAR(32),
                car.model::VARCHAR(32),
                car.number_plate::VARCHAR(32),
                car.city_id::BIGINT,
                car.color::public.colors,
                car.car_class::public.car_classes
            );
        END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL private.register_test_cars();