USE [master]
GO
  
--Drop procedure if it exists
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_join_whoisactive_execrequests]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].sp_join_whoisactive_execrequests
GO
  
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* =============================================
-- Author:      Frank Gill
-- Create date: 2015-10-27
-- Description: This procedure executes Adam Machanic's sp_whoisactive, dumps the results to a temp table, and then joins those results to 
-- sys.dm_exec_requests.  This will return estimated completion time for the following commands along with the statement being executed
-- in a single pass:
-- ALTER INDEX REORGANIZE
-- AUTO_SHRINK option with ALTER DATABASE
-- BACKUP DATABASE
-- DBCC CHECKDB
-- DBCC CHECKFILEGROUP
-- DBCC CHECKTABLE
-- DBCC INDEXDEFRAG
-- DBCC SHRINKDATABASE
-- DBCC SHRINKFILE
-- RECOVERY
-- RESTORE DATABASE,
-- ROLLBACK
-- TDE ENCRYPTION
-- ============================================= */
CREATE PROCEDURE sp_join_whoisactive_execrequests
AS
BEGIN
  
    IF OBJECT_ID('tempdb..#WhoIsActive') IS NOT NULL 
    BEGIN
        SELECT 'Dropping'
        DROP TABLE #WhoIsActive
    END
  
    CREATE TABLE #WhoIsActive
    ([dd hh:mm:ss.mss] VARCHAR(20)
    ,[dd hh:mm:ss.mss (avg)] VARCHAR(20)
    ,[session_id] SMALLINT
    ,[sql_text] XML
    ,[sql_command] XML
    ,[login_name] SYSNAME
    ,[wait_info] NVARCHAR(4000)
    ,[tran_log_writes] NVARCHAR(4000)
    ,[CPU] VARCHAR(30)
    ,[tempdb_allocations] VARCHAR(30)
    ,[tempdb_current] VARCHAR(30)
    ,[blocking_session_id] SMALLINT
    ,[blocked_session_count] VARCHAR(30)
    ,[reads] VARCHAR(30)
    ,[writes] VARCHAR(30)
    ,[physical_reads] VARCHAR(30)
    ,[query_plan] XML
    ,[used_memory] VARCHAR(30)
    ,[status] VARCHAR(30)
    ,[tran_start_time] DATETIME
    ,[open_tran_count] VARCHAR(30)
    ,[percent_complete] VARCHAR(30)
    ,[host_name] SYSNAME
    ,[database_name] SYSNAME
    ,[program_name] SYSNAME
    ,[start_time] DATETIME
    ,[login_time] DATETIME
    ,[request_id] INT
    ,[collection_time] DATETIME)
 
    /* Execute sp_whoisactive and write the result set to the temp table created above */
    EXEC master.dbo.sp_WhoIsActive
    @get_plans = 2, 
    @get_outer_command = 1, 
    @get_transaction_info = 1, 
    @get_avg_time = 1, 
    @find_block_leaders = 1,
    @destination_table = #WhoIsActive
 
    /* Join the #whoisactive temp table to sys.dm_exec_requests to get estimated completion time and query information in one pass */ 
    SELECT CASE WHEN ((r.estimated_completion_time/1000)/3600) < 10 THEN '0' +
    CONVERT(VARCHAR(10),(r.estimated_completion_time/1000)/3600) 
    ELSE CONVERT(VARCHAR(10),(r.estimated_completion_time/1000)/3600)
    END  + ':' +
	CASE WHEN ((r.estimated_completion_time/1000)%3600/60) < 10 THEN '0' +
    CONVERT(VARCHAR(10),(r.estimated_completion_time/1000)%3600/60) 
    ELSE CONVERT(VARCHAR(10),(r.estimated_completion_time/1000)%3600/60)
    END  + ':' + 
    CASE WHEN ((r.estimated_completion_time/1000)%60) < 10 THEN '0' +
    CONVERT(VARCHAR(10),(r.estimated_completion_time/1000)%60)
    ELSE CONVERT(VARCHAR(10),(r.estimated_completion_time/1000)%60)
    END
    AS [Time Remaining],
    r.percent_complete,
    r.session_id,
    w.login_name,
    w.[host_name],
    w.sql_command,
    w.sql_text 
    FROM #WhoIsActive w
    RIGHT OUTER JOIN sys.dm_exec_requests r
    ON r.session_id = w.session_id
    WHERE r.percent_complete > 0;
  
END