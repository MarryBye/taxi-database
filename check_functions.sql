CREATE OR REPLACE FUNCTION public.check_car_number(car_number TEXT) RETURNS BOOLEAN AS $$
BEGIN
  RETURN (car_number ~* '^[A-Z]{2}[0-9]{3}[A-Z]{2}$');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.check_email(email TEXT) RETURNS BOOLEAN AS $$
BEGIN
  RETURN (email ~* '^[\w\.-]+@[\w\.-]+\.\w+$');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.check_tel(tel_number TEXT) RETURNS BOOLEAN AS $$
BEGIN
  RETURN (tel_number ~* '^\+[0-9]{10,13}$');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.check_password(password TEXT) RETURNS BOOLEAN AS $$
BEGIN
  RETURN (length(password) >= 8) AND (password ~* '^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$');
END;
$$ LANGUAGE plpgsql;