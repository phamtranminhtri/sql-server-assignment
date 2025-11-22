SQL Server queries run order:

1. `reset.sql`: Drop the database (`MyDatabase`) if it exists.
2. `create_table.sql`: Create database `MyDatabase` and its tables.
3. `insert_data.sql`: Populate the tables with data.
4. `function_procedure.sql`: Create functions and stored procedures.
5. `trigger.sql`: Create triggers.

(`test.sql` is for demo the effects of the functions, stored procedures, and triggers)

When something goes wrong, drop the database with `reset.sql` and restart!
