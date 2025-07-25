BEGIN TRY	
	BEGIN TRANSACTION;
		-- Insert a dummy domain record
		INSERT INTO domain (domain_id)
		VALUES (1), (2);

		-- Insert a dummy agent record
		INSERT INTO agent (agent_id)
		VALUES (1001), (1002), (2001);

		---- Insert initial state values into domain_agent_states
		--INSERT INTO domain_agent_states (domain_id, state, db_date)
		--VALUES 
		--(1, 'READY', GETUTCDATE()),
		--(1, 'NOT_READY', GETUTCDATE()),
		--(1, 'ON_CALL', GETUTCDATE()),
		--(1, 'ACW', GETUTCDATE()),
		--(1, 'LOGGED_OUT', GETUTCDATE()),
		--(2, 'READY', GETUTCDATE()),
		--(2, 'ON_CALL', GETUTCDATE());

		INSERT INTO agent_event (
		agent_id, domain_id, event_id, timestamp_millisecond,
		agent, state, state_start_datetime, state_end_datetime, dbdatetime
		)
		VALUES
		-- A. Aligned to 15 min
		(1001, 1, 'E001', '2025-07-19T10:00:00Z', 'AGENT1', 'READY', '2025-07-19T10:00:00Z', '2025-07-19T10:15:00Z', GETUTCDATE()),

		-- B. Starts before interval
		(1001, 1, 'E002', '2025-07-19T09:55:00Z', 'AGENT1', 'ON_CALL', '2025-07-19T09:55:00Z', '2025-07-19T10:05:00Z', GETUTCDATE()),

		-- C. Ends after interval
		(1001, 1, 'E003', '2025-07-19T10:25:00Z', 'AGENT1', 'ON_CALL', '2025-07-19T10:25:00Z', '2025-07-19T10:45:00Z', GETUTCDATE()),

		-- D. Crosses two intervals
		(1002, 1, 'E004', '2025-07-19T10:10:00Z', 'AGENT2', 'NOT_READY', '2025-07-19T10:10:00Z', '2025-07-19T10:20:00Z', GETUTCDATE()),

		-- E. Spans three intervals
		(1002, 1, 'E005', '2025-07-19T10:00:00Z', 'AGENT2', 'ACW', '2025-07-19T10:00:00Z', '2025-07-19T10:45:00Z', GETUTCDATE()),

		-- F. Entirely before window — should not be counted
		(1001, 1, 'E006', '2025-07-19T09:00:00Z', 'AGENT1', 'LOGGED_OUT', '2025-07-19T09:00:00Z', '2025-07-19T09:30:00Z', GETUTCDATE()),

		-- G. Agent from different domain
		(2001, 2, 'E007', '2025-07-19T10:00:00Z', 'AGENT3', 'ON_CALL', '2025-07-19T10:00:00Z', '2025-07-19T10:30:00Z', GETUTCDATE());

	-- Commit the transaction if all steps succeed
	COMMIT TRANSACTION;
	PRINT 'Tables populated successfully.';
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