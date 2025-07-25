CREATE PROCEDURE GetDataForDayInUserTimezone
    @InputDate DATE,            -- The specific date (e.g., '2025-07-19')
    @UserTimeZone NVARCHAR(128) -- e.g., 'Pacific Standard Time'
AS
BEGIN
    SET NOCOUNT ON;

    -- Check for null InputDate
    IF @InputDate IS NULL
    BEGIN
        RAISERROR ('InputDate cannot be null.', 16, 1);
        RETURN;
    END;

    -- Check for null UserTimeZone
    IF @UserTimeZone IS NULL
    BEGIN
        RAISERROR ('UserTimeZone cannot be null.', 16, 1);
        RETURN;
    END;

    -- Validate timezone exists in sys.time_zone_info
    IF NOT EXISTS (
        SELECT 1 
        FROM sys.time_zone_info 
        WHERE name = @UserTimeZone
    )
    BEGIN
        RAISERROR ('Invalid UserTimeZone provided.', 16, 1);
        RETURN;
    END;

    -- Declare variables for the start and end of the specified day in the user's timezone
    DECLARE @StartOfDayUTC DATETIME2;
    DECLARE @EndOfDayUTC DATETIME2;

    -- Calculate the start of the specified day (midnight) in the user's timezone, converted to UTC
    SET @StartOfDayUTC = CONVERT(DATETIME2, @InputDate) 
        AT TIME ZONE @UserTimeZone 
        AT TIME ZONE 'UTC';

    -- Calculate the end of the specified day (23:59:59.999) in the user's timezone, converted to UTC
    SET @EndOfDayUTC = DATEADD(MILLISECOND, -1, 
        DATEADD(DAY, 1, CONVERT(DATETIME2, @InputDate)) 
        AT TIME ZONE @UserTimeZone 
        AT TIME ZONE 'UTC');

    -- Select rows where the interval falls within the specified day
    SELECT *
    FROM [table]
    WHERE [interval] >= @StartOfDayUTC 
    AND [interval] <= @EndOfDayUTC;
END;
GO