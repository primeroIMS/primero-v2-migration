These Scripts are for exporting and generating v2 compatible user seed scripts on a 1.7 system.
==================================================================================================

Exporting the users on a v1 system
==================================

Copy script to the v1.7 system
------------------------------
- check out the desired tag/branch of this repo
- scp the contents of the users directory to the target system.
  Sepcifically, you will need export_users.rb and everything under the exporters directory


Run the script on the v1.7 system
---------------------------------
- ssh to the 1.7 system
- $ sudo -Hu primero bash
- $ cd ~/application/
- $ $ RAILS_ENV=production bundle exec rails r /home/ubuntu/users/export_users.rb

(This will generate user seed files in a seed-files directory)


Tar up the seed-files
---------------------
- exit back to the ubuntu user
- $ cd /srv/primero/application
- $ sudo tar czvf seed-files.tar.gz seed-files
- $ cd
- $ sudo mv /srv/primero/application/seed-files.tar.gz .



Load the generated user migration scripts on a v2 server
========================================================

Copy / scp the tar file to the target v2 server
-------------------------------------------------

Untar the tar file on the v2 server
----------------------------------------
$ tar -xzvf seed-files.tar.gz


Copy the import script to the v2 server
-----------------------------------------
- If you haven't already, check out the desired tag/branch of this repo
- scp the import_data.rb script to the target system.
- the seed-files directory should be at the same level as the import_users.rb script
  Ex:   /home/ubuntu/import_users.rb
        /home/ubuntu/seed-files/*


ON THE v2 SERVER
----------------------

Copy the scripts to the application docker container
------------------------------------------------------
- $ docker ps   (to get the name of the application image)
- $ docker cp seed-files primero_application_1:/srv/primero/application/tmp/.  (where primero_application_1 is the image name)
- $ docker cp import_users.rb primero_application_1:/srv/primero/application/tmp/.


Run the script in the docker container
---------------------------------------
- $ sudo docker exec -it primero_application_1 bash  (to access the docker container)
- $ cd /srv/primero/application
- $ rails r ./tmp/import_users.rb > import_users.out


WARNING - Potential issue with Users and User Groups getting out of sync
------------------------------------------------------------------------
There is a many to many relationship between Users and User Groups.
There is a link table user_groups_users to manage this association.
If during user migration testing you delete all users and re-import, this association can get out of sync.
Also, if you delete the UserGroups table and reload the configuration, this association can get out of sync.
It is important that your load_configuration script updates UserGroups without first deleting them.
To resolve:
- From rails console in the application container:
  - Delete all rows from user_groups_users table:  `$ User.connection.execute('Delete from user_groups_users')`
  - Delete all rows from the users table: `$ User.delete_all`
- From command line in the application container:
  - Re-run the user import
  `