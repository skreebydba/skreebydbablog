USE msdb;
 
SET NOCOUNT ON;
 
/* Drop and create temp table
   and declare local variables */
DROP TABLE IF EXISTS #profiles;
 
CREATE TABLE #profiles
(RowId INT IDENTITY(1,1)
,ProfileName SYSNAME);
 
/* Update @recipient 
   Set @noexec = 1 to print the EXEC sp_send_dbmail statements
   Set @noexec = 0 to execute the statements immediately */
DECLARE @profilename SYSNAME,
@sqlstr NVARCHAR(2000),
@loopcount INT = 1,
@looplimit INT,
@noexec INT = 1,
@recipient NVARCHAR(255) = N'fgill@concurrency.com';
 
/* Insert Database Mail profile names into temp table
   and initialize the loop limit variable */
INSERT INTO #profiles
(ProfileName)
SELECT name
FROM sysmail_profile;
 
SELECT @looplimit = MAX(RowId) FROM #profiles;
 
/* Loop through the list of Database Mail profiles and 
   execute sp_send_dbmail for each one */
WHILE @loopcount <= @looplimit
BEGIN
 
    SELECT @profilename = ProfileName FROM #profiles WHERE RowId = @loopcount;
 
 
    SELECT @sqlstr = CONCAT('EXEC msdb.dbo.sp_send_dbmail  
        @profile_name = ''',
    @profilename,''',  
        @recipients = ''', @recipient, ''',  
        @body = ''Database mail succeeded for ', @profilename, ' on SQLWEBDB-01.'',  
        @subject = ''Database mail test for ', @profilename, ';''');
 
    SELECT @loopcount += 1;
 
    IF @noexec = 1
    BEGIN
 
        PRINT @sqlstr;
 
    END
    ELSE
    BEGIN
 
        EXEC sp_executesql @sqlstr;
 
    END
         
END