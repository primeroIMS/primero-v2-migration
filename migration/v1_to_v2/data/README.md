These Scripts are for exporting and generating v2 compatible data migration scripts on a 1.7 system.
==================================================================================================

Exporting the data on a v1 system
==================================

Copy the export scripts to the v1.7 system
-------------------------------------------
- check out the desired tag/branch of this repo
- scp the contents of the data directory to the target system.
  Sepcifically, you will need export_data.rb and everything under the exporters directory


Run the script on the v1.7 system
---------------------------------
- ssh to the 1.7 system
- $ sudo -Hu primero bash
- $ cd ~/application/
- $ $ RAILS_ENV=production bundle exec rails r /home/ubuntu/data/export_data.rb

(This will generate files in a record-data-files directory)


Tar up the record-data-files
----------------------------
- exit back to the ubuntu user
- $ cd /srv/primero/application
- $ sudo tar czvf record-data-filess.tar.gz record-data-files
- $ cd
- $ sudo mv /srv/primero/application/record-data-files.tar.gz .





Load the generated data migration scripts on a v2 server
========================================================

Copy / scp the tar file to the target v2 server
-------------------------------------------------

Untar the tar file on the v2 server
----------------------------------------
$ tar -xzvf record-data-files.tar.gz


Copy the import script to the v2 system
-----------------------------------------------------------------------
- If you haven't already, check out the desired tag/branch of this repo
- scp the import_data.rb script to the target system.
- the record-data-files directory should be at the same level as the import_data.rb script
  Ex:   /home/ubuntu/import_data.rb
        /home/ubuntu/record-data-files/*


Run the script on the v2 system
---------------------------------
- ssh to the v2 system
- $ sudo -Hu primero bash
- $ cd ~/application/
- $ RAILS_ENV=production rails r /home/ubuntu/import_data.rb