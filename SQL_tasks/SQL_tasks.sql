--SQLite Expert Personal
CREATE TABLE IF NOT EXISTS Book (
	id_book INTEGER PRIMARY KEY
,	name_book VARCHAR(50)
,	genre VARCHAR(10)
,	pages INTEGER
,	price NUMERIC(9,2)
);

INSERT INTO Book (id_book, name_book, genre, pages, price) VALUES (1, 'name_book_1', 'genre_1', 100, 10.0);
INSERT INTO Book (id_book, name_book, genre, pages, price) VALUES (2, 'name_book_2', 'genre_2', 200, 20.0);
INSERT INTO Book (id_book, name_book, genre, pages, price) VALUES (3, 'name_book_3', 'genre_3', 300, 30.0);
INSERT INTO Book (id_book, name_book, genre, pages, price) VALUES (4, 'name_book_4', 'genre_4', 400, 40.0);
INSERT INTO Book (id_book, name_book, genre, pages, price) VALUES (5, 'name_book_5', 'genre_4', 444, 44.0);
INSERT INTO Book (id_book, name_book, genre, pages, price) VALUES (6, '%%%', 'genre_6', 5, 5.5);



CREATE TABLE IF NOT EXISTS Students (
	id_student INTEGER PRIMARY KEY
,	name_student VARCHAR(50)
);
INSERT INTO Students (id_student, name_student) VALUES (1, 'name_student_1');
INSERT INTO Students (id_student, name_student) VALUES (2, 'name_student_2');
INSERT INTO Students (id_student, name_student) VALUES (3, 'name_student_3');
INSERT INTO Students (id_student, name_student) VALUES (4, 'name_student_4');



CREATE TABLE IF NOT EXISTS Register (
	id_student INTEGER
,	id_book INTEGER
,	date DATE
,	FOREIGN KEY (id_student) REFERENCES Students(id_student)
,	FOREIGN KEY (id_book) REFERENCES Book(id_book)
);

INSERT INTO Register (id_student, id_book, date) VALUES (1, 1, '2020-12-01');
INSERT INTO Register (id_student, id_book, date) VALUES (2, 2, '2020-12-02');
INSERT INTO Register (id_student, id_book, date) VALUES (3, 3, '2020-12-03');
INSERT INTO Register (id_student, id_book, date) VALUES (4, 4, '2020-12-04');
INSERT INTO Register (id_student, id_book, date) VALUES (1, 1, '2021-01-01');
INSERT INTO Register (id_student, id_book, date) VALUES (2, 2, '2021-02-02');
INSERT INTO Register (id_student, id_book, date) VALUES (2, 2, '2021-12-02');
INSERT INTO Register (id_student, id_book, date) VALUES (2, 3, '2021-12-02');
INSERT INTO Register (id_student, id_book, date) VALUES (3, 2, '2021-12-02');



--1. Вивести книгу, що має найбільше сторінок
SELECT * FROM Book ORDER BY pages DESC LIMIT 1 ;


--2. Показати студентів, які брали книгу 'name_book_1' в грудні 2020
SELECT * FROM Register WHERE id_book=(SELECT id_book FROM Book WHERE name_book='name_book_1') AND date BETWEEN '2020-12-01' AND '2020-12-31' ;


--3. Яку кількість студентів брали книгу name_2 у грудні 2021; у скільки разів їх більше, ніж тих, хто брав книгу name_2 у грудні 2020
SELECT
	(SELECT COUNT() FROM Register WHERE id_book=(SELECT id_book FROM Book WHERE name_book='name_book_2')
			AND date BETWEEN '2021-12-01' AND '2021-12-31') AS NO2021
,  (SELECT COUNT() FROM Register WHERE id_book=(SELECT id_book FROM Book WHERE name_book='name_book_2')
			AND date BETWEEN '2020-12-01' AND '2020-12-31') AS NO2020
--,	CASE WHEN NO2020>0 THEN NO2021/NO2020 ELSE NULL END AS RATE
-- SQLite має глюки з аліасами, проте на повноцінних БД працюватиме. Можна реалізувати через створення змінних
;


/*4. Вивести в алфавітному порядку назви найдорожчих книг у кожному жанрі.
Відобразити поля: жанр, назва книги, ціна, остання дата покупки книги, ім'я студента, який зробив останню покупку. З умовою, що всі ціни унікальні
*/
DROP TABLE IF EXISTS RankedGenre; -- знову ж таки, в SQLite не працює CREATE OR REPLACE яке мені більш подобається
CREATE TEMPORARY TABLE RankedGenre AS
SELECT
	genre
,	id_book
,	name_book
,	price
,	ROW_NUMBER() OVER (PARTITION BY genre ORDER BY price DESC) AS RowNum
FROM Book
--WHERE RowNum=1 -- обмеження SQLite
;
DELETE FROM RankedGenre WHERE RowNum<>1;

DROP TABLE IF EXISTS LastBay;
CREATE TEMPORARY TABLE LastBay AS
SELECT
	id_book
,	MAX(date) AS MAX_DATE
,	CAST( NULL AS INT) AS id_student
,	CAST( NULL AS VARCHAR(50)) AS name_student
FROM Register
WHERE id_book IN (SELECT id_book FROM RankedGenre)
GROUP BY id_book
;
UPDATE	LastBay AS A
SET		id_student = B.id_student
FROM	Register AS B
WHERE	A.id_book = B.id_book AND A.MAX_DATE = B.DATE
;
UPDATE	LastBay AS A
SET		name_student = B.name_student
FROM	Students AS B
WHERE	A.id_student = B.id_student
;


--5. Вивести всі можливі дані по книгах, у назві яких є символ "%"
SELECT * FROM Book WHERE name_book GLOB '*%*' ; -- SQLite
SELECT * FROM Book WHERE LIKE '%[%]%' ; -- MS SQL


--6. Вивести імена останніх (за датою) трьох студентів та книги, які вони брали
DROP TABLE IF EXISTS LastBay2;
CREATE TEMPORARY TABLE LastBay2 AS
SELECT
	id_student
,	MAX(date) AS MAX_DATE
--,	ROW_NUMBER() OVER (ORDER BY MAX_DATE DESC) AS RowNum
FROM Register
GROUP BY id_student
ORDER BY MAX_DATE DESC
;
DELETE FROM LastBay2
WHERE id_student NOT IN (SELECT id_student FROM
					 (SELECT id_student, MAX_DATE, ROW_NUMBER() OVER (ORDER BY MAX_DATE DESC) as rn FROM LastBay2 ORDER BY rn LIMIT 3 ) )
;
SELECT B.name_student, C.name_book, A.date
FROM 
	 Register AS A
	 LEFT JOIN Students as B
	 ON A.id_student = B.id_student
	 LEFT JOIN Book as C
	 ON A.id_book = C.id_book
WHERE A.id_student IN (SELECT id_student FROM LastBay2)
ORDER BY 1,2,3
;


--7. Вивести книги, які студенти не брали протягом січня 2021 року. За кожною книгою порахувати втрачений дохід, ґрунтуючись на середньомісячному продажу книги за останній рік
WITH
AvgIncome AS 
	(SELECT B.name_book, R.id_book, ROUND( COUNT(R.id_book)*B.price*(1.0/12),2) AS AvgIncome
	FROM Register AS R
		 LEFT JOIN Book as B
		 ON R.id_book = B.id_book
	WHERE strftime('%Y', R.date)='2021'
	GROUP BY B.name_book, R.id_book)
SELECT	A.name_book, A.AvgIncome AS Loss
FROM	AvgIncome AS A
WHERE	A.id_book NOT IN (SELECT id_book FROM Register WHERE date BETWEEN '2021-01-01' AND '2021-01-31')
;


--bonus
--1. Задача на віконні функції, наприклад знайти кумулятивну суму.
SELECT
	id_student
,	date
,	COUNT() AS NO
,	SUM(COUNT()) OVER (PARTITION BY id_student ORDER BY date) AS cumulative_NO
FROM
	Register
WHERE
	 id_student=2
GROUP BY
	id_student
,	date
ORDER BY
	id_student
,	date
;

--2. Перетворити дані для когортний/вінтажного аналіз (на жаль поточні дані не підходять для прикладу)