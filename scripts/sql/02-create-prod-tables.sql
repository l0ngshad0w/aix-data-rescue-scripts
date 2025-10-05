DROP TABLE dbo.membr
DROP TABLE dbo.coursetitle
DROP TABLE dbo.ct_membr_xrf
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dbo.membr')
BEGIN
	CREATE TABLE dbo.membr
	(
		member_pk_id INT IDENTITY (1,1)
		,member_no INT NOT NULL
		,zip_code INT NULL
		,zip_ext SMALLINT NULL
		,last_name VARCHAR(40) NULL
		,first_name VARCHAR(40) NULL
		,middle_name VARCHAR(40) NULL
		,address1 VARCHAR(100) NULL
		,address2 VARCHAR (80) NULL
		,city VARCHAR (60) NULL
		,[state] VARCHAR (10) NULL
		,foreign_address VARCHAR(120) NULL
		,same_adr SMALLINT NULL
		,congr_num INT NULL
		,ordin_date DATE NULL
		,subscr_date DATE NULL
		,congr_num2 INT NULL
		,area_code VARCHAR(10) NULL
		,phone_no VARCHAR(20) NULL
		,email_adr VARCHAR(120) NULL
		,last_modified_dttm DATETIME NOT NULL DEFAULT(GETDATE())
		CONSTRAINT PK_membr_pk_id PRIMARY KEY CLUSTERED (member_pk_id)
	);

-- Suggested nonclustered indexes (from observed usage and 4GL hints)
CREATE INDEX IX_membr_last_name ON dbo.membr(last_name);
CREATE INDEX IX_membr_zip ON dbo.membr(zip_code);
CREATE INDEX IX_membr_zip_last ON dbo.membr(zip_code, last_name);

END
GO


IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dbo.coursetitle')
BEGIN
    CREATE TABLE dbo.coursetitle (
        ct_type   CHAR(1)     NOT NULL,
        ct_number SMALLINT    NOT NULL,
        desc1    VARCHAR(100) NULL,
        desc2    VARCHAR(50) NULL
    );
--  There are duplicate Type and Number combinations so can't use a PK here.
CREATE INDEX IX_type_number ON dbo.coursetitle(ct_type, ct_number);

END
GO



IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dbo.ct_membr_xrf')
BEGIN
    CREATE TABLE dbo.ct_membr_xrf (
        member_no INT      NOT NULL,
        ct_type    CHAR(1)  NOT NULL,
        ct_number  SMALLINT NOT NULL,
        assigned_date    DATE     NULL
    );
	CREATE INDEX IX_ctxrf_member ON dbo.ct_membr_xrf (member_no);
END
GO
