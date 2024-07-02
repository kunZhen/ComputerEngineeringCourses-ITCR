-------------------- Examen Parcial 2 --------------------
-- Estudiante: Kun Kin Zheng Liang


-------------------- I Parte: DML SQL --------------------

/*
1. Cree una base de datos que se llame Parcial2_RRHH
*/

CREATE DATABASE Parcial2_RRHH;

USE Parcial2_RRHH; -- le agrego esto para que de una vez lo rediriga a la base de datos 

/*
2. Desarrollar las sentencias necesarias para las relaciones Employee y Person 
del diagrama entidad relación. DDL completo: tipos de datos, constraints, integridad referencial
*/

CREATE TABLE Person (
    BusinessEntityID INT NOT NULL PRIMARY KEY,
    PersonType NCHAR(2) NOT NULL, 
    Title NVARCHAR(8),
    FirstName NVARCHAR(50) NOT NULL,
    MiddleName NVARCHAR(50),
    LastName NVARCHAR(50) NOT NULL,
    Suffix NVARCHAR(10),
    EmailPromotion INT NOT NULL
);

CREATE TABLE Employee (
    BusinessEntityID INT NOT NULL PRIMARY KEY,
    NationalIDNumber NVARCHAR(15) NOT NULL,
    LoginID NVARCHAR(256) NOT NULL,
    JobTitle NVARCHAR(50) NOT NULL,
    BirthDate DATE NOT NULL,
    MaritalStatus NCHAR(1) NOT NULL,
    Gender NCHAR(1) NOT NULL,
    HireDate DATE NOT NULL,
    VacationHours SMALLINT NOT NULL,
    SickLeaveHours SMALLINT NOT NULL,
    CurrentFlag BIT NOT NULL
);

ALTER TABLE
ADD CONSTRAINT FK_Employee_BusinessEntity
FOREIGN KEY (BusinessEntityID) REFERENCES Person(BusinessEntityID);

/*
3. Actualización sobre la relación Employee que aumente en un día las vacaciones 
para los empleados con más de 20 años en la compañia
*/

UPDATE Employee
SET VacationHours = VacationHours + 8
WHERE DATEDIFF(YEAR, HireDate, GETDATE()) >= 20;

/*
4. Store procedure que reciba como entrada los datos de una Persona y 
realiza la inserción de la persona en la relación Person
*/

CREATE PROCEDURE InsertPerson
    @BusinessEntityID INT,
    @PersonType NCHAR(2),
    @Title NVARCHAR(8),
    @FirstName NVARCHAR(50),
    @MiddleName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Suffix NVARCHAR(10),
    @EmailPromotion INT
AS
BEGIN
    INSERT INTO Person (BusinessEntityID, PersonType, Title, FirstName, MiddleName, LastName, Suffix, EmailPromotion)
    VALUES (@BusinessEntityID, @PersonType, @Title, @FirstName, @MiddleName, @LastName, @Suffix, @EmailPromotion);
END;

/*
5. Trigger cuando se borre un Employee verifique, si el periodo de prueba no ha sido pasado, 
también borre el registro en la relación Person.
*/

CREATE TRIGGER trg_DeleteEmployee
ON Employee
FOR DELETE
AS
BEGIN
    DELETE FROM Person
    WHERE BusinessEntityID IN (
        SELECT BusinessEntityID
        FROM deleted
        WHERE DATEDIFF(MONTH, HireDate, GETDATE()) <= 3
    );
END;


/*
6. Función que recibe el BussinessEntityID y regresa el departamento en el que trabaja el empleado 
*/

CREATE FUNCTION GetEmployeeDepartment (@BusinessEntityID INT)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @DepartmentName NVARCHAR(50);

    SELECT @DepartmentName = d.Name
    FROM EmployeeDepartmentHistory edh
    JOIN Department d ON edh.DepartmentID = d.DepartmentID
    WHERE edh.BusinessEntityID = @BusinessEntityID
    AND edh.EndDate IS NULL; -- tomando en cuenta que EndDate NULL significa que aún está en el departamento (se le menciona al profe, me indica que se lo tiene que agregar a su solución)

    RETURN @DepartmentName;
END;

/*
7. Consulta que retorne el FirstName, LastName y la cantidad de historial de pagos
(EmployeePayHistory), en aquellos donde el historial de pagos sea mayor a uno.
Resultado ordenado por nombre y apellido.
*/

SELECT p.FirstName, p.LastName, COUNT(eph.BusinessEntityID) AS PaymentHistoryCount
FROM Person p
JOIN EmployeePayHistory eph ON p.BusinessEntityID = eph.BusinessEntityID
GROUP BY p.FirstName, p.LastName
HAVING COUNT(eph.BusinessEntityID) > 1
ORDER BY p.FirstName, p.LastName;

/*
8. Vista que muestre el FirstName, LastName de los empleados que nunca han recibido
un salario. 
*/

CREATE VIEW EmployeesWithoutPayHistory AS
SELECT p.FirstName, p.LastName
FROM Person p
JOIN Employee e ON p.BusinessEntityID = e.BusinessEntityID
LEFT JOIN EmployeePayHistory eph ON e.BusinessEntityID = eph.BusinessEntityID
GROUP BY p.FirstName, p.LastName
HAVING COUNT(eph.BusinessEntityID) = 0;



-------------------- II Parte: RESPUESTA CORTA --------------------
/* 

1. ¿Qué especifica la Tercer Forma Normal?
	Esta forma normal se basa en una dependencia transitiva: X-Z y Z-Y. 
	Se podría tomar el diagrama del examen como ejemplo, 
	específicamente la Tabla EmployeeDepartmentHistory, de manera que, 
	Employee-EmployeeDepartmentHistory y EmployeeDepartmentHistory-Shift, relación X-Z y Z-Y.

2. ¿Qué es una ACID para una transacción? 

ACID corresponde a las siglas de atomicidad, consistente, isolation y durable, específicamente.

- Atomicidad: viene a ser una unidad atómica de procesamiento, por lo que su ejecución 
se realiza de manera completa o no.

- Consistente: este indica que al ejecutar una transacción por completo, esta debe llevar
la base de datos, de un estado en la cual se encontraba consistente, a otro donde se mantiene
esa consistencia. Antes y después de la transacción, la Base mantiene sus consistencia.

 - Isolation: en español, aislamiento, indicando que una transacción en sí debe aparecer que se ejecuta
 de manera aislada de otras trasacciones que se encuentren ejecutando. En otras palabras, una transacción
 no debe interferir a otra. 

 - Durable: los cambios que se han realizado por una transacción deben de mantenerse, es decir, persistir. 

 */