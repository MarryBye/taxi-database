CREATE OR REPLACE FUNCTION public.get_countries()
RETURNS SETOF public.countries_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM public.countries_view;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_cities(
    p_country_id BIGINT
) RETURNS SETOF public.cities_view SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM public.cities_view AS cities WHERE (cities.country->>'id')::BIGINT = p_country_id;
END;
$$ LANGUAGE plpgsql;