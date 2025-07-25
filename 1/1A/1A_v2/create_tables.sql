BEGIN TRY
	-- Verify database exists before switching
    IF EXISTS (SELECT * FROM sys.databases WHERE name = 'test1')
    BEGIN
        PRINT 'Switching to test database...';
        USE test1;
    END
    ELSE
    BEGIN
		PRINT 'Error: test database does not exist. Execution stopped.';
		RAISERROR ('Cannot proceed without test database.', 16, 1);
		RETURN;
    END;

    BEGIN TRANSACTION;
		-- Create dummy domain table if it doesn't exist
		IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'domain')
		BEGIN
			CREATE TABLE domain
			(
				domain_id BIGINT NOT NULL,
				CONSTRAINT PK_domain PRIMARY KEY (domain_id)
			);
		END;

		-- Create dummy agent table if it doesn't exist
		IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'agent')
		BEGIN
			CREATE TABLE agent
			(
				agent_id BIGINT NOT NULL,
				CONSTRAINT PK_agent PRIMARY KEY (agent_id)
			);
		END;

		---- Create domain_agent_states table if it doesn't exist
		--IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'domain_agent_states')
		--BEGIN
		--	CREATE TABLE domain_agent_states
		--	(
		--		domain_id BIGINT NOT NULL DEFAULT 1,
		--		state NVARCHAR(200) NOT NULL,
		--		db_date DATETIME NOT NULL DEFAULT GETUTCDATE(),
		--		CONSTRAINT PK_domain_agent_states PRIMARY KEY (domain_id,state,db_date),
		--		CONSTRAINT FK_domain_agent_states_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id)
		--	);
		--END;

		-- Create agent_event table if it doesn't exist
		IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'agent_event')
		BEGIN
			CREATE TABLE agent_event
			(
				agent_id BIGINT NOT NULL,
				domain_id BIGINT NOT NULL DEFAULT 1,
				event_id NVARCHAR(200) NOT NULL,
				timestamp_millisecond DATETIME NOT NULL DEFAULT DATEDIFF_BIG(MILLISECOND, '1970-01-01 00:00:00.000', GETUTCDATE()),
				agent NVARCHAR(150) NOT NULL,
				state NVARCHAR(40) NOT NULL,
				state_start_datetime DATETIME NOT NULL DEFAULT GETUTCDATE(),
				state_end_datetime DATETIME NOT NULL,
				dbdatetime DATETIME NOT NULL DEFAULT GETUTCDATE(),
				CONSTRAINT PK_agent_event PRIMARY KEY (event_id),
				CONSTRAINT FK_agent_event_agent FOREIGN KEY (agent_id) REFERENCES agent (agent_id),
				CONSTRAINT FK_agent_event_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id)
			);

			CREATE NONCLUSTERED INDEX IX_agent_event_agent_id_state_dates
				ON agent_event (agent_id, domain_id, state_start_datetime, state_end_datetime)
				INCLUDE (state, event_id);
		END;

		-- Create agent_state_interval table if it doesn't exist
		IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'agent_state_interval')
		BEGIN
			CREATE TABLE agent_state_interval
			(
				agent_id BIGINT NOT NULL,
				domain_id BIGINT NOT NULL,
				[interval] DATETIME NOT NULL,
				state NVARCHAR(40) NOT NULL,
				agent_state_time BIGINT NOT NULL,
				db_updated_datetime DATETIME NOT NULL DEFAULT GETUTCDATE(),
				db_created_datetime DATETIME NOT NULL DEFAULT GETUTCDATE(),
				CONSTRAINT PK_agent_state_interval PRIMARY KEY (agent_id,domain_id,state,[interval]),
				CONSTRAINT FK_agent_state_interval_agent FOREIGN KEY (agent_id) REFERENCES agent (agent_id),
				CONSTRAINT FK_agent_state_interval_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id)
			);

			CREATE NONCLUSTERED INDEX IX_agent_state_interval_interval_agent
				ON dbo.agent_state_interval ([interval], agent_id, domain_id)
				INCLUDE (state, agent_state_time);
		END;

	-- Commit the transaction if all steps succeed
    COMMIT TRANSACTION;
    PRINT 'Tables created successfully.';
END TRY
BEGIN CATCH
    -- Roll back the transaction if any error occurs
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    -- Output error details
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;