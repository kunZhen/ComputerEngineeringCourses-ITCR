--------------------------- EJERCICIO 2 ---------------------------

-- Crear la tabla Dependent en el esquema Person
CREATE TABLE Person.Dependent (
    DependantID INT NOT NULL PRIMARY KEY,
    Fname NVARCHAR(50) NULL,
    Lname NVARCHAR(50) NULL,
    Sex NVARCHAR(1) NOT NULL,
    BusinessEntityID INT NOT NULL
);

-- Crear la relación de llave foránea
ALTER TABLE Person.Dependent
ADD CONSTRAINT FK_Dependent_Person
FOREIGN KEY (BusinessEntityID) REFERENCES Person.Person(BusinessEntityID);

--------------------------- EJERCICIO 3 ---------------------------

-- Buscamos el ID de Ken Sánchez
SELECT BusinessEntityID, FirstName, LastName
FROM Person.Person
WHERE FirstName = 'Ken' AND LastName = 'Sánchez';

-- El BusinessEntityID de Ken Sánchez es 1 o 1726, según la búsqueda hecha
DECLARE @KenBusinessEntityID INT;
SET @KenBusinessEntityID = 1; 

INSERT INTO Person.Dependent (DependantID, Fname, Lname, Sex, BusinessEntityID)
VALUES
(1, 'Pedro', 'Sánchez', 'M', @KenBusinessEntityID),
(2, 'Pancha', 'Sánchez', 'F', @KenBusinessEntityID),
(3, 'Fulano', 'Sánchez', 'M', @KenBusinessEntityID);

--------------------------- EJERCICIO 4 ---------------------------

-- Buscamos el ID de Terri Duffy
SELECT BusinessEntityID, FirstName, LastName
FROM Person.Person
WHERE FirstName = 'Terri' AND LastName = 'Duffy';

-- El BusinessEntityID de Terri Duffy es 2 o 2237
DECLARE @TerriBusinessEntityID INT;
SET @TerriBusinessEntityID = 2;

INSERT INTO Person.Dependent (DependantID, Fname, Lname, Sex, BusinessEntityID)
VALUES
(4, 'Mengano', 'Duffy', 'M', @TerriBusinessEntityID),
(5, 'Zutano', 'Duffy', 'M', @TerriBusinessEntityID);

--------------------------- EJERCICIO 5 ---------------------------

-- Buscamos el ID de Roberto Tamburello
SELECT BusinessEntityID, FirstName, LastName
FROM Person.Person
WHERE FirstName = 'Roberto' AND LastName = 'Tamburello';

-- El BusinessEntityID de Roberto Tamburello es 3
DECLARE @RobertoBusinessEntityID INT;
SET @RobertoBusinessEntityID = 3; 

INSERT INTO Person.Dependent (DependantID, Fname, Lname, Sex, BusinessEntityID)
VALUES
(6, 'Fulana', 'Tamburello', 'F', @RobertoBusinessEntityID);

--------------------------- EJERCICIO 6 ---------------------------

SELECT 
    p.FirstName AS PersonaFirstName,
    p.LastName AS PersonaLastName,
    d.Fname AS DependentFirstName,
    d.Lname AS DependentLastName,
    d.Sex AS DependentSex
FROM 
    Person.Person p
JOIN 
    Person.Dependent d
ON 
    p.BusinessEntityID = d.BusinessEntityID;

--------------------------- EJERCICIO 7 ---------------------------

-- Verificamos la existencia de los correos electrónicos
SELECT *
FROM Person.EmailAddress
WHERE EmailAddress IN ('ken0@adventureworks.com', 'terri0@adventure-works.com', 'roberto0@adventure-works.com', 'rob0@adventure-works.com', 'gail0@adventure-works.com');

-- ELiminamos las direcciones de correo electrónico
DELETE FROM Person.EmailAddress
WHERE EmailAddress IN ('ken0@adventureworks.com', 'terri0@adventure-works.com', 'roberto0@adventure-works.com', 'rob0@adventure-works.com', 'gail0@adventure-works.com');

--------------------------- EJERCICIO 8 ---------------------------
SELECT 
    p.FirstName AS PersonaFirstName,
    p.LastName AS PersonaLastName
FROM 
    Person.Person p
JOIN 
    Person.Dependent d
ON 
    p.BusinessEntityID = d.BusinessEntityID
WHERE 
    d.Sex = 'M'
GROUP BY 
    p.FirstName, p.LastName
HAVING 
    COUNT(d.DependantID) >= 2;

--------------------------- EJERCICIO 9 ---------------------------
SELECT 
    p.FirstName AS PersonaFirstName,
    p.LastName AS PersonaLastName
FROM 
    Person.Person p
LEFT JOIN 
    Person.EmailAddress e
ON 
    p.BusinessEntityID = e.BusinessEntityID
WHERE 
    e.EmailAddress IS NULL;

--------------------------- EJERCICIO 10 ---------------------------

USE AdventureWorks2019; -- Asegúrate de reemplazar con el nombre de tu base de datos
GO

-- Crear el procedimiento almacenado
CREATE PROCEDURE GetPersonsByCountry
    @CountryName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.FirstName AS PersonaFirstName,
        p.LastName AS PersonaLastName
    FROM 
        Person.Person p
    JOIN 
        Person.Address a ON p.BusinessEntityID = a.AddressID
    JOIN 
        Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
    JOIN 
        Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode
    WHERE 
        cr.Name = @CountryName
    ORDER BY 
        p.LastName, p.FirstName;
END;
GO

--------------------------- EJERCICIO 11 ---------------------------

-- Trigger que se ejecuta después de cada INSERT y UPDATE en la tabla Person.Dependent
CREATE TRIGGER trg_UpdatePersonModifiedDateOnInsertOrUpdate
ON Person.Dependent
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET p.ModifiedDate = GETDATE()
    FROM Person.Person p
    INNER JOIN inserted i ON p.BusinessEntityID = i.BusinessEntityID;
END;
GO

-- Trigger que se ejecute después de cada DELETE en la tabla Person.Dependent.
CREATE TRIGGER trg_UpdatePersonModifiedDateOnDelete
ON Person.Dependent
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET p.ModifiedDate = GETDATE()
    FROM Person.Person p
    INNER JOIN deleted d ON p.BusinessEntityID = d.BusinessEntityID;
END;
GO

--------------------------- EJERCICIO 12 ---------------------------

-- Función para obtener el nombre del país basado en BusinessEntityID
CREATE FUNCTION dbo.GetCountryByBusinessEntityID
(
    @BusinessEntityID INT
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @CountryName NVARCHAR(50);

    SELECT @CountryName = cr.Name
    FROM Person.Person p
    JOIN Person.Address a ON p.BusinessEntityID = a.AddressID
    JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
    JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode
    WHERE p.BusinessEntityID = @BusinessEntityID;

    RETURN @CountryName;
END;

--------------------------- EJERCICIO 13 ---------------------------

SELECT 
    p.FirstName AS PersonaFirstName,
    p.LastName AS PersonaLastName,
    dbo.GetCountryByBusinessEntityID(p.BusinessEntityID) AS CountryName
FROM 
    Person.Person p
ORDER BY 
    p.LastName, p.FirstName;
