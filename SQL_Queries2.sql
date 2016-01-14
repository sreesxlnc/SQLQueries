/********************************* IDS 521 ********************************
**********************   Sreekanth Chinthagunta  ********************
**************************************************************************/
	
/* Since we will be using tweets table and search the table with various conditions, we will create a table
 * named "Tweets_Indexed" in which we have index on several columns */
 DROP TABLE IF EXISTS Tweets_Indexed;
 
 -- Create table
 CREATE TABLE Tweets_Indexed (
	smblid VARCHAR(10),
	symbol VARCHAR(8),
	periodnum INT,
	periodnum_inday INT, 
	volumestart INT,
	volumeend INT,
	twittermentions INT,
	twitterpermin DECIMAL(10,2), 
	averagefollowers DECIMAL(10,2),
	datestart DATE,
	timestart TIME,
	dateend DATE, 
	timeend TIME,
	INDEX i_smblid (smblid),
    INDEX i_twitterpermin (twitterpermin),
    INDEX i_periodnum (periodnum),
    INDEX i_periodnum_inday(periodnum_inday),
    INDEX i_datestart(datestart),
    INDEX i_timestart(timestart)
);

-- Insert data from tweets table into Tweets_Indexed table
INSERT INTO Tweets_Indexed SELECT * FROM tweets;
/*************************************** Part 1 ***************************************/
/************************************* Question 1 *************************************/
-- number of firms that are represented in at least 30 days
SELECT COUNT(*) FROM (SELECT smblid, COUNT(DISTINCT datestart) No_of_Days FROM tweets2 GROUP BY smblid HAVING COUNT(DISTINCT datestart) >= 30) a;
-- List of companies 
SELECT smblid, COUNT(DISTINCT datestart) No_of_Days FROM tweets2 GROUP BY smblid HAVING COUNT(DISTINCT datestart) >= 30;


/************************************* Question 2 *************************************/
DROP TABLE IF EXISTS TradeVolumeChange;

CREATE TABLE TradeVolumeChange(Symbol VARCHAR(10), EarningsReleaseDate DATE, VolumeStart INT, VolumeEnd INT, ChangeInVolume INT); 

INSERT INTO TradeVolumeChange SELECT t1.smblid,em1.earnrelease_date
									  ,min(volumestart)
									  ,max(volumeend)
									  ,(max(volumeend)-min(volumestart)) FROM tweets_indexed t1, EarnRelMatched em1 
																		WHERE t1.smblid = em1.ticker
																		  AND t1.datestart = em1.datestart
																		  AND t1.periodnum BETWEEN em1.periodnum AND (em1.periodnum+3)
																	 GROUP BY t1.smblid, em1.datestart;

/*************************************** Part 2 ***************************************/
/************************************* Question 3 *************************************/
DROP TABLE IF EXISTS Percentile_Threshold;

-- Create stored procedure. The stored procedure takes percentile value as input.accessible
DROP PROCEDURE IF EXISTS calculate_percentile;

DELIMITER $$
CREATE PROCEDURE calculate_percentile(IN p_percentile decimal(10,2)) 
BEGIN

DECLARE number_of_obs decimal(10,2);
DECLARE index_number int;
DECLARE index_number2 int;
DECLARE percentile_value double;
DECLARE iterations int default 0;
DECLARE finished int default 0;
DECLARE l_smblid VARCHAR(10);
DECLARE l_startdate DATE;
-- Declaring cursor to fetch distinct combinations of Firm and Date from Tweets_Indexed table
DECLARE data_cursor CURSOR FOR SELECT DISTINCT smblid,datestart  FROM Tweets_Indexed;
-- Declare not found handler, which will be used to exit the loop when there are no rows to process
DECLARE CONTINUE handler FOR NOT FOUND SET finished = 1;

-- Create a table during the first iteration to store smblid, datestart and threshod value
IF(iterations = 0 ) THEN
 	CREATE TABLE Percentile_Threshold(smblid VARCHAR(10),datestart DATE, threshold DOUBLE, INDEX i_smblid(smblid), INDEX i_datestart(datestart), INDEX i_threshold(threshold));
END IF;    

OPEN data_cursor;
-- Loop through the values fetched by the cursor and calculate threshold for each combination
get_data: loop
-- Counting the number of iterations for debugging purpose
SET iterations = iterations+1;
-- Fetch smblid, datestart into local variables
FETCH data_cursor INTO l_smblid,l_startdate;
IF (finished = 1) THEN 
	LEAVE get_data;
END IF;
-- Find the number of observations and store them in a local variables
SELECT (COUNT(*)*p_percentile) INTO number_of_obs FROM Tweets_Indexed WHERE smblid = l_smblid AND datestart <= l_startdate;
-- If the number obtained is a whole number then we need to take average of two numbers
IF (CEILING(number_of_obs) = number_of_obs) THEN
	SET index_number = number_of_obs;
	SET index_number2 = index_number+1;
    SELECT (max(t1.twitterpermin)+max(t2.twitterpermin))/2 INTO percentile_value FROM (SELECT twitterpermin FROM Tweets_Indexed WHERE smblid = l_smblid AND datestart <= l_startdate ORDER BY twitterpermin LIMIT index_number) t1, (SELECT twitterpermin FROM Tweets_Indexed WHERE smblid = l_smblid AND datestart <= l_startdate ORDER BY twitterpermin LIMIT index_number2) t2;
	-- INSERT INTO test VALUE (concat('Inside if condition -->',iterations,':::smblid : ',l_smblid,':::startdate : ',l_startdate)); 
ELSE 
	SET index_number = ROUND(number_of_obs);
    SELECT max(twitterpermin) INTO percentile_value FROM (SELECT twitterpermin FROM Tweets_Indexed WHERE smblid = l_smblid AND datestart <= l_startdate ORDER BY twitterpermin LIMIT index_number) t1;
END IF;
-- Insert into the main threshold table
INSERT INTO Percentile_Threshold(smblid,datestart,threshold) VALUE (l_smblid,l_startdate,percentile_value);
COMMIT;
END loop get_data;
CLOSE data_cursor;
END $$

DELIMITER ;

-- Call stored procedure
CALL calculate_percentile(0.99);

/************************************* Question 4 *************************************/
DROP TABLE IF EXISTS Twitter_Peaks;

CREATE TABLE Twitter_Peaks(smblid VARCHAR(10), periodnum int,datestart date, VolDiff int, INDEX i_smblid(smblid),INDEX i_periodnum(periodnum),INDEX i_VolDiff(VolDiff));

INSERT INTO Twitter_Peaks 
SELECT ti2.smblid,ti2.periodnum
      ,ti2.datestart
      ,(max(ti2.volumeend)-min(ti2.volumeend)) '40Min_Vol_Diff'  
 FROM (SELECT ti.smblid, ti.periodnum,ti.periodnum_inday FROM tweets_indexed ti, percentile_threshold pt 
													    WHERE ti.smblid = pt.smblid 
														  AND ti.datestart = pt.datestart 
														  AND ti.twitterpermin > pt.threshold) t, tweets_indexed ti2 
WHERE t.smblid = ti2.smblid 
  AND ti2.periodnum BETWEEN t.periodnum AND (t.periodnum+4)
  AND ti2.periodnum_inday  BETWEEN t.periodnum_inday AND (t.periodnum_inday+4)
GROUP BY t.smblid, t.periodnum;

COMMIT;							

/*************************************** Part 3 ***************************************/				
/************************************* Question 5 *************************************/
DROP TABLE IF EXISTS Baseline_Average;

CREATE TABLE Baseline_Average(smblid VARCHAR(10),TenAMAvg DECIMAL(10,2), TwelvePMAvg DECIMAL(10,2), TwoPMAvg DECIMAL(10,2));

/* We select period number which falls in the first ten minute range (10.00 - 10.10 etc ) and consider four periods from that period number to get 40 min range */
INSERT INTO Baseline_Average          
SELECT t.smblid, avg(t.volchange) '10AM', avg(u.volchange) '12PM',avg(v.volchange) '2PM' FROM (SELECT ti2.smblid, ti2.datestart, 
												(max(ti2.volumeend)-min(ti2.volumestart)) 'volchange' FROM (SELECT ti.smblid
																		 ,ti.periodnum
																		 ,ti.periodnum_inday
																		 ,ti.datestart
																	FROM tweets_indexed ti 
																   WHERE ti.timestart BETWEEN '10:00:00' AND '10:10:00' 
																  -- AND smblid IN ('AAPL','ADBE')
                                                                     ) t
																  ,tweets_indexed ti2 
															WHERE t.smblid = ti2.smblid
															  AND t.datestart = ti2.datestart
                                                              AND t.datestart NOT IN (SELECT distinct earnrelease_date FROM earnrelmatched WHERE ticker = t.smblid)
                                                              AND t.datestart NOT IN (SELECT DISTINCT datestart FROM twitter_peaks WHERE smblid = t.smblid)
															  AND ti2.periodnum BETWEEN t.periodnum AND (t.periodnum+3)
															  AND ti2.periodnum_inday BETWEEN t.periodnum_inday AND (t.periodnum_inday+3)
														 GROUP BY ti2.smblid, ti2.datestart) t,
												(SELECT ti2.smblid, ti2.datestart, 
												(max(ti2.volumeend)-min(ti2.volumestart)) 'volchange' FROM (SELECT ti.smblid
																		 ,ti.periodnum
																		 ,ti.periodnum_inday
																		 ,ti.datestart
																	FROM tweets_indexed ti 
																   WHERE ti.timestart BETWEEN '12:00:00' AND '12:10:00' 
																     -- AND smblid IN ('AAPL','ADBE')
                                                                     ) t
																  ,tweets_indexed ti2 
															WHERE t.smblid = ti2.smblid
															  AND t.datestart = ti2.datestart
                                                              AND t.datestart NOT IN (SELECT distinct earnrelease_date FROM earnrelmatched WHERE ticker = t.smblid)
                                                              AND t.datestart NOT IN (SELECT DISTINCT datestart FROM twitter_peaks WHERE smblid = t.smblid)
															  AND ti2.periodnum BETWEEN t.periodnum AND (t.periodnum+3)
															  AND ti2.periodnum_inday BETWEEN t.periodnum_inday AND (t.periodnum_inday+3)
														 GROUP BY ti2.smblid, ti2.datestart) u,
                                                         (SELECT ti2.smblid, ti2.datestart, 
												(max(ti2.volumeend)-min(ti2.volumestart)) 'volchange' FROM (SELECT ti.smblid
																		 ,ti.periodnum
																		 ,ti.periodnum_inday
																		 ,ti.datestart
																	FROM tweets_indexed ti 
																   WHERE ti.timestart BETWEEN '14:00:00' AND '14:10:00' 
																     -- AND smblid IN ('AAPL','ADBE')
                                                                     ) t
																  ,tweets_indexed ti2 
															WHERE t.smblid = ti2.smblid
															  AND t.datestart = ti2.datestart
                                                              AND t.datestart NOT IN (SELECT distinct earnrelease_date FROM earnrelmatched WHERE ticker = t.smblid)
                                                              AND t.datestart NOT IN (SELECT DISTINCT datestart FROM twitter_peaks WHERE smblid = t.smblid)
															  AND ti2.periodnum BETWEEN t.periodnum AND (t.periodnum+3)
															  AND ti2.periodnum_inday BETWEEN t.periodnum_inday AND (t.periodnum_inday+3)
														 GROUP BY ti2.smblid, ti2.datestart) v
                                                         WHERE t.smblid = u.smblid
                                                           AND u.smblid = v.smblid
                                                         GROUP BY t.smblid;