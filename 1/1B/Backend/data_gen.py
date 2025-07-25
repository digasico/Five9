import random
from datetime import datetime, timedelta

# Variables
domain_ids = [1]  # Single domain
agent_ids = [1001, 1002, 1003, 1004, 1005]  # 5 agents

# Valid states and allowed transitions
states = ['LOGGED_IN', 'READY', 'ON_CALL', 'ACW', 'ON_HOLD', 'ON_PARK', 'NOT_READY', 'LOGGED_OUT']
valid_transitions = {
    'LOGGED_IN': ['READY', 'NOT_READY'],
    'READY': ['ON_CALL', 'NOT_READY', 'ON_HOLD', 'ON_PARK'],
    'ON_CALL': ['ACW', 'ON_HOLD', 'ON_PARK'],
    'ACW': ['READY', 'NOT_READY'],
    'ON_HOLD': ['ON_CALL', 'READY', 'NOT_READY'],
    'ON_PARK': ['ON_CALL', 'READY', 'NOT_READY'],
    'NOT_READY': ['READY'],
    'LOGGED_OUT': ['LOGGED_IN']  # LOGGED_OUT can transition to LOGGED_IN on next day
}

# State duration ranges (in minutes)
duration_ranges = {
    'LOGGED_IN': (180, 480),  # Login session: 3–8 hours
    'READY': (5, 30),         # Waiting for calls
    'ON_CALL': (5, 60),       # Active call duration
    'ACW': (2, 15),           # After-call work
    'ON_HOLD': (2, 20),       # Holding a call
    'ON_PARK': (5, 30),       # Parked call
    'NOT_READY': (5, 45),     # Breaks or other tasks
    'LOGGED_OUT': (960, 1440) # Between sessions (overnight, adjusted dynamically)
}

# Helper function to generate agent events
def generate_agent_events(agent_ids, domain_ids, num_days=30):
    events = []
    event_id_counter = 1

    for agent_id in agent_ids:
        base_time = datetime(2025, 7, 1, 8, 0, 0)  # Start at 8 AM

        # Track previous day's logout time for LOGGED_OUT duration
        prev_logout_end_time = base_time

        for day in range(num_days):
            end_of_day = prev_logout_end_time + timedelta(hours=8)  # 8-hour workday

            # Generate LOGGED_IN event
            login_start_time = prev_logout_end_time
            login_duration = random.randint(*duration_ranges['LOGGED_IN'])
            login_end_time = login_start_time + timedelta(minutes=login_duration)
            login_end_time = min(login_end_time, end_of_day)

            login_event_id = f"EVT{event_id_counter:03}"
            event_id_counter += 1
            events.append(
                f"({agent_id}, {domain_ids[0]}, '{login_event_id}', '{login_start_time.strftime('%Y-%m-%d %H:%M:%S.000')}', "
                f"'Agent_{agent_id}', 'LOGGED_IN', '{login_start_time.strftime('%Y-%m-%d %H:%M:%S.000')}', "
                f"'{login_end_time.strftime('%Y-%m-%d %H:%M:%S.000')}')"
            )

            # Generate intermediate events within LOGGED_IN period
            current_time = login_start_time
            current_state = 'LOGGED_IN'
            num_intermediate_events = random.randint(3, 6)
            for _ in range(num_intermediate_events):
                if current_time >= login_end_time - timedelta(minutes=10):  # Reserve time before login end
                    break

                # Choose next state based on valid transitions
                possible_states = valid_transitions[current_state]
                if not possible_states:
                    break
                next_state = random.choice(possible_states)

                # Get duration for the next state
                duration = random.randint(*duration_ranges[next_state])
                state_start_time = current_time
                state_end_time = state_start_time + timedelta(minutes=duration)

                # Ensure event doesn't exceed login end
                if state_end_time > login_end_time:
                    state_end_time = login_end_time
                    duration = int((state_end_time - state_start_time).total_seconds() / 60)

                event_id = f"EVT{event_id_counter:03}"
                event_id_counter += 1
                events.append(
                    f"({agent_id}, {domain_ids[0]}, '{event_id}', '{state_start_time.strftime('%Y-%m-%d %H:%M:%S.000')}', "
                    f"'Agent_{agent_id}', '{next_state}', '{state_start_time.strftime('%Y-%m-%d %H:%M:%S.000')}', "
                    f"'{state_end_time.strftime('%Y-%m-%d %H:%M:%S.000')}')"
                )
                current_time = state_end_time
                current_state = next_state

            logout_event_id = f"EVT{event_id_counter:03}"
            # Generate LOGGED_OUT event from end of LOGGED_IN to start of next day's LOGGED_IN
            if day < num_days - 1:  # Not the last day
                next_day_time = base_time + timedelta(days=day)
                logout_start_time = login_end_time
                logout_end_time = next_day_time  # Next day's login start
            else:  # Last day, LOGGED_OUT extends to end of period
                logout_start_time = login_end_time
                logout_end_time = logout_start_time + timedelta(hours=16)  # Arbitrary 16 hours for last day
            events.append(
                f"({agent_id}, {domain_ids[0]}, '{logout_event_id}', '{logout_start_time.strftime('%Y-%m-%d %H:%M:%S.000')}', "
                f"'Agent_{agent_id}', 'LOGGED_OUT', '{logout_start_time.strftime('%Y-%m-%d %H:%M:%S.000')}', "
                f"'{logout_end_time.strftime('%Y-%m-%d %H:%M:%S.000')}')"
            )
            event_id_counter += 1
            prev_logout_end_time = logout_end_time

    return events

# Generate the SQL data
agent_events = generate_agent_events(agent_ids, domain_ids)

# Start SQL script
begin_sql = """
USE test1;
BEGIN TRY	
    BEGIN TRANSACTION;
"""

# Generate SQL insert statements
domain_insert = "\t\tINSERT INTO domain (domain_id) VALUES (1);\n"
agent_insert = "\n".join([f"\t\tINSERT INTO agent (agent_id) VALUES ({agent_id});" for agent_id in agent_ids])

# End SQL script
end_sql = """
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
"""

sql_data = (
    begin_sql +
    domain_insert +
    agent_insert +
    "\n\n\t\t-- Insert into agent_event table\n" +
    "\n".join(
        f"\t\tINSERT INTO agent_event (agent_id, domain_id, event_id, timestamp_millisecond, agent, state, state_start_datetime, state_end_datetime) VALUES {event};"
        for event in agent_events
    ) +
    "\n" + end_sql
)

# Write SQL data to a file
file_path = r"C:\Users\diogo\OneDrive\Ambiente de Trabalho\Five9_take_home\1\1A\1A_v2\populate_tables.sql"
with open(file_path, 'w') as f:
    f.write(sql_data)

print(f"SQL data has been written to {file_path}")