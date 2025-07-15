**A1**: Identify fields included in detailed table and summary table
#### Detailed table
- film_id INT PRIMARY KEY -- unique id for each film
- film_rating VARCHAR(5) -- mpaa_rating casted to VARCHAR
- film_title VARCHAR(255) -- title of film
- film_description TEXT -- No limit to text, best for long string descriptions
- rental_price NUMERIC -- dollar amount 4.99
- inventory_count INT -- COUNT(*) of all the same film_id's tied to multiple rental records
- store_id INT -- store_id
- rental_duration DOUBLE PRECISION -- return-rental (epoch seconds) / 3600 = hours. 

#### Summary table
