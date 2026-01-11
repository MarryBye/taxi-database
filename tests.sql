CALL admin.create_user(
    'test_admin',
    'test_admin@gmail.com',
    '+38-000-000-00-00',
    '1111',
    'admin',
    'admin',
    'Ukraine',
    'Odessa',
    'admin'
);

CALL admin.create_user(
    'test_client',
    'test_client@gmail.com',
    '+38-000-000-00-01',
    '1111',
    'client',
    'client',
    'Ukraine',
    'Odessa',
    'client'
);

CALL admin.create_user(
    'test_driver',
    'test_driver@gmail.com',
    '+38-000-000-00-02',
    '1111',
    'driver',
    'driver',
    'Ukraine',
    'Odessa',
    'driver'
);

CALL public.register(
    'test_registered_client',
    'test_registered_client@gmail.com',
    '+38-000-000-00-03',
    '1111',
    'registered',
    'registered',
    'Ukraine',
    'Odessa'
);

CALL admin.create_user(
    'Viktor',
    'viktor@gmail.com',
    '+38-000-000-00-05',
    '1111',
    'Viktor',
    'Ivanovich',
    'Ukraine',
    'Odessa',
    'driver'
);

SELECT * FROM private.users;
SELECT * FROM admin.users_view;
SELECT * FROM public.auth(
    'test_admin'
);

CALL admin.create_user(
    'Viktor2',
    'viktor2@gmail.com',
    '+38-222-000-00-05',
    '1111',
    'Viktor',
    'Ivanovich',
    'Ukraine',
    'Odessa',
    'driver'
);
SET ROLE "admin";
SELECT * FROM private.users;
RESET ROLE;

CALL admin.set_psql_user_role('MarryBye', 'driver')