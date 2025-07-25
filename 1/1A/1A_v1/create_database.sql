-- Check if the test database exists
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'test')
BEGIN
    PRINT 'Creating test database...';
    CREATE DATABASE test;
END;