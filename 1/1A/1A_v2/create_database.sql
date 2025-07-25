-- Check if the test database exists
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'test1')
BEGIN
    PRINT 'Creating test database...';
    CREATE DATABASE test1;
END;
