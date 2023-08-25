--use the create command to create a database for the library
CREATE DATABASE SalfordLibrary;

-- use the use command to ensure that the database is being used
USE SalfordLibrary;

-- use the create table command to create a members table for the database
-- include constraints where necessary
-- ensure password security by using salted hash function
CREATE TABLE Members (
Member_ID int IDENTITY (1,1) PRIMARY KEY,
Username NVARCHAR(40) UNIQUE NOT NULL,
PasswordHash BINARY(64) NOT NULL,
Salt UNIQUEIDENTIFIER,
First_Name nvarchar(30) NOT NULL,
Middle_Name nvarchar(30) NULL,
Last_Name nvarchar(30) NOT NULL,
Address_1 nvarchar(50) NOT NULL,
Address_2 nvarchar(50) NULL,
City nvarchar(50)  NULL,
Postcode nvarchar(10)  NOT NULL,
DOB date NOT NULL,
Email nvarchar(100) NULL  CHECK 
(Email LIKE '%_@_%._%'),
Telephone nvarchar(20) NULL,
Date_Joined date NOT NULL,
Date_Left date NULL);

-- adjust the email column to ensure every email is unique
CREATE UNIQUE NONCLUSTERED INDEX UQ_Members_Email 
ON Members(Email)
WHERE Email IS NOT NULL;

-- create a table for overdue fines, indicating the right datatypes
CREATE TABLE Overdue_Fines (
Fine_ID int IDENTITY (1,1) PRIMARY KEY,
Member_ID int NOT NULL FOREIGN KEY REFERENCES Members (Member_ID),
Total_Overdue_Fine smallmoney  NOT NULL,
Fines_Paid smallmoney NOT NULL,
Fines_Outstanding smallmoney NOT NULL);

-- create a table for repayments done and methods of repayment
CREATE TABLE Repayments (
Repayment_ID int IDENTITY (1,1) PRIMARY KEY,
Fine_ID int NOT NULL FOREIGN KEY REFERENCES Overdue_Fines (Fine_ID) ,
Repayment_Date datetime NOT NULL,
Amount_Repaid money NOT NULL,
Repayment_method nvarchar(10) NOT NULL);

-- create a catalogue table that gives details of the items in the library
CREATE TABLE Catalogue (
Item_ID int IDENTITY(1,1) PRIMARY KEY,
Item_Title nvarchar(100) NOT NULL,
Item_Type nvarchar(30) NOT NULL,
Author nvarchar(100) NOT NULL, 
Year_of_Publication Date NOT NULL,
Date_added Date NOT NULL,
Current_Status nvarchar(30) NOT NULL,
Date_Lost_Or_Removed Date NULL,
ISBN_No nvarchar(50) NULL);

--adjust the catalogue table to ensure that all ISBN numbers of books are unique
CREATE UNIQUE NONCLUSTERED INDEX UQ_Catalogue_ISBN_No
ON Catalogue(ISBN_No)
WHERE ISBN_No IS NOT NULL;

-- create a table for the library loans, including all foreign keys
CREATE TABLE Loans (
Loan_ID int IDENTITY (1,1)  PRIMARY KEY,
MemberID int NOT NULL FOREIGN KEY REFERENCES Members (Member_ID),
Item_ID int NOT NULL FOREIGN KEY REFERENCES Catalogue (Item_ID),
Loan_Date date NOT NULL,
Loan_Due_Date date NULL,
Loan_Return_Date date NULL);

-- use the alter command to add an overdue fee column to the loans table
-- this column derives the over due based on conditions from other columns in the table
ALTER TABLE Loans ADD Overdue_Fee AS 
(CASE WHEN Loan_Return_Date IS NULL 
AND Loan_Due_Date < GETDATE()
THEN (DATEDIFF(dd, Loan_Due_Date, GETDATE()) * 0.1) 
ELSE 0 END);

--create a procedure to search library items by title
--which are ordered by their year of publication in descending order
CREATE PROCEDURE Title_search @Item_Title nvarchar(100)
AS
BEGIN
SELECT Item_Title, Year_of_Publication
FROM Catalogue WHERE Item_Title LIKE '%'+@Item_Title+'%'
ORDER BY Year_of_Publication DESC
END;

--create a procedure that have a duedate of less than 5 days from current date
--note that any item with due date less than current date is automatically overdue
CREATE PROCEDURE Loan_Items
AS
BEGIN
SELECT L.Loan_ID, C.Item_ID, C.Item_Title, L.Loan_Due_Date
FROM Loans L JOIN Catalogue C ON L.Item_ID = C.Item_ID
WHERE C.Current_Status =  'Overdue'
AND DATEDIFF(day, GETDATE(), L.Loan_Due_Date) <= 5
END;

-- create a procedure to insert a new member
CREATE PROCEDURE Insert_New_Member
	@Username nvarchar(40),
	@Password nvarchar(50),
    @First_Name nvarchar(30),
    @Middle_Name nvarchar(30),
    @Last_Name nvarchar(30),
    @Address_1 nvarchar(50),
    @Address_2 nvarchar(50),
    @City nvarchar(50),
    @Postcode nvarchar(10),
    @DOB date,
    @Email nvarchar(100),
    @Telephone nvarchar(20),
    @Date_Joined date,
    @Date_Left date
AS
BEGIN TRANSACTION
BEGIN TRY
DECLARE @salt UNIQUEIDENTIFIER=NEWID()
    INSERT INTO Members (Username, PasswordHash, Salt, First_Name, Middle_Name, Last_Name, 
	Address_1, Address_2, City, Postcode, DOB, Email, Telephone, Date_Joined, Date_Left)
    VALUES (@Username, HASHBYTES('SHA2_512', @Password+CAST(@Salt AS nvarchar(36))), 
	@Salt,  @First_Name, @Middle_Name, @Last_Name, @Address_1, @Address_2, @City, 
	@Postcode, @DOB, @Email, @Telephone, @Date_Joined, @Date_Left)
COMMIT TRANSACTION
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION
END CATCH

-- create a procedure to update existing member details
CREATE PROCEDURE Update_Member_Details
	@Member_ID int, @Username nvarchar(40) = NULL,
	@Password nvarchar(50) = NULL,  @First_Name nvarchar(30) = NULL, 
	@Middle_Name nvarchar(30) = NULL,  @Last_Name nvarchar(30) = NULL, 
	@Address_1 nvarchar(50) = NULL,  @Address_2 nvarchar(50) = NULL, 
	@City nvarchar(50) = NULL, @Postcode nvarchar(10) = NULL, 
	@DOB date = NULL, @Email nvarchar(100) =NULL,
	@Telephone nvarchar(20) = NULL, @Date_Joined date = NULL,
	@Date_Left date = NULL
AS
BEGIN TRANSACTION
BEGIN TRY
DECLARE @salt UNIQUEIDENTIFIER
SELECT @salt = Salt FROM Members WHERE Member_ID = @Member_ID
UPDATE Members
SET 
	Username = CASE WHEN @Username IS NOT NULL THEN @Username ELSE Username END,
	PasswordHash = CASE WHEN @Password IS NOT NULL THEN HASHBYTES('SHA2_512', @Password+CAST(@Salt AS nvarchar(36))) ELSE PasswordHash END,
	Salt = CASE WHEN @Password IS NOT NULL THEN @salt ELSE Salt END,
	First_Name = CASE WHEN @First_Name IS NOT NULL THEN @First_Name ELSE First_Name END,
      Middle_Name = CASE WHEN @Middle_Name IS NOT NULL THEN @Middle_Name ELSE Middle_Name END,
      Last_Name = CASE WHEN @Last_Name IS NOT NULL THEN @Last_Name ELSE Last_Name END,
      Address_1 = CASE WHEN @Address_1 IS NOT NULL THEN @Address_1 ELSE Address_1 END,
      Address_2 = CASE WHEN @Address_2 IS NOT NULL THEN @Address_2 ELSE Address_2 END,
      City = CASE WHEN @City IS NOT NULL THEN @City ELSE City END,
      Postcode = CASE WHEN @Postcode IS NOT NULL THEN @Postcode ELSE Postcode END,
      DOB = CASE WHEN @DOB IS NOT NULL THEN @DOB ELSE DOB END,
      Email = CASE WHEN @Email IS NOT NULL THEN @Email ELSE Email END,
      Telephone = CASE WHEN @Telephone IS NOT NULL THEN @Telephone ELSE Telephone END,
	  Date_Joined = CASE WHEN @Date_Joined IS NOT NULL THEN @Date_Joined ELSE Date_Joined END,
      Date_Left = CASE WHEN @Date_Left IS NOT NULL THEN @Date_Left ELSE Date_Left END
WHERE Member_ID = @Member_ID
COMMIT TRANSACTION
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION
END CATCH

-- create a view that shows details of loan history
CREATE VIEW Loan_History AS 
SELECT L.Loan_ID, 
M.Member_ID, 
C.Item_ID, 
C.Item_Title, 
L.Loan_Date, 
L.Loan_Due_Date,
O.Total_Overdue_Fine,
O.Fines_Outstanding
FROM Loans L 
JOIN Members M ON L.MemberID = M.Member_ID 
JOIN Catalogue C ON L.Item_ID = C.Item_ID
JOIN Overdue_Fines O ON O.Member_ID = M.Member_ID;

-- create trigger to update status of item to available when book is returned
CREATE TRIGGER Update_Status
ON Loans
AFTER UPDATE
AS
BEGIN
  UPDATE Catalogue
  SET Current_Status = 'Available'
  FROM Catalogue
  INNER JOIN inserted ON Catalogue.Item_ID = inserted.Item_ID
  WHERE inserted.Loan_Return_Date IS NOT NULL
    AND Item_Type = 'Book'
    AND (Catalogue.Current_Status = 'On Loan' OR Catalogue.Current_Status = 'Overdue');
END;

-- create a function that returns the total number of loans made on a specified date
CREATE FUNCTION Total_Loans (@LoanDate AS date)
RETURNS INT
AS
BEGIN
    RETURN 
	(SELECT COUNT(*) AS No_of_Loans
	FROM Loans 
	WHERE Loan_Date = @LoanDate);
END;

-- use the insert command to populate the members table with details of its members
INSERT INTO Members 
(Username, PasswordHash, Salt, First_Name, Middle_Name, Last_Name, Address_1, 
Address_2, City, Postcode, DOB, Email, Telephone, Date_Joined, Date_Left)
VALUES  
	( 'marymosefoh', HASHBYTES('SHA2_512', 'redberries'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(), 'Mary', 'Aikhuenmosefoh', 'Aisagbonhi', '137B',
	'Elma Lane', 'Silverton', 'BL9 MH4', '1996-10-13', 'maryai@gmail.com', 
	'0170349858', '2019-02-12', NULL),
	('hopemuse', HASHBYTES('SHA2_512', 'blueberries'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(), 'Peter', 'Hope', 'Imuse', '15', NULL, NULL,
	'CH7 NB8','1993-08-11',NULL, NULL, '2021-05-08', NULL),
	('LiamG2', HASHBYTES('SHA2_512', 'grapes'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(),'George', NULL, 'Liam',  '156S', NULL, 'Falltown', 
	'M1 2AS', '2001-10-23', 'liamG@hotmail.com', NULL, '2020-01-01', '2023-03-12'),
	('madSeki0', HASHBYTES('SHA2_512', 'lemons'+CAST(NEWID()
	AS nvarchar(36))), NEWID(), 'Seki','Mary', 'Ahmad', '12', 'Jogger road', 
	'Ferry', 'SK2 3BN', '1998-05-16', 'sekiA@gmail.com', '0144567512', '2023-01-01', NULL),
	('Bjosh', HASHBYTES('SHA2_512', 'strawberries'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(),'Josh', NULL, 'Benard', '7', 'Sale lane',
	'Manchester', 'M11 5RT', '2001-07-23', NULL, NULL, '2021-06-17', NULL),
	('leyGed', HASHBYTES('SHA2_512', 'coconut'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(), 'Ged', NULL, 'Buckley', '26', NULL, NULL,
	'M28 6YT', '1996-09-26', 'gedB@yahoo.com', '0776845034', '2020-03-14', '2023-01-09'),
	('zeebibi',  HASHBYTES('SHA2_512', 'berries'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(),'Komal', 'Ayibi', 'Zee', '4A' , 'Westport lane', 'Birmingham',
	'BG3 6FD', '1995-09-24', 'komalbibi@gmail.com', '0773945254', '2021- 08-01', '2023-02-13'),
	('sefohsefoh', HASHBYTES('SHA2_512', 'almond'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(), 'Sefoh', NULL, 'Imuse', '122B', NULL, NULL,
	'6NW 4YN', '1999-02-16', NULL, NULL, '2022-09-18', NULL),
	('richierich', HASHBYTES('SHA2_512', 'cashews'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(), 'Daniel', 'Hope', 'Richie', '34C', NULL, 'Swinton', 
	'5OL 9OT', '2002-08-08', NULL, NULL, '2019-05-17', NULL),
	('atiomomo', HASHBYTES('SHA2_512', 'grapes'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(),'Charles', 'Izie', 'Atiomo', '7', 'Fours sisters street',
	'Salford', 'M19 4YU', '1999-01-01', 'izieAt@gmail.com', NULL, '2021-08-07', NULL),
	('saruba', HASHBYTES('SHA2_512', 'peach'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(), 'Elsie', 'Osaru', 'Ogioba', '45A', NULL, 'Salford', 'M34 4EA',
	'2000-05-23', 'elsie@gmail.com', '0776214890', '2022-12-21', '2023-01-29'),
	('livieAte', HASHBYTES('SHA2_512', 'kiwis'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(), 'Olivia',NULL, 'Ubuane', '34', 'Sale lane', 'Worsley',
	'M21 5FT', '1997-08-05', 'livie@gmail.com','0724384900', '2023-02-21', NULL),
	('emasoph', HASHBYTES('SHA2_512', 'oranges'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(), 'Sophia', 'Emma', 'Ubaune', '21', 'Archies lane', 'Trafford',
	'M43 4DG', '2002-12-01', 'sophia@gmail.com', '0784550076', '2022-03-17', NULL),
	('jayboy',  HASHBYTES('SHA2_512', 'mangoes'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(),'Jayden', 'Ose', 'Okojie', '6A', NULL, NULL, 'SK5 3WE',
	'1998-04-09', 'jayboy@gmail.com', '0748935006', '2021-12-19', NULL),
	('swissk',  HASHBYTES('SHA2_512', 'pawpaw'+CAST(NEWID() 
	AS nvarchar(36))), NEWID(),'Peter', 'Swiss', 'Halbert', '16B', 'Eleanor drive', 'Manchester',
	'M19 4BD', '1993-10-12', 'SwissP@gmail.com', '0702501345', '2023-04-04', NULL);

-- check the members table to find out if password s protected with password hash
SELECT * FROM Members

 -- insert details of the current overdue fines into the fines table
INSERT INTO Overdue_Fines (Member_ID, Total_Overdue_Fine, Fines_Paid, Fines_Outstanding)
VALUES (1, 0.7, 0, 0.7),
(12, 0.2, 0, 0.2),
(8, 2.3, 1.3, 1.0),
(5, 3.1, 2.0, 1.1),
(4, 0.2, 0.2, 0);

--insert values of the repayment table
INSERT INTO Repayments (Fine_ID, Repayment_Date, Amount_Repaid, Repayment_method)
VALUES (3, '2023-04-13 11:00', 1.3, 'Card'),
(4, '2023-03-27 10:00', 2.0, 'Cash'),
(5, '2023-03-04 13:00', 0.2, 'Card');

--insert values into the catalogue table
INSERT INTO Catalogue (Item_Title, Item_Type, Author, Year_of_Publication, Date_added, 
											Current_Status, Date_Lost_Or_Removed, ISBN_No)
VALUES ('All About Pineapples', 'Book', 'Florence Abel', '2004', '2006-12-19', 'On Loan', NULL, '34583221'),
('The Good Dog','Book', 'Anjola Daniels', '2005', '2007-03-10', 'Overdue', NULL, '12345678'),
('Principles of Programming', 'DVD',  'Seyi Eyeo', '2011', '2019-06-06', 'On Loan', NULL, NULL),
('The CookBook', 'Book', 'Sarah Jones', '2012', '2018-05-03', 'Available', NULL, '23456789'),
('Music and Soul', 'Other Media', 'Jessica Parker', '2015', '2019-10-24', 'Available', NULL, NULL),
('The Three Wise Friends', 'Journal', 'David Albert', '2017', '2020-01-07', 'Overdue', NULL, NULL),
('Thats the Way its Done', 'Journal', 'Albert Staff', '2020', '2023-01-06', 'Lost/Removed', '2023-03-12', NULL),
('Hello World', 'Journal', 'Mike Dumbo', '2009', '2012-10-17',  'Overdue', NULL, NULL),
('Amazing World of Kitty', 'Viola Marcy', 'Journal', '2013', '2017-10-21', 'Overdue', NULL, NULL),
('Snail Farming', 'Journal', 'Mary Statam', '2020', '2021-03-17', 'On Loan', NULL, NULL);

--insert loan details into the loan table
INSERT INTO Loans (MemberID, Item_ID, Loan_Date, Loan_Due_Date, Loan_Return_Date)
VALUES (2, 1, '2023-01-05', '2023-05-28', NULL),
(1, 2, '2023-02-06', '2023-04-12', NULL),
(14,  3, '2023-04-02', '2023-05-24', NULL),
(12, 6, '2023-03-01', '2023-04-17', NULL),
(7, 4, '2023-02-01', '2023-02-13', '2023-02-13'),
(3, 5, '2023-01-12', '2023-03-01', '2023-03-01'),
(8, 8, '2023-02-27', '2023-03-27', NULL),
(5, 9, '2023-02-19', '2023-03-19', NULL),   
(4, 7, '2023-02-24', '2023-03-01', '2023-03-04');

--execute the title search stored procedure
EXEC Title_search 'The';

--execute the loan items stored procedure 
EXEC Loan_Items

--execute the insert new member stored procedure
EXEC Insert_New_Member 
    @Username = 'wolexy',
    @Password = 'cherries',
    @First_Name = 'Wole',
	@Middle_Name = NULL,
    @Last_Name = 'Doe',
    @Address_1 = '6',
	@Address_2 = 'Salford Crescent',
    @City = 'Salford',
    @Postcode = '12345',
    @DOB = '1990-01-01',
    @Email = 'wole@gmail.com',
    @Telephone = NULL,
    @Date_Joined = '2023-04-20',
	@Date_Left = NULL;

-- update details of member with member_ID 2 using stored procedure
EXEC Update_Member_Details @Member_ID = 2, @Address_2 = '16 Good will lane', @Telephone = '0792743500';

-- to try out the update status trigger created, first update the loans
-- and then check the catalogue table to see that current status of item_1 is now available
UPDATE Loans
SET Loan_Return_Date = '2023-04-20'
WHERE Item_ID = 1;

SELECT * FROM Catalogue;

-- call the function using 2nd february 2023
SELECT dbo.Total_Loans('2023-02-24');

-- Find members who joined the library before or during the year 2020
SELECT *
FROM Members 
WHERE YEAR(Date_Joined) <= 2020;

-- find out members who have not taken any loan yet
SELECT Member_ID, First_Name, Middle_Name, Last_Name, Email, Telephone
FROM Members WHERE Member_ID NOT IN
(SELECT DISTINCT MemberID
FROM Loans);

--create a view that allows the library to search for items that are overdue and their current overdue fines
CREATE VIEW Items_Overdue AS
SELECT C.Item_Title, O.Total_Overdue_Fine, O.Fines_Outstanding, 
M.Member_ID, M.First_Name, M.Last_Name, M.Email, M.Telephone
FROM Overdue_Fines O
JOIN Members M ON O.Member_ID = M.Member_ID
JOIN Loans L ON L.MemberID = M.Member_ID
JOIN Catalogue C ON C.Item_ID = L.Item_ID
WHERE C.Current_Status = 'Overdue';

--call the view
SELECT * FROM Items_Overdue;

-- check that the library database can be restored and backup not corrupt
BACKUP DATABASE SalfordLibrary
TO DISK =
'C:\SalfordLibrary_Backup\SalfordLibrarycheck.bak' 
WITH CHECKSUM;

RESTORE VERIFYONLY
FROM DISK =
'C:\SalfordLibrary_Backup\SalfordLibrarycheck.bak'  
WITH CHECKSUM;




