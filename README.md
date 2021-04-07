These Scripts are for migrating a v1.7 system to a v2 system
=============================================================


Configuration
==================
- Run configuration/export_configuration.rb on the 1.7 server to generate v2 compatible ruby config seeds.
- Copy the generated seeds to a config repo branch
- Add in the load_configuration.rb script to the config repo branch
- Deploy that configuration to the v2 server

User Migration
=================
- Run users/export_data.rb on the 1.7 server to generate v2 compatible ruby data migration scripts.
- Copy the generated user migration scripts to the target v2 server
- Run the import_users.rb script on the target v2 server to execute the generated user migration scripts.


Data Migration
=================
- Run data/export_data.rb on the 1.7 server to generate v2 compatible ruby data migration scripts.
- Copy the generated data migration scripts to the target v2 server
- Run the import_data.rb script on the target v2 server to execute the generated data migration scripts.
