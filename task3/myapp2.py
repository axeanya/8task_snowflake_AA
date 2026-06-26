import streamlit as st
from snowflake.snowpark.context import get_active_session

st.title("❄️ Snowflake ❄️")
st.caption("(🐾^._.^🐾) Self-Service Database Cloning and Access Management (🐾^._.^🐾)")

# Initialize the active Snowflake session within Snowsight
try:
    session = get_active_session()
except Exception:
    st.error("Execution failed.")
    st.stop()

# User input configuration panel
st.sidebar.header("💻⚙️ Configuration Setup 💻⚙️")
source_db = st.sidebar.text_input("Source Database Template", value="SF_AVIA").strip().upper()
target_db = st.sidebar.text_input("New Target Database Name", value="SF_AVIA_DEV").strip().upper()

st.sidebar.subheader("⚙️ Infrastructure Setup ⚙️")
warehouse_name = st.sidebar.text_input("Target Warehouse", value="COMPUTE_WH").strip().upper()

# SQL GENERATION 
generated_sql = f"""CREATE DATABASE {target_db} CLONE {source_db};
CREATE ROLE IF NOT EXISTS readonly_role;
CREATE ROLE IF NOT EXISTS development_role;
GRANT USAGE ON WAREHOUSE {warehouse_name} TO ROLE readonly_role;
GRANT USAGE ON DATABASE {target_db} TO ROLE readonly_role;
GRANT USAGE ON ALL SCHEMAS IN DATABASE {target_db} TO ROLE readonly_role;
GRANT SELECT ON ALL TABLES IN DATABASE {target_db} TO ROLE readonly_role;
GRANT SELECT ON ALL VIEWS IN DATABASE {target_db} TO ROLE readonly_role;
GRANT SELECT ON FUTURE TABLES IN DATABASE {target_db} TO ROLE readonly_role;
GRANT SELECT ON FUTURE VIEWS IN DATABASE {target_db} TO ROLE readonly_role;
GRANT ROLE readonly_role TO ROLE development_role;
GRANT MODIFY, CREATE SCHEMA ON DATABASE {target_db} TO ROLE development_role;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE {target_db} TO ROLE development_role;
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE {target_db} TO ROLE development_role;"""

# Display the SQL code script on the main screen
st.subheader("📋 Generated SQL Script Preview")
st.caption("Review the dynamic deployment steps below before triggering the execution pipeline:")
st.code(generated_sql, language="sql")

st.markdown("---")

# Safety Gate: Confirmation Checkbox
is_confirmed = st.checkbox("🔒 I have reviewed the generated SQL script and confirm its execution")

# Main processing interface (The button is disabled unless the checkbox is ticked)
if st.button("🚀 Execute Environment Provisioning 🚀", type="primary", disabled=not is_confirmed):
    if not target_db or not source_db:
        st.error("Validation Error: Both Source and Target database names are mandatory fields.")
    elif target_db == source_db:
        st.error("Validation Error: Target database name must be different from the Source database.")
    else:
        status_indicator = st.empty()
        status_indicator.info("Processing execution...")
        
        try:
            # Parse the big string into a list of individual clean SQL statements
            sql_commands = [
                cmd.strip() for cmd in generated_sql.split(";") if cmd.strip()
            ]
            
            # Execute every single command dynamically in a loop
            for index, command in enumerate(sql_commands, 1):
                status_indicator.info(f"Executing step {index}/{len(sql_commands)}: `{command[:40]}...`")
                session.sql(command).collect()
            
            # Success feedback 
            status_indicator.empty()
            st.success(f"Success! Database '{target_db}' provisioned with all RBAC hierarchies.")
            st.balloons()

        except Exception as error_log:
            status_indicator.empty()
            st.error(f"Deployment Pipeline Failed: {str(error_log)}")