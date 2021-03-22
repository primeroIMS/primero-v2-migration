These Scripts are for exporting and generating v2 compatible config seed scripts on a 1.7 system.
==================================================================================================

Exporting the seeds on a v1 system
==================================

Copy script to the v1.7 system
------------------------------
- check out the desired tag/branch of this repo
- scp the contents of the configuration directory to the target system.
  Sepcifically, you will need export_configuration.rb and everything under the exporters directory


Run the script on the v1.7 system
---------------------------------
- ssh to the 1.7 system
- $ sudo -Hu primero bash
- $ cd ~/application/
- $ $ RAILS_ENV=production bundle exec rails r /home/ubuntu/configuration/export_configuration.rb

(This will generate files in a seed-files directory)


Tar up the seed-files
---------------------
- exit back to the ubuntu user
- $ cd /srv/primero/application
- $ sudo tar czvf seed-files.tar.gz seed-files
- $ cd
- $ sudo mv /srv/primero/application/seed-files.tar.gz .


Copy / scp the tar file back to your local system
-------------------------------------------------



Load the generated configuration scripts on a v2 server
=======================================================

Untar the tar file on your local system
----------------------------------------
$ tar -xzvf seed-files.tar.gz


Add these seed files to a configuration repo branch
---------------------------------------------------


Copy the load_configuration_template.rb script to the root seed-files directory in your repo branch
---------------------------------------------------------------------------------------------------


Update the load configuration script as needed if necessary
-----------------------------------------------------------


Make sure the target v2 system has the appropriate locales as were on the v1.7 system
-------------------------------------------------------------------------------------


Deploy the configuration to the v2 system
-----------------------------------------
