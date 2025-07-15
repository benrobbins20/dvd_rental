-- internal function to get the store with the most adult film rentals
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


----------------- Section B: Transformation Function -----------------
CREATE OR REPLACE FUNCTION increase_adult_film_inventory(current_count INT, percent INT, rental_price NUMERIC)
-- show both the quantity increase the potential revenue from adding more inventory
RETURNS TABLE (
    increased_inventory INT,
    revenue_potential NUMERIC
) AS $$ -- $$ function body/select queries $$, function delimiters
BEGIN
    increased_inventory := CEILING(current_count * (1 + percent / 100.0)); -- increase the count by the percent, round up
    revenue_potential := (increased_inventory -  current_count) * rental_price; -- calculate added revenue potential
    RETURN NEXT; -- only one row returned, so 
END;
$$ LANGUAGE plpgsql;

-- create a common table expression to test transformation function
WITH adult_film_count AS (
    SELECT *
    FROM (VALUES
        (11,25),
        (100, 100),
        (1,2)) AS t(current_count, percent) 
)
SELECT
    current_count,
    percent,
    -- call the transformation function to increase inventory count
    increase_adult_film_inventory(current_count, percent) as test_increase
FROM adult_film_count;

---------------- SECTION C: Create detailed and summary tables ----------------
-- detailed table for adult movies
DROP TABLE IF EXISTS detailed_adult_films;
CREATE TABLE detailed_adult_films(
    film_id INT PRIMARY KEY,
    film_rating VARCHAR(5),
    film_title VARCHAR(255),
    film_description TEXT,
    rental_price NUMERIC(4,2), -- eq. 0.0.1 - 99.99
    inventory_count INT,
    store_id INT,
    rental_duration DOUBLE PRECISION
);

-- summary table including transformed field increased_inventory and the other custom field that uses this calculation
DROP TABLE IF EXISTS summary_adult_films;
CREATE TABLE summary_adult_films(
    film_id INT PRIMARY KEY,
    film_title VARCHAR(255),
    film_rating VARCHAR(10),
    increased_inventory VARCHAR(255),
    revenue_potential NUMERIC
);

--------------------- SECTION D: Extract raw data for detailed table insert ----------------
-- insert data and trigger summary table updater and call the transformation function
CREATE OR REPLACE FUNCTION populate_detailed_adult_table()
RETURNS VOID AS $$
BEGIN
    INSERT INTO detailed_adult_films(film_id, film_rating, film_title, film_description, rental_price, inventory_count, store_id, rental_duration)
    SELECT 
        f.film_id, 
        f.rating::VARCHAR, -- cast mpaa enum to varchar
        f.title, 
        f.description,
        f.rental_rate,
        COUNT(*) AS inventory_count, -- grouping done by combining all of the film_ids that belong in inventory + chosen store
        i.store_id, 
        MAX(EXTRACT(EPOCH FROM (r.return_date - r.rental_date)) / 3600) AS rental_duration -- calculate the length of the rental in hours
    FROM public.film f
    JOIN public.inventory i ON f.film_id = i.film_id
    JOIN public.rental r ON i.inventory_id = r.inventory_id
    WHERE f.rating IN ('NC-17', 'R') 
        AND i.store_id = most_adult_film_rentals() 
        AND r.return_date IS NOT NULL
    GROUP BY f.film_id, f.rating, f.title, f.description, i.store_id -- must group by all the column that are not aggregrated
    ORDER BY rental_duration DESC -- the longest durations are at the top, and moves down 200 entries
    LIMIT 200;
END;
$$ LANGUAGE plpgsql;

---------------------- SECTION E: Trigger and the update function for the summary table ----------------
-- updater that runs when the inserts into detailed table trigger summary table updates
CREATE OR REPLACE FUNCTION update_summary_table()
RETURNS TRIGGER AS $$
DECLARE inventory_record RECORD; -- transformtion function returns a table, hold result in a record
BEGIN
    -- get the row/record of the transformation function
    SELECT * INTO inventory_record 
    FROM increase_adult_film_inventory(NEW.inventory_count, 30, NEW.rental_price)
    LIMIT 1;

    -- add the processed columns to the summary table
    INSERT INTO summary_adult_films(film_id, film_rating, film_title, increased_inventory, revenue_potential)
    VALUES (
        NEW.film_id,
        NEW.film_rating,
        NEW.film_title,
        inventory_record.increased_inventory,
        inventory_record.revenue_potential
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER summary_table_updater
AFTER INSERT ON detailed_adult_films
FOR EACH ROW
EXECUTE FUNCTION update_summary_table();


	
-- ----------------------- SECTION F: Stored procedure to flush data and repopulate tables ----------------
CREATE OR REPLACE PROCEDURE wipe_and_repopulate_tables() AS $$
BEGIN
    TRUNCATE TABLE detailed_adult_films, summary_adult_films;
    PERFORM populate_detailed_adult_table(); -- fill the detailed table, which triggers the summary table updater
END;
$$ LANGUAGE plpgsql;

CALL wipe_and_repopulate_tables();
SELECT * FROM summary_adult_films;
