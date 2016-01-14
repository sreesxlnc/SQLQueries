/********************************* IDS 521 ********************************
**********************   Sreekanth Chinthagunta  ********************
**************************************************************************/
	
DROP DATABASE IF EXISTS `Enrollments`;

CREATE DATABASE `Enrollments`;

USE `Enrollments`;

CREATE TABLE `Student` (
    `sno` INT,
    `sName` VARCHAR(10),
    PRIMARY KEY (`sno`),
    `age` SMALLINT
);

CREATE TABLE `Course` (
    `cno` VARCHAR(5),
    `title` VARCHAR(10),
    PRIMARY KEY (`cno`),
    `credits` SMALLINT
);

CREATE TABLE `Professor` (
    `lname` VARCHAR(10),
    `dept` VARCHAR(10),
    `salary` SMALLINT,
    `age` SMALLINT,
    PRIMARY KEY (`lname`)
);

CREATE TABLE `Enroll` (
    `sno` INT,
    `cno` VARCHAR(5),
    PRIMARY KEY (`cno`, `sno`),
    FOREIGN KEY (sno) REFERENCES Student(sno),
    FOREIGN KEY (cno) REFERENCES Course(cno)
);

CREATE TABLE `Teach` (
    `lname` VARCHAR(10),
    `cno` VARCHAR(5),
    PRIMARY KEY (`cno`, `lname`),
    FOREIGN KEY (lname) REFERENCES Professor(lname),
    FOREIGN KEY (cno) REFERENCES Course(cno)
);

insert into student values(1, 'AARON',20);
insert into student values(2, 'CHUCK',21);
insert into student values(3, 'DOUG',20);
insert into student values(4, 'MAGGIE',19);
insert into student values(5, 'STEVE',22); 

insert into student values(6, 'JING',18); 
insert into student values(7, 'BRIAN',21); 
insert into student values(8, 'KAY',20); 
insert into student values(9, 'GILLIAN',20); 
insert into student values(10, 'CHAD',21); 

insert into course values('CS112', 'PHYSICS',4); 
insert into course values('CS113', 'CALCULUS',4); 
insert into course values('CS114', 'HISTORY',4); 

insert into professor values('CHOI', 'SCIENCE',400,45); 
insert into professor values('GUNN', 'HISTORY',300,60); 
insert into professor values('MAYER', 'MATH',400,55); 
insert into professor values('POMEL', 'SCIENCE',500,65); 
insert into professor values('FEUER', 'MATH',400,40); 

insert into enroll values(1,'CS112');
insert into enroll values(1,'CS113');
insert into enroll values(1,'CS114');
insert into enroll values(2,'CS112');
insert into enroll values(3,'CS112');
insert into enroll values(3,'CS114');
insert into enroll values(4,'CS112');
insert into enroll values(4,'CS113');

insert into enroll values(5,'CS113');
insert into enroll values(6,'CS113');
insert into enroll values(6,'CS114');

insert into teach values('CHOI','CS112');
insert into teach values('CHOI','CS113');
insert into teach values('CHOI','CS114');
insert into teach values('POMEL','CS113');
insert into teach values('MAYER','CS112');
insert into teach values('MAYER','CS114');

/****************************** Homework 1 Solution ****************************************/
-- (a) Students who take at least two courses, excluding students who take all courses 
SELECT * FROM student s1
		 WHERE s1.sno IN (SELECT e1.sno FROM enroll e1, enroll e2 
									    WHERE e1.sno = e2.sno
                                         AND e1.cno != e2.cno) 
		   AND s1.sno NOT IN (SELECT e1.sno FROM enroll e1, enroll e2, enroll e3 
											WHERE e1.sno = e2.sno
                                              AND e2.sno = e3.sno 
                                              AND e1.cno != e2.cno 
                                              AND e2.cno != e3.cno 
                                              AND e3.cno != e1.cno);

-- (b) The youngest student(s) who takes more than one course
SELECT distinct s1.* FROM student s1, student s2
		WHERE s1.sno IN (SELECT DISTINCT e1.sno FROM enroll e1, enroll e2 
									    WHERE e1.sno = e2.sno
                                         AND e1.cno != e2.cno) 
		AND s1.sno NOT IN (SELECT s2.sno FROM student s2, student s3 WHERE s2.age > s3.age);
 
 
-- (c) Professors who teach exactly two courses
SELECT p.* FROM professor p WHERE p.lname IN (SELECT t1.lname FROM teach t1, teach t2 
														   WHERE t1.lname = t2.lname 
                                                             AND t1.cno != t2.cno)
							AND p.lname NOT IN (SELECT t1.lname FROM teach t1, teach t2, teach t3 
																WHERE t1.lname = t2.lname
                                                                  AND t2.lname = t3.lname 
                                                                  AND t3.lname = t1.lname 
                                                                  AND t1.cno != t2.cno 
                                                                  AND t2.cno != t3.cno
                                                                  AND t3.cno != t1.cno);

-- (d) Professors who teach all courses 								
SELECT p.* FROM professor p WHERE p.lname IN (SELECT t1.lname FROM teach t1, teach t2, teach t3 
																WHERE t1.lname = t2.lname
                                                                  AND t2.lname = t3.lname 
                                                                  AND t3.lname = t1.lname 
                                                                  AND t1.cno != t2.cno 
                                                                  AND t2.cno != t3.cno
                                                                  AND t3.cno != t1.cno);
-- (e) Courses taught by two or more professors
SELECT c.* FROM course c WHERE c.cno IN (SELECT t1.cno FROM teach t1, teach t2 
													WHERE t1.lname = t2.lname 
														AND t1.cno != t2.cno);
                                                                                 
-- (f) The 2nd highest paid professor
SELECT p1.lname FROM professor p1 WHERE p1.lname NOT IN (SELECT p2.lname FROM (SELECT DISTINCT p4.lname,p4.salary FROM professor p4, professor p5
																												 WHERE p4.salary < p5.salary) p2, 
																			  (SELECT DISTINCT p6.lname, p6.salary FROM professor p6, professor p7
																											       WHERE p6.salary < p7.salary) p3 
																		WHERE p2.salary < p3.salary) 
									AND p1.lname IN (SELECT p2.lname FROM professor p2, professor p3
																	 WHERE p2.salary < p3.salary);