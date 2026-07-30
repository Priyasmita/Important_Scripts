SELECT
    s.name AS schema_name,
    t.name AS table_name,
    SUM(CASE WHEN ps.index_id IN (0,1) THEN ps.row_count ELSE 0 END) AS [rows],
    CAST(SUM(ps.reserved_page_count) * 8 / 1024.0 AS DECIMAL(18,2)) AS reserved_mb,
    CAST(SUM(ps.used_page_count)     * 8 / 1024.0 AS DECIMAL(18,2)) AS used_mb,
    CAST(SUM(CASE WHEN ps.index_id IN (0,1)
                  THEN ps.in_row_data_page_count
                     + ps.lob_used_page_count
                     + ps.row_overflow_used_page_count
                  ELSE 0 END) * 8 / 1024.0 AS DECIMAL(18,2)) AS data_mb
FROM sys.dm_db_partition_stats AS ps
JOIN sys.tables  AS t ON ps.object_id = t.object_id
JOIN sys.schemas AS s ON t.schema_id  = s.schema_id
WHERE t.is_ms_shipped = 0
GROUP BY s.name, t.name
ORDER BY reserved_mb DESC;
