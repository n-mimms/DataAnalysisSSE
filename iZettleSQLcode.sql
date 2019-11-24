#########    iZettle:
USE IZettle;

#glimpse of tables
SELECT * FROM IZettle.IZettleOrder LIMIT 100;   
SELECT * FROM IZettle.IZettleAR;   #Retriever data is split up company-year (12 companies, 5 years = 60 rows)


##EXPLORATION:

#purchase types for each merchant:
SELECT merchant_id,
SUM(CASE WHEN target = '1' THEN 1 ELSE 0 END) AS "DesktopPurchases",
SUM(CASE WHEN target = '0' THEN 1 ELSE 0 END) AS "non-DesktopPurchases",
SUM(CASE WHEN target IS null THEN 1 ELSE 0 END) AS "Null-devicePurchases"
FROM IZettle.IZettleOrder
GROUP BY merchant_id ;


#Customer Facts (GROUP BY cid, ORDER BY total num purchases):
#NOTE: Top purchasers are birthyear-less and genderless (companies?)
#top purchasers tend to use desktops
#3 merchants dominate top-purchasers
SELECT cid, 
birthyear, count(distinct(birthyear)), country,
gender, COUNT(DISTINCT(gender)),
COUNT(*) AS numPurchases, SUM(purchase_amount) AS SumPurchases, ROUND(AVG(purchase_amount),1) AS AvgPurchaseAmt,  currency,
SUM(CASE WHEN target = '1' THEN 1 ELSE 0 END) AS "DesktopPurchases",
SUM(CASE WHEN target = '0' THEN 1 ELSE 0 END) AS "non-DesktopPurchases",
SUM(CASE WHEN target IS null THEN 1 ELSE 0 END) AS "Null-devicePurchases",
COUNT(DISTINCT(merchant_id)) AS "numMerchants", 
merchant_id FROM IZettle.IZettleOrder 
GROUP BY cid 
ORDER BY numPurchases DESC;

#GROUP BY country, basic facts
SELECT country, 
COUNT(*) AS "TotalTransactions", 
SUM(purchase_amount) AS "SumPurchases",
currency,
COUNT(DISTINCT(currency)),
COUNT(DISTINCT(cid)) AS "NumIndCustomers",
COUNT(DISTINCT(merchant_id)) AS "NumCompanies" FROM IZettle.IZettleOrder GROUP BY country;   

#GROUP BY Merchants: basic facts
SELECT merchant_id, 
COUNT(*) AS "TotalTransactions", 
COUNT(DISTINCT(cid)) AS "NumIndCustomers",
SUM(purchase_amount) AS "SumPurchases", 
currency,
COUNT(DISTINCT(country)), 
country 
FROM IZettle.IZettleOrder GROUP BY merchant_id;   

#More Merchant facts (incl. customer facts):
SELECT merchant_id, country,
COUNT(*) AS "TotalTransactions", 
SUM(CASE WHEN gender = 'male' THEN 1 ELSE 0 END) AS "Males",
SUM(CASE WHEN gender = 'female' THEN 1 ELSE 0 END) AS "Females",
SUM(CASE WHEN gender = 'none' THEN 1 ELSE 0 END) AS "NoGender",   #ONLY ONE STORE HAS 'none' GENDER
SUM(purchase_amount) AS "SumPurchases",
currency,
2015 - MAX(birthyear) AS "youngestCustomer", 
2015 - AVG(birthyear) AS "avgAgeCustomer", 
2015 - MIN(birthyear) AS "oldestCustomer", 
STD(birthyear) AS "stdDevCustomerAge"
FROM IZettle.IZettleOrder WHERE birthyear != "" GROUP BY merchant_id;  


#When 'birthyear' is blank, all the customers have "none" gender (these might be companies?)
#(44292 distinct customers with blank birthyear)
SELECT merchant_id, COUNT(*),
SUM(CASE WHEN gender = 'male' THEN 1 ELSE 0 END) AS "Males",
SUM(CASE WHEN gender = 'female' THEN 1 ELSE 0 END) AS "Females",
SUM(CASE WHEN gender = 'none' THEN 1 ELSE 0 END) AS "NoGender", 
COUNT(DISTINCT(cid)) 
FROM IZettle.IZettleOrder 
WHERE birthyear = "" 
GROUP BY merchant_id;

#look at bizarre case for merchant 2723490 : some birthyear-having rows have "none" genders (incomplete data? or a birth year for a company?)
#Should these none-gender rows have gender?
SELECT * FROM  IZettle.IZettleOrder 
WHERE merchant_id = '2723490' AND birthyear != "" AND  gender = "none";



# See if multiple birth years given -- e.g. one missing and one complete, GROUPing BY customer id (can we fix the data?)
SELECT num AS "BirthYrsGiven", merchant_id, COUNT(DISTINCT(merchant_id)), COUNT(*) 
FROM (SELECT cid, 
		merchant_id, 
		COUNT(DISTINCT(birthyear)) AS "num" 
		FROM IZettle.IZettleOrder GROUP BY cid) t 
GROUP BY num;
#204/44292 distinct customers have a blank birthyear that also have a complete birthyear (can fill those in!)

#Fill in 204 missing birthyears by join tables (fill in blanks)
SELECT *
FROM (SELECT cid, birthyear AS "badBirthYear" FROM IZettle.IZettleOrder WHERE birthyear = '' GROUP BY cid) TABLE1  #Table1 = blank birthyears
LEFT JOIN (SELECT cid, birthyear, merchant_id FROM IZettle.IZettleOrder WHERE birthyear != '' GROUP BY cid) TABLE2     #Table2 = complete birthyears
USING(cid); 
#I think all these missing birthyears come from a lazy merchant 2723490 but not sure right now...


#See sample customers who have a corrected birthyear:
SELECT * FROM  IZettle.IZettleOrder WHERE cid IN('100388900','1011085500','101175500','105885400','1094875500');

# All of blank ("") birthyears have gender = "none"   (indication of Company/ non-individual purchaser?)
SELECT COUNT(*), gender FROM IZettle.IZettleOrder WHERE birthyear = '' GROUP BY gender;
#Genderless, birthyear-less orders, by merchant (suppliers to companies?)
SELECT  merchant_id,  country, COUNT(*) AS NumPurchases 
FROM IZettle.IZettleOrder 
WHERE birthyear = '' AND gender = 'none' GROUP BY merchant_id ORDER BY NumPurchases desc;


#Count how many customers shop at 1, 2, 3... different stores:
#First collapse by customer ID to find number of DISTINCT stores they shopped at (inner query)
#Then collapse by that number (outer query).
SELECT NumberShoppedAt, 
COUNT(NumberShoppedAt) 
FROM 
(SELECT cid, COUNT(DISTINCT(merchant_id)) AS "NumberShoppedAt" FROM IZettle.IZettleOrder GROUP BY cid) t
GROUP BY NumberShoppedAt;   #Most customers (668,106) shop at one store. 5,667 have shopped at two stores, 40 have shopped at 3 stores


#TIME FACTORS:
#DAY OF WEEK (1 = sunday):
SELECT COUNT(*), DAYOFWEEK(datestamp) AS "wkday" FROM IZettle.IZettleOrder GROUP BY wkday;
#year:
SELECT COUNT(*), YEAR(datestamp) AS "yr" FROM IZettle.IZettleOrder GROUP BY yr;
#month:
SELECT COUNT(*), MONTH(datestamp) AS "mnth",YEAR(datestamp) AS "yr" FROM IZettle.IZettleOrder GROUP BY yr,mnth;

#Companies over time (merchant_it - year - month):
SELECT 
merchant_id,
COUNT(*) AS "NumTransactions",
COUNT(DISTINCT(cid)) AS "NumIndCustomers",
SUM(purchase_amount) AS "TotalSales",
currency,
MONTH(datestamp) AS "mnth",YEAR(datestamp) AS "yr" FROM IZettle.IZettleOrder GROUP BY merchant_id, yr,mnth;



#Companies over time (merchant_id - date):
SELECT 
merchant_id,
COUNT(*) AS "NumTransactions",
COUNT(DISTINCT(cid)) AS "NumIndCustomers",
SUM(purchase_amount) AS "TotalSales",
currency,
datestamp FROM IZettle.IZettleOrder GROUP BY merchant_id, datestamp;
	
#Transactions by Device: (NOTE: blank "Device" = NOT desktop, so there are more non-desktop than there appears)
SELECT 
device, COUNT(*) AS "NumTransactions", SUM(purchase_amount) AS "SumPurchases"
FROM IZettle.IZettleOrder
GROUP BY device;

#Transaction by Device and store: Do some stores tend to use one device?
SELECT 
merchant_id, device, COUNT(*) AS "NumTransactions", SUM(purchase_amount) AS "SumPurchases"
FROM IZettle.IZettleOrder
GROUP BY merchant_id, device;
#merchants 2756123, 4218266, 5913810, 6394740, 9402067 only uses ""/non-desktops (and NULL)

#Non-NA Counts by column: The only columns with NAs are "device" and "target"
SELECT COUNT(*) AS "TotalRows", COUNT(datestamp), COUNT(cid), COUNT(purchase_amount), 
COUNT(currency), COUNT(birthyear), COUNT(gender), COUNT(merchant_id), COUNT(country),
COUNT(device), COUNT(target) 
FROM IZettleOrder;

#Non-NA, Non-blank Counts by column: birthyear, device, and target have Blanks
SELECT COUNT(*) AS "TotalRows", COUNT(NULLIF(datestamp,'')), COUNT(NULLIF(cid,'')), COUNT(NULLIF(purchase_amount,'')), 
COUNT(NULLIF(currency,'')), COUNT(NULLIF(birthyear,'')), COUNT(NULLIF(gender,'')), COUNT(NULLIF(merchant_id,'')), COUNT(NULLIF(country,'')),
COUNT(NULLIF(device,'')), COUNT(NULLIF(target,'')) 
FROM IZettleOrder;

#gender breakdown:
SELECT merchant_id, gender, COUNT(*), COUNT(DISTINCT(cid)) FROM IZettleOrder GROUP BY merchant_id, gender;


#Sum of purchases by merchant and year. Can this be compared with something in AR table?
SELECT merchant_id, 
YEAR(datestamp) AS "Yr", 
SUM(purchase_amount) AS "SumPurchases", 
currency
FROM IZettleOrder GROUP BY merchant_id, Yr;

#All blanks in column "device" belong to target 0 (i.e. are NOT desktop purchases)
SELECT COUNT(*), target FROM IZettle.IZettleOrder WHERE device = "" GROUP BY target;   
SELECT COUNT(*), target, merchant_id FROM IZettle.IZettleOrder WHERE device = "" GROUP BY target, merchant_id;   #also group by another col (merchant)

