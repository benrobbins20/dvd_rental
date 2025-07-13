-- procedure to get the store with the most adult film rentals
CREATE OR REPLACE FUNCTION most_adult_film_rentals()
RETURNS INT as $$
declare top_store INT;
BEGIN
    SELECT i.store_id INTO top_store -- setting the local variable top_store to be the return value (store with most adult films)
    FROM public.inventory i
    JOIN public.film f ON f.film_id = i.film_id -- just this (rating, store_id which is also in inventory), dont need rental table
    WHERE f.rating IN ('NC-17', 'R')
    GROUP BY i.store_id -- needed to aggragate the count of adult films into the right store
    ORDER BY COUNT(*) DESC -- want the top result so descending order
    LIMIT 1; -- grab the top store
    RETURN top_store; -- return the store_id
END;
$$ LANGUAGE plpgsql; -- procedural language postgres, like shebang, interpreter declaration
-- print the result
-- SELECT most_adult_film_rentals();

DROP FUNCTION IF EXISTS get_top_adult_films();
-- create a table with the top 100 adult films with the longest rental period from store 2 (return val of most_adult..())
CREATE OR REPLACE FUNCTION get_top_adult_films()
RETURNS TABLE(film_id INT, rating mpaa_rating, rental_duration DOUBLE PRECISION) AS $$
BEGIN
    RETURN QUERY
    SELECT
        f.film_id,
        f.rating,
        EXTRACT(EPOCH FROM (r.return_date - r.rental_date)) / 3600 AS rental_duration  -- hours
    FROM public.rental r
    JOIN public.inventory i ON r.inventory_id = i.inventory_id
    JOIN public.film f ON i.film_id = f.film_id
    WHERE f.rating IN ('NC-17', 'R') AND i.store_id = most_adult_film_rentals() AND r.return_date IS NOT NULL
    ORDER BY rental_duration DESC
    LIMIT 100; -- limit to top 20 adult films
END;
$$ LANGUAGE plpgsql;

-- SELECT get_top_adult_films();

-- the query to get master data for the adult films 
SELECT f.film_id, f.rating, COUNT(*) as adult_film_inventory
FROM public.film f
JOIN public.inventory i on f.film_id = i.film_id -- has the one film_id mapped to many inventory_id
JOIN public.rental r on i.inventory_id = r.inventory_id -- rental table has the store_id
WHERE f.rating IN ('NC-17', 'R') AND store_id = 2 -- access the top_store variable stored from helper task
GROUP BY f.film_id, f.rating
ORDER BY f.film_id;

-- detailed table for adult movies
DROP TABLE IF EXISTS detailed_adult_films;
CREATE TABLE detailed_adult_films(
    film_id INT PRIMARY KEY,
    film_rating VARCHAR(5),
    film_title VARCHAR(255),
    film_description TEXT,
    inventory_count INT,
    store_id INT,
    rental_duration DOUBLE PRECISION
);

-- summary table including inventory id and top 100 film count
DROP TABLE IF EXISTS summary_adult_films;
CREATE TABLE summary_adult_films(
    film_id INT PRIMARY KEY,
    film_title VARCHAR(255),
    film_rating VARCHAR(10),
    increased_inventory VARCHAR(255)
);

-- updater that runs when the inserts into detailed table trigger summary table updates
CREATE OR REPLACE FUNCTION update_summary_table()
RETURNS TRIGGER AS $$
BEGIN
	INSERT INTO summary_adult_films(film_id, film_rating, film_title, increased_inventory)
	VALUES (
		NEW.film_id,
		NEW.film_rating,
		NEW.film_title,
		increase_adult_film_inventory(NEW.inventory_count, 30)
	);
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -- trigger on insert to detailed_adult_films that executes the summary population function
CREATE TRIGGER summary_table_updater
AFTER INSERT ON detailed_adult_films
FOR EACH ROW
EXECUTE FUNCTION update_summary_table();

-- transformation function to increase the inventory count, converts count INT to VARCHAR qty:<int>
CREATE OR REPLACE FUNCTION increase_adult_film_inventory(current_count INT, percent INT)
returns VARCHAR AS $$ -- dollar signs are delimiters to run raw sql
declare 
    increased_inventory INT;
BEGIN
    increased_inventory := CEILING(current_count * (1 + percent / 100.0)); -- increase the count by the percent, round up
    return 'qty: ' || increased_inventory;
END;
$$ LANGUAGE plpgsql;

-- create a common table expression to test transformation function
-- -- WITH adult_film_count AS (
-- --     SELECT *
-- --     FROM (VALUES
-- --         (11,25),
-- --         (100, 100),
-- --         (1,2)) AS t(current_count, percent) 
-- -- )
-- -- SELECT
-- --     current_count,
-- --     percent,
-- --     -- call the transformation function to increase inventory count
-- --     increase_adult_film_inventory(current_count, percent) as test_increase
-- -- FROM adult_film_count;



-- ------------------------------------------------------------------------------------------------------------------
-- insert data and trigger summary table updater and call the transformation function
CREATE OR REPLACE FUNCTION populate_detailed_adult_table()
RETURNS VOID AS $$
BEGIN
    INSERT INTO detailed_adult_films(film_id, film_rating, film_title, film_description, inventory_count, store_id, rental_duration)
    SELECT 
        f.film_id, 
        f.rating::VARCHAR, -- cast mpaa enum to varchar
        f.title, 
        f.description, 
        COUNT(*) AS inventory_count, 
        i.store_id, 
        MAX(EXTRACT(EPOCH FROM (r.return_date - r.rental_date)) / 3600) AS rental_duration
    FROM public.film f
    JOIN public.inventory i ON f.film_id = i.film_id
    JOIN public.rental r ON i.inventory_id = r.inventory_id
    WHERE f.rating IN ('NC-17', 'R') 
        AND i.store_id = most_adult_film_rentals() 
        AND r.return_date IS NOT NULL
    GROUP BY f.film_id, f.rating, f.title, f.description, i.store_id
    ORDER BY rental_duration DESC
    LIMIT 200;
END;
$$ LANGUAGE plpgsql;

-- call function for initial insert

-- SELECT * FROM detailed_adult_films;
SELECT * FROM summary_adult_films;
	
-- wipe both created tables and repopulate detailed table, which will trigger summary table updates
CREATE OR REPLACE FUNCTION wipe_and_repopulate_tables() AS $$
BEGIN
    TRUNCATE TABLE detailed_adult_films, summary_adult_films;
    PERFORM populate_detailed_adult_table();
END;
$$ LANGUAGE plpgsql;

SELECT wipe_and_repopulate_tables();