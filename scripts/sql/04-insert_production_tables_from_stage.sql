/** 
There was an issue in testing with two records having the same member_no.
Don't expect it on cutover but have Dad fix it before running then remove 
	the where clause in the member load.

Also, duplicate Course/Title & Number combinations prevented the use of
a PK between them.  Not much to do there, just be aware.
**/

SET DATEFORMAT mdy;

-- Separate the City and State for US Zips
WITH SplitCityState AS (
    SELECT
        m.member_no,
        m.city_state,
        s.value AS Tag,
        ROW_NUMBER() OVER (PARTITION BY m.member_no ORDER BY (SELECT NULL)) AS TagOrdinal -- Assign an ordinal to each tag
    FROM
        stage.membr_raw AS m
    CROSS APPLY
        STRING_SPLIT(m.city_state, ',') AS s
	WHERE
		m.zip_code <> -1
)


INSERT INTO dbo.membr (
	member_no
	,zip_code
	,zip_ext
	,last_name
	,first_name
	,middle_name
	,address1
	,city
	,[state]
	,foreign_address
	,same_adr
	,congr_num
	,ordin_date
	,subscr_date
	,congr_num2
	,area_code
	,phone_no
	,email_adr
)
SELECT
	CONVERT(INT, NULLIF(LTRIM(RTRIM(stg.member_no)), '')) AS member_no
	,CONVERT(INT, NULLIF(LTRIM(RTRIM(stg.zip_code)), '')) AS zip_code
	,CONVERT(SMALLINT, NULLIF(LTRIM(RTRIM(stg.zip_ext)), '')) AS zip_ext
	,NULLIF(LTRIM(RTRIM(stg.last_name)), '') AS last_name
	,NULLIF(LTRIM(RTRIM(stg.first_name)), '') AS first_name
	,NULLIF(LTRIM(RTRIM(stg.middle_name)), '') AS middle_name
	,NULLIF(LTRIM(RTRIM(stg.[address])), '') AS address1
	,pt.city AS city
	,CASE
		WHEN LEN(LTRIM(RTRIM(pt.[state]))) > 2 THEN NULL 
		ELSE pt.[state]		
		END AS [state]  -- If any state is greater than 2, send it to foreign.
	,CASE
		WHEN stg.zip_code = -1 THEN NULLIF(LTRIM(RTRIM(stg.city_state)), '')
		WHEN LEN(LTRIM(RTRIM(pt.[state]))) > 2 THEN pt.[state] 
		ELSE NULL
		END AS foreign_address
	,TRY_CONVERT(SMALLINT, NULLIF(LTRIM(RTRIM(stg.same_adr)), '')) AS same_adr
	,TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(stg.congr_num)), '')) AS congr_num
	,TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(stg.ordin_date)), '')) AS ordin_date
	,TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(stg.subscr_date)),'')) AS subscr_date
	,TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(stg.congr_num2)), '')) AS congr_num2
	,NULLIF(LTRIM(RTRIM(stg.area_code)), '') AS area_code
	,NULLIF(LTRIM(RTRIM(stg.phone_no)), '') AS phone_no
	,NULLIF(LTRIM(RTRIM(stg.email_adr)), '') AS email_adr
FROM
	stage.membr_raw stg
LEFT JOIN
	(SELECT
		member_no,
		[1] AS city,
		[2] AS [state]
	FROM
		SplitCityState
	PIVOT (
		MAX(Tag)
		FOR TagOrdinal IN ([1], [2]) -- Specify the columns to pivot on
	) AS PivotTable ) pt
ON
	stg.member_no = pt.member_no

GO

-- Courses & Titles
INSERT INTO dbo.coursetitle
	(
		ct_type
		,ct_number
		,desc1
	)
SELECT 
	a_type AS ct_type
	,CONVERT(SMALLINT,NULLIF(a_number,'')) AS ct_number
	,NULLIF(desc1,' ') + NULLIF(desc2, '') AS desc1
FROM 
	stage.corti_raw
WHERE 
	a_number IS NOT NULL


-- Members and Courses & Titles
SET DATEFORMAT mdy;

INSERT INTO dbo.ct_membr_xrf (
	member_no
	,ct_type
	,ct_number
	,assigned_date
)
SELECT
	CONVERT(INT, NULLIF(LTRIM(RTRIM(member_no)),'')) as member_no
	,SUBSTRING(ISNULL(a_type,''),1,1) as ct_type
	,CONVERT(SMALLINT, NULLIF(LTRIM(RTRIM(a_number)),'')) as ct_number
	,CONVERT(DATE, NULLIF(LTRIM(RTRIM(a_date)),'')) as assigned_date
FROM 
	stage.ctxrf_raw
GO
