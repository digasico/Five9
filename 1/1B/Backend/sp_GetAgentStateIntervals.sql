USE test1;
GO

CREATE OR ALTER PROCEDURE GetAgentStateIntervals
    @AgentId BIGINT = NULL,
    @DomainId BIGINT = NULL,
    @StartDate DATETIME = NULL,
    @EndDate DATETIME = NULL,
    @State NVARCHAR(100) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 50,
    @SortColumn NVARCHAR(50) = 'interval',
    @SortDirection NVARCHAR(4) = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Use default values if parameters are NULL
    SET @PageNumber = ISNULL(@PageNumber, 1);
    SET @PageSize = ISNULL(@PageSize, 50);
    SET @SortColumn = ISNULL(@SortColumn, 'interval');
    SET @SortDirection = ISNULL(@SortDirection, 'ASC');

    -- Validate pagination parameters;
    IF @PageSize < 1 SET @PageSize = 50;

    -- Validate sort direction
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'ASC';

    -- Dynamic SQL for flexible sorting
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @SafeSortColumn NVARCHAR(50);

    -- Prevent SQL injection by validating sort column
    SET @SafeSortColumn = CASE 
        WHEN @SortColumn IN ('agent_id', 'domain_id', 'interval', 'state', 'agent_state_time', 'db_updated_datetime', 'db_created_datetime')
        THEN @SortColumn
        ELSE 'interval'
    END;

    SET @SQL = '
    SELECT 
        agent_id,
        domain_id,
        interval,
        state,
        agent_state_time,
        db_updated_datetime,
        db_created_datetime
    FROM agent_state_interval
    WHERE 1 = 1'
    + CASE WHEN @AgentId IS NOT NULL THEN ' AND agent_id = @AgentId' ELSE '' END
    + CASE WHEN @DomainId IS NOT NULL THEN ' AND domain_id = @DomainId' ELSE '' END
    + CASE WHEN @StartDate IS NOT NULL THEN ' AND interval >= @StartDate' ELSE '' END
    + CASE WHEN @EndDate IS NOT NULL THEN ' AND interval <= @EndDate' ELSE '' END
    + CASE WHEN @State IS NOT NULL THEN ' AND state in (SELECT value FROM STRING_SPLIT(@State, '',''))' ELSE '' END
    + '
    ORDER BY ' + @SafeSortColumn + ' ' + @SortDirection 
    + CASE WHEN @PageNumber > 0 THEN 
        ' OFFSET (@PageNumber - 1) * @PageSize ROWS
          FETCH NEXT @PageSize ROWS ONLY;'
      ELSE ';'
      END;

    -- Execute the dynamic SQL
    EXEC sp_executesql @SQL,
        N'@AgentId BIGINT, @DomainId BIGINT, @StartDate DATETIME, @EndDate DATETIME, @State NVARCHAR(100), @PageNumber INT, @PageSize INT',
        @AgentId, @DomainId, @StartDate, @EndDate, @State, @PageNumber, @PageSize;
END;
GO