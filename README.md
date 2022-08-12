These Scripts are for migrating a v1.7 system to a v2 system
=============================================================

Pre Migration
=================
- Prior to running the migration, run the invalid_users_report to get a report of users that will have issues being
  migrated to v2 and to get a list of users that are currently disabled
- Refer to the [User Migration README](./migration/v1_to_v2/users/README.md) for more detail.

Configuration
==================
- Run configuration/export_configuration.rb on the 1.7 server to generate v2 compatible ruby config seeds.
- Copy the generated seeds to a config repo branch
- Add in the load_configuration.rb script to the config repo branch
- Deploy that configuration to the v2 server
- Refer to the [Configuration README](./migration/v1_to_v2/configuration/README.md) for more detail.

User Migration
=================
- Run users/export_data.rb on the 1.7 server to generate v2 compatible ruby data migration scripts.
- Copy the generated user migration scripts to the target v2 server
- Run the import_users.rb script on the target v2 server to execute the generated user migration scripts.
- Refer to the [User Migration README](./migration/v1_to_v2/users/README.md) for more detail.


Data Migration
=================
- Run data/export_data.rb on the 1.7 server to generate v2 compatible ruby data migration scripts.
- Copy the generated data migration scripts to the target v2 server
- Run the import_data.rb script on the target v2 server to execute the generated data migration scripts.
- Refer to the [Data Migration README](./migration/v1_to_v2/data/README.md) for more detail.


Post Migration
=================
- Run the reset_passwords.rb script to update user passwords.
- Run the updated_disabled.rb script to disable all users.
- After verification is complete and ready to go live, run the update_disabled.rb script to enable all users.
- Refer to the [User Migration README](./migration/v1_to_v2/users/README.md) for more detail.

Notes
=====
- If you have a date range field in any of the ugrade server forms these fields have been deprecated in v2. They represent as text fields in v2 and will prevent the case from being saved (Invalid JSON Error) if the user tries to fill them out.
