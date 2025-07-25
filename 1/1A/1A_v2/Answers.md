1. I believe the "populate_tables.sql" answers this question since the calculations are
   inside an insert/update trigger for the agent_event table. Therefore, inserting rows 
   into agent_state is basically insert/update rows into agent_state.<br>
<br>
2. Well, I'm not sure that I fully grasp the goal behind this question; therefore, it is hard
   for me to say for sure what's wrong, but I would guess that:
  
    - domain_agent_states feels weird. For the name I would guess it is and intermediary 
      table for domain and agent, but then there is no agent reference in any column, therefor
      I do not know??? Also, there is no context about what a state represents. Does a domain 
      have a state? Is the event that has a state? Is it both? What about agents? Do they 
      have states? Well, I'm guessing this table is just here to show that the same states are 
      used in several tables, which leads me to say that maybe states should be an enum. First,
      if it's going to be used in several tables its way easier to maintain 1 table than updating 
      in multiple tables , then there is the space required by a string vs int and performance 
      (don't make me enumerate all the advantages of using index with relations instead of 
      duplicating data all over relational databases :) )

    - Don't know if that counts, but I added indexes that were not in the tables, and those 
      should also help improve the performance since agent_state_interval is a rollup table.

    - Not sure if I would have the column "agent" in table agent_event, as far as I can 
      tell it is dependent on agent, so it should be on the agent table.<br>
<br>
3. I guess this is the trigger (create_trigger.sql)