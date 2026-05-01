-- CREATE STAGING TABLE --
CREATE TABLE `naijamart_staging` (
  `TransactionID` text,
  `SaleDate` text,
  `Customer_Name` text,
  `Category` text,
  `Amount` double DEFAULT NULL,
  `Branch_Location` text,
  `Payment_Type` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--  LOAD RAW DATA INTO STAGING TABLE --
INSERT naijamart_staging
SELECT *
FROM `naijamart.`;

--  TRIM ALL COLUMNS --
UPDATE naijamart_staging
SET 
    TransactionID = TRIM(TransactionID),
    Customer_Name = TRIM(Customer_Name),
    Category = TRIM(Category),
    Amount = TRIM(Amount),
    SaleDate = TRIM(SaleDate),
    Branch_Location = TRIM(Branch_Location),
    Payment_Type = TRIM(Payment_Type);
    
 -- HANDLE MISSING NAMES --
 UPDATE naijamart_staging
SET Customer_Name = 'Unknown Customer'
WHERE Customer_Name IS NULL OR Customer_Name = '';

-- CONVERT AMOUNT TO NUMERIC --
ALTER TABLE naijamart_staging
MODIFY Amount DECIMAL(10,2);

--  FIX NEGATIVE AMOUNTS --
UPDATE naijamart_staging
SET Amount = ABS(Amount)
WHERE Amount < 0;

--  STANDARDIZE DATE FORMAT--
UPDATE naijamart_staging
SET SaleDate = 
    CASE
        -- VALID dd/mm/yyyy (avoid 00/00/0000)
        WHEN SaleDate REGEXP '^[0-3][0-9]/[0-1][0-9]/[1-2][0-9]{3}$'
             AND SaleDate <> '00/00/0000'
        THEN DATE_FORMAT(STR_TO_DATE(SaleDate, '%d/%m/%Y'), '%Y-%m-%d')

        -- VALID "Jul 17, 2025"
        WHEN SaleDate REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$'
        THEN DATE_FORMAT(STR_TO_DATE(SaleDate, '%b %d, %Y'), '%Y-%m-%d')

        -- VALID yyyy-mm-dd
        WHEN SaleDate REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN SaleDate

        -- INVALID → set to NULL (important!)
        ELSE NULL
    END;
    
    -- CONVERT SALEDATE TO DATE --
ALTER TABLE staging_naijamart
MODIFY SaleDate DATE;

-- STANDARDIZE CATEGORY --
UPDATE naijamart_staging
SET Category = 
    CASE
        WHEN LOWER(Category) IN ('house-hold', 'household') THEN 'Household'
        ELSE CONCAT(UPPER(LEFT(Category,1)), LOWER(SUBSTRING(Category,2)))
    END;

-- STANDARDIZE LOCATION --
UPDATE naijamart_staging
SET Branch_Location =
    CASE
        WHEN LOWER(Branch_Location) = 'lagos' THEN 'Lagos'
        WHEN LOWER(Branch_Location) IN ('vi', 'victoria island') THEN 'Victoria Island'
        WHEN LOWER(Branch_Location) = 'ibadan' THEN 'Ibadan'
        ELSE CONCAT(UPPER(LEFT(Branch_Location,1)), LOWER(SUBSTRING(Branch_Location,2)))
    END;

--  STANDARDIZE PAYMENT TYPE --
UPDATE naijamart_staging
SET Payment_Type =
    CASE
        WHEN LOWER(Payment_Type) = 'pos' THEN 'POS'
        WHEN LOWER(Payment_Type) = 'transfer' THEN 'Transfer'
        ELSE CONCAT(UPPER(LEFT(Payment_Type,1)), LOWER(SUBSTRING(Payment_Type,2)))
    END;

--  REMOVE DUPLICATES --
DELETE FROM naijamart_staging
WHERE TransactionID IN (
    SELECT TransactionID FROM (
        SELECT TransactionID,
               ROW_NUMBER() OVER (PARTITION BY TransactionID ORDER BY TransactionID) AS rn
        FROM naijamart_staging
    ) t
    WHERE rn > 1
);

-- REMOVE DUP FROM TRANSACTIONID --
UPDATE naijamart_staging
SET TransactionID = TRIM(REPLACE(TransactionID, '%dup%%', ''));
UPDATE naijamart_staging
SET TransactionID = REPLACE(TransactionID, '_DUP', '')
WHERE TransactionID LIKE '%_DUP';

-- STANDARDIZING BRANCH_LOCATION --
UPDATE naijamart_staging
SET Branch_Location =
    CASE
        WHEN LOWER(Branch_Location) LIKE '%abuja%' THEN 'Abuja'
        WHEN LOWER(Branch_Location) LIKE '%lagos%' THEN 'Lagos'
        WHEN LOWER(Branch_Location) LIKE '%ibadan%' THEN 'Ibadan'
         WHEN LOWER(Branch_Location) LIKE '%Victoria%' THEN 'Lagos'
         WHEN LOWER(Branch_Location) LIKE '%Yaba%' THEN 'Lagos'
         WHEN LOWER(Branch_Location) LIKE '%Phc%' THEN 'Lagos'
         WHEN LOWER(Branch_Location) LIKE '%Ikeja%' THEN 'Lagos'
         WHEN LOWER(Branch_Location) LIKE '%Lekki%' THEN 'Lagos'
        ELSE Branch_Location
    END;
    
SELECT *
FROM naijamart_staging
