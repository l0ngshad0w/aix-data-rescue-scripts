/* Bulk Insert each file into its respective raw table
	- Considered using variables but for the three files, didn't seem necessary
	- Last run successfully 10/4/25.
*/

--membr
BULK INSERT stage.membr_raw
FROM 'D:\\AIX-Exports\\membr__138.unl'
WITH
(
	DATAFILETYPE = 'char'
	,FIELDTERMINATOR = '|'
	,ROWTERMINATOR = '0x0A'
	,KEEPNULLS
	,TABLOCK
);
GO

-- Some -1 (foreign addresses) were entered as 1.  Normalizing.
UPDATE stage.membr_raw
SET zip_code = -1
WHERE zip_code = 1
GO

UPDATE stage.membr_raw
SET email_adr = REPLACE(NULLIF(LTRIM(RTRIM(stg.email_adr)), ''), '|', '')
GO


--ctrxf
BULK INSERT stage.ctxrf_raw
FROM 'D:\\AIX-Exports\\ctxrf__101.unl'
WITH
(
	DATAFILETYPE = 'char'
	,FIELDTERMINATOR = '|'
	,ROWTERMINATOR = '0x0A'
	,KEEPNULLS
	,TABLOCK
);
GO

--corti
BULK INSERT stage.corti_raw
FROM 'D:\\AIX-Exports\\corti__102.unl'
WITH
(
	DATAFILETYPE = 'char'
	,FIELDTERMINATOR = '|'
	,ROWTERMINATOR = '0x0A'
	,KEEPNULLS
	,TABLOCK
);
GO
