USE master;
/* Get transfer rate and estimated completion time for Availability Group automatic seeding */
SELECT local_database_name,
internal_state_desc,
remote_machine_name,
database_size_bytes / 1045876 AS [Database Size (mb)],
transferred_size_bytes / 1045876 AS [Transferred Size (mb)],
transfer_rate_bytes_per_second / 1045876 AS [Transfer Rate/Sec (mb)],
(database_size_bytes - transferred_size_bytes) / transfer_rate_bytes_per_second AS [Time Remaining (sec)],
CASE
WHEN ((database_size_bytes - transferred_size_bytes) / transfer_rate_bytes_per_second) < 360000
THEN '0'
ELSE ''
END
+ RTRIM(((database_size_bytes - transferred_size_bytes) / transfer_rate_bytes_per_second) / 3600)
+ ':' + RIGHT('0' + RTRIM(((database_size_bytes - transferred_size_bytes) / transfer_rate_bytes_per_second) % 3600 / 60), 2)
+ ':' + RIGHT('0' + RTRIM(((database_size_bytes - transferred_size_bytes) / transfer_rate_bytes_per_second) % 60), 2) AS [Time Remaining]
FROM sys.dm_hadr_physical_seeding_stats
WHERE internal_state_desc = 'ReadingAndSendingData'
ORDER BY remote_machine_name;