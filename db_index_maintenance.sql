IF OBJECT_ID (N'dbo.fGetIndexFragmentation', N'IF') IS NOT NULL
    DROP FUNCTION fGetIndexFragmentation;
GO
CREATE FUNCTION dbo.fGetIndexFragmentation()
RETURNS TABLE
AS
RETURN
(
	SELECT S.name as 'Schema',
	T.name as 'Table',
	I.name as 'Index',
	DDIPS.avg_fragmentation_in_percent as 'Fragmentation',
	DDIPS.page_count as 'PageCount'
	FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS DDIPS
	INNER JOIN sys.tables T on T.object_id = DDIPS.object_id
	INNER JOIN sys.schemas S on T.schema_id = S.schema_id
	INNER JOIN sys.indexes I ON I.object_id = DDIPS.object_id
	AND DDIPS.index_id = I.index_id
	WHERE DDIPS.database_id = DB_ID()
	and I.name is not null
	AND DDIPS.avg_fragmentation_in_percent > 0
	ORDER BY DDIPS.avg_fragmentation_in_percent desc OFFSET 0 ROWS
)
GO
DECLARE @Index nvarchar(MAX) = null
DECLARE @Schema nvarchar(MAX) = null
DECLARE @Table nvarchar(MAX) = null
WHILE((select count(1) FROM fGetIndexFragmentation() WHERE [Fragmentation] > 40 and [PageCount] > 100) > 0)
BEGIN
	SELECT TOP(1) @Index = [Index], @Schema = [Schema], @Table = [Table] FROM fGetIndexFragmentation() WHERE [Fragmentation] > 40 and [PageCount] > 100
	DECLARE @REBUILDCOMMAND nvarchar(MAX) = 'ALTER INDEX ' + QUOTENAME(@Index) + ' ON ' + '['+@Schema+'].['+@Table+']' + ' REBUILD'
	EXECUTE sp_executesql @REBUILDCOMMAND
END
WHILE((select count(1) FROM fGetIndexFragmentation() WHERE Fragmentation > 30 and PageCount > 100) > 0)
BEGIN
	SELECT TOP(1) @Index = [Index], @Schema = [Schema], @Table = [Table] FROM fGetIndexFragmentation() WHERE [Fragmentation] > 30 and [PageCount] > 100
	DECLARE @REORGANIZECOMMAND nvarchar(MAX) = 'ALTER INDEX ' + QUOTENAME(@Index) + ' ON ' + '['+@Schema+'].['+@Table+']' + ' REORGANIZE'
	EXECUTE sp_executesql @REORGANIZECOMMAND
END
GO