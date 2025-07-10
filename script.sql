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

-- create a table with the top 20 adult films with the longest rental period from store 2 (return val of most_adult..())
CREATE OR REPLACE FUNCTION get_top_adult_films()
RETURNS TABLE(film_id INT, rating VARCHAR, rental_duration INT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        f.film_id,
        f.rating,
        EXTRACT(EPOCH FROM (r.return_date - r.rental_date)) AS rental_duration
    FROM public.rental r
    JOIN public.inventory i ON r.inventory_id = i.inventory_id
    JOIN public.film f ON i.film_id = f.film_id
    WHERE f.rating IN ('NC-17', 'R') AND i.store_id = most_adult_film_rentals() AND r.return_date IS NOT NULL
    ORDER BY rental_duration DESC
    LIMIT 20; -- limit to top 20 adult films
    RETURN QUERY SELECT f.film_id, f.rating, rental_duration
END;
$$ LANGUAGE plpgsql;


-- the query to get master data for the adult films 
SELECT f.film_id, f.rating, COUNT(*) as adult_film_inventory
FROM public.film f
JOIN public.inventory i on f.film_id = i.film_id -- has the one film_id mapped to many inventory_id
JOIN public.rental r on i.inventory_id = r.inventory_id -- rental table has the store_id
WHERE f.rating IN ('NC-17', 'R') AND store_id = most_adult_film_rentals() -- access the top_store variable stored from helper task
GROUP BY f.film_id, f.rating
ORDER BY f.film_id;

-- detailed table for 
CREATE TABLE detailed_adult_films(
    film_id INT PRIMARY KEY,
    film_rating::VARCHAR(10),
    film_title VARCHAR(255),
    film_description TEXT,
    inventory_count INT,
    store_id INT,
    rental_duration INT
)

-- summary table including inventory id and top 100 film count
CREATE TABLE summary_adult_films(
    film_id INT PRIMARY KEY,
    film_title VARCHAR(255),
    film_rating::VARCHAR(10),
    inventory_id INT,
);


INSERT INTO detailed_adult_films(film_id, film_rating, film_title, film_description, inventory_count, store_id, rental_duration)
SELECT f.film_id, f.rating, f.title, f.description, COUNT(f.film_id) AS inventory_count, i.store_id, EXTRACT(EPOCH FROM (r.return_date - r.rental_date)) AS rental_duration
FROM public.film f
JOIN public.inventory i ON f.film_id = i.film_id
JOIN public.rental r ON i.inventory_id = r.inventory_id
WHERE f.rating IN ('NC-17', 'R') AND i.store_id = most_adult_film_rentals() AND r.return_date IS NOT NULL;






