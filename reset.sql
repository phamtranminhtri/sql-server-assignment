-- Source - https://stackoverflow.com/a/7469167
-- Posted by unruledboy, modified by community. See post 'Timeline' for change history
-- Retrieved 2025-11-15, License - CC BY-SA 4.0
USE master;
GO

DECLARE @DatabaseName nvarchar(50)
SET @DatabaseName = N'MyDatabase'

DECLARE @SQL varchar(max)

SELECT @SQL = COALESCE(@SQL,'') + 'Kill ' + Convert(varchar, SPId) + ';'
FROM MASTER..SysProcesses
WHERE DBId = DB_ID(@DatabaseName) AND SPId <> @@SPId

--SELECT @SQL 
EXEC(@SQL)

IF DB_ID(@DatabaseName) IS NOT NULL
BEGIN
    EXEC('DROP DATABASE ' + @DatabaseName);
END
GO