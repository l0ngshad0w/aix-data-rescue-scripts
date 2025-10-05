-- membr
IF OBJECT_ID('stage.membr_raw','U') IS NOT NULL DROP TABLE stage.membr_raw;
CREATE TABLE stage.membr_raw
(
	member_no NVARCHAR(200) NULL
	,zip_code NVARCHAR(200) NULL
	,zip_ext NVARCHAR(200) NULL
	,last_name NVARCHAR(400) NULL
	,first_name NVARCHAR(400) NULL
	,middle_name NVARCHAR(400) NULL
	,[address] NVARCHAR(400) NULL
	,city_state NVARCHAR(400) NULL
	,same_adr NVARCHAR(200) NULL
	,congr_num NVARCHAR(200) NULL
	,ordin_date NVARCHAR(200) NULL
	,subscr_date NVARCHAR(200) NULL
	,congr_num2 NVARCHAR(200) NULL
	,area_code NVARCHAR(200) NULL
	,phone_no NVARCHAR(200) NULL
	,email_adr NVARCHAR(400) NULL
);
GO

-- corti
IF OBJECT_ID('stage.corti_raw','U') IS NOT NULL DROP TABLE stage.corti_raw;
CREATE TABLE stage.corti_raw(
    a_type   NVARCHAR(50)  NULL,
    a_number NVARCHAR(200) NULL,
    desc1    NVARCHAR(400) NULL,
    desc2    NVARCHAR(400) NULL,
    desc3    NVARCHAR(400) NULL
);
GO

-- ctxrf
IF OBJECT_ID('stage.ctxrf_raw','U') IS NOT NULL DROP TABLE stage.ctxrf_raw;
CREATE TABLE stage.ctxrf_raw(
    member_no NVARCHAR(200) NULL,
    a_type    NVARCHAR(50)  NULL,
    a_number  NVARCHAR(200) NULL,
    a_date    NVARCHAR(200) NULL
);
