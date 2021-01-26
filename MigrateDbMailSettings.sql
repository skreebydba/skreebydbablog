USE msdb;
GO
 
/*
    Author -        Frank Gill, Concurrency
    Date -          2017-08-18
    Description -   Script queries sys tables to generate dynamic SQL statements
                    to recreate database mail accounts and profiles
                    Code modified to generate multiple mail profiles from the script found here:
                    https://basetable.wordpress.com/2012/04/03/script-out-database-mail-settings/
    Note -          Execute query in SQL Server Management Studio and output Results to Text (Ctrl + T)
                    Copy the results to a separate query window 
                    For mail acounts with passwords, the password will appear as 'NotTheRealPassword'
                    You will need to change this to the real password
                    Each result set will contain a header row of Text
                    Do a group replace (Ctrl + H) of Text to --Text to comment the headers out
                     
*/
 
SET NOCOUNT ON;
 
/* Drop and create temp table 
   Declare local variables */
IF OBJECT_ID('tempdb.dbo.#sysmail_info') IS NOT NULL
BEGIN
 
    DROP TABLE #sysmail_info;
 
END
 
CREATE TABLE #sysmail_info
(RowId INT IDENTITY(1,1)
,account_name SYSNAME
,email_address NVARCHAR(120)
,display_name NVARCHAR(128)
,replyto_address NVARCHAR(128)
,[description] NVARCHAR(256)
,servername SYSNAME
,servertype SYSNAME
,[port] INT
,credential_identity NVARCHAR(4000)
,use_default_credentials BIT
,enable_ssl BIT
,profile_name SYSNAME
,sequence_number INT
,database_principal_name SYSNAME NULL
,is_default BIT);
 
DECLARE @loopcount INT = 1,
@looplimit INT,
@SQLText VARCHAR(MAX),
@ProfileText VARCHAR(MAX),
@CrLf CHAR(2) = CHAR(13) + CHAR(10);
 
/* Insert the required database mail info into the temp table */
INSERT INTO #sysmail_info
(account_name
,email_address
,display_name
,replyto_address
,[description]
,servername
,servertype
,[port]
,credential_identity
,use_default_credentials
,enable_ssl
,profile_name
,sequence_number
,database_principal_name
,is_default)
SELECT a.name AS account_name,
a.email_address,
a.display_name,
a.replyto_address,
a.[description],
servername,
servertype,
[port],
c.credential_identity,
s.use_default_credentials,
s.enable_ssl,
p.name AS profile_name,
pa.sequence_number,
dp.name AS database_principal_name,
pp.is_default
FROM msdb.dbo.sysmail_profile AS p
INNER JOIN msdb.dbo.sysmail_profileaccount AS pa ON
  p.profile_id = pa.profile_id
INNER JOIN msdb.dbo.sysmail_account AS a ON
  pa.account_id = a.account_id
LEFT OUTER JOIN msdb.dbo.sysmail_principalprofile AS pp ON
  p.profile_id = pp.profile_id
LEFT OUTER JOIN msdb.sys.database_principals AS dp ON
  pp.principal_sid = dp.sid
LEFT OUTER JOIN msdb.dbo.sysmail_server AS s ON
  a.account_id = s.account_id
LEFT OUTER JOIN sys.credentials AS c ON
  s.credential_id = c.credential_id;
 
/* Set loop limit to max RowId value */
SELECT @looplimit = MAX(RowId) FROM #sysmail_info;
 
/* Generate commands to enable database mail */
SELECT @SQLText = '
EXEC msdb.dbo.sp_configure
    @configname = ''show advanced options'',
    @configvalue = 1;
RECONFIGURE;
 
EXEC msdb.dbo.sp_configure
    @configname = ''Database Mail XPs'',
    @configvalue = 1;
RECONFIGURE;';
 
SELECT @SQLText AS [Text];
 
/* Loop through each row in the temp table 
   build commands to recreate database mail accounts and profiles */
WHILE @loopcount <= @looplimit
BEGIN
 
    SELECT @SQLText = '
 
    EXECUTE msdb.dbo.sysmail_add_profile_sp
      @profile_name = ''' + profile_name + ''',
      @description  = ''' + ISNULL([description],'') + ''';
 
    EXEC msdb.dbo.sysmail_add_account_sp
      @account_name = ' + CASE WHEN account_name IS NULL THEN 'NULL' ELSE + '''' + account_name + '''' END + ',
      @email_address = ' + CASE WHEN email_address IS NULL THEN 'NULL' ELSE + '''' + email_address + '''' END + ',
      @display_name = ' + CASE WHEN display_name IS NULL THEN 'NULL' ELSE + '''' + display_name + '''' END + ',
      @replyto_address = ' + CASE WHEN replyto_address IS NULL THEN 'NULL' ELSE + '''' + replyto_address + '''' END + ',
      @description = ' + CASE WHEN [description] IS NULL THEN 'NULL' ELSE + '''' + [description] + '''' END + ',
      @mailserver_name = ' + CASE WHEN servername IS NULL THEN 'NULL' ELSE + '''' + servername + '''' END + ',
      @mailserver_type = ' + CASE WHEN servertype IS NULL THEN 'NULL' ELSE + '''' + servertype + '''' END + ',
      @port = ' + CASE WHEN [port] IS NULL THEN 'NULL' ELSE + '''' + CONVERT(VARCHAR,[port]) + '''' END + ',
      @username = ' + CASE WHEN credential_identity IS NULL THEN 'NULL' ELSE + '''' + credential_identity   + '''' END + ',
      @password = ' + CASE WHEN credential_identity IS NULL THEN 'NULL' ELSE + '''NotTheRealPassword''' END + ',
      @use_default_credentials = ' + CASE WHEN use_default_credentials = 1 THEN '1' ELSE '0' END + ',
      @enable_ssl = ' + CASE WHEN enable_ssl = 1 THEN '1' ELSE '0' END + ';
 
    EXEC msdb.dbo.sysmail_add_profileaccount_sp
      @profile_name = ''' + profile_name + ''',
      @account_name = ''' + account_name + ''',
      @sequence_number = ' + CAST(sequence_number AS NVARCHAR(3)) + ';
    ' +
      COALESCE('
    EXEC msdb.dbo.sysmail_add_principalprofile_sp
      @profile_name = ''' + profile_name + ''',
      @principal_name = ''' + database_principal_name + ''',
      @is_default = ' + CAST(is_default AS NVARCHAR(1)) + ';
    ', '')
    FROM #sysmail_info
    WHERE RowId = @loopcount;
 
    WITH R2(N) AS (SELECT 1 UNION ALL SELECT 1),
    R4(N) AS (SELECT 1 FROM R2 AS a CROSS JOIN R2 AS b),
    R8(N) AS (SELECT 1 FROM R4 AS a CROSS JOIN R4 AS b),
    R16(N) AS (SELECT 1 FROM R8 AS a CROSS JOIN R8 AS b),
    R32(N) AS (SELECT 1 FROM R16 AS a CROSS JOIN R16 AS b),
    R64(N) AS (SELECT 1 FROM R32 AS a CROSS JOIN R32 AS b),
    R128(N) AS (SELECT 1 FROM R64 AS a CROSS JOIN R64 AS b),
    Tally(N) AS (
      SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
      FROM R128
    ),
    SplitText(SplitIndex, [Text]) AS (
      SELECT
        N,
        SUBSTRING(
          @CrLf + @SQLText + @CrLf,
          N + DATALENGTH(@CrLf),
          CHARINDEX(
            @CrLf,
            @CrLf + @SQLText + @CrLf,
            N + DATALENGTH(@CrLf)
          ) - N - DATALENGTH(@CrLf)
        )
      FROM Tally
      WHERE
        N < DATALENGTH(@CrLf + @SQLText) AND
        SUBSTRING(@CrLf + @SQLText + @CrLf, N, DATALENGTH(@CrLf)) = @CrLf
    )
    SELECT [Text]
    FROM SplitText
    ORDER BY SplitIndex;
 
    SELECT @loopcount += 1;
 
END