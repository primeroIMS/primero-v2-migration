This documents the steps to anonymize production to simulate a production migration
==================================================================================================
After you have completed testing the data migration with integration and alpha data, the next step
is to do a test migration run using anonymized production data.
This anonymization happens on a v1 test server.
After the v1 prod data is anonymized, continue with the migration process same as in the previous iterations.

It is **EXTREMELY** important to anonymize sensitive personal data so it is not exposed outside of the
production environment.


Set up data mapping for instance specific fields to be anonymized
=================================================================
The data_anonymizer has a built-in mapping of fields generic to all instances that are to be anonymized.  
The script takes as input a json file with a mapping of fields defined in your forms that need to be anonymized and  
  are not already defined in the built-in mapping.  
This file contains a hash for each record type (case, incident, tracing_request)  
In that hash, the key is the field name, the value is the anonymization type  
   (first_name, last_name, full_name, address, phone, id, email, subform)  
Typically, we store this mapping file on the configuration repo under an 'anonymization' directory then manyally copy  
  it to the v1 test server when you run the anonymization script.
   
Subforms
--------
To handle subform fields that need to anonymized, first add a hash entry for the subform itself  
then add a hash entry for each field on that subform that needs to be anonymized.

Example:
```
   ...
   "incident_details": "subform",
   "incident_details||cp_incident_abuser_name": "full_name",
   "incident_details||cp_incident_perpetrator_national_id_no": "id",
   "incident_details||cp_incident_perpetrator_other_id_no": "id",
   "incident_details||cp_incident_perpetrator_mobile_phone": "phone",
   "incident_details||cp_incident_perpetrator_phone": "phone",
   "incident_details||cp_incident_perpetrator_address": "address",
   "incident_details||cp_incident_perpetrator_work_place": "address",
   "incident_details||cp_incident_perpetrator_work_phone": "phone",
   "incident_details||cp_incident_perpetrator_work_address": "address",
   "incident_details||abuser_notes": "full_name"
   ...
```

anonymize_field_map.json example
--------------------------------
```
{
  "case_fields": {
    "legal_guardian": "full_name",
    "ration_card_no": "id",
    "icrc_ref_no": "id",
    "rc_id_no": "id",
    "unhcr_id_no": "id",
    "unhcr_individual_no": "id",
    "un_no": "id",
    "family_number": "id",
    "other_id_no": "id",
    "telephone_mobile": "phone",
    "telephone_current": "phone",
    "occupation_place": "address",
    "occupation_phone": "phone",
    "occupation_address": "address",
    "caregiver_id_type_and_no": "id",
    "consent_source_other": "full_name",
    "incident_details": "subform",
    "incident_details||cp_incident_abuser_name": "full_name",
    "incident_details||cp_incident_perpetrator_national_id_no": "id",
    "incident_details||cp_incident_perpetrator_other_id_no": "id",
    "incident_details||cp_incident_perpetrator_mobile_phone": "phone",
    "incident_details||cp_incident_perpetrator_phone": "phone",
    "incident_details||cp_incident_perpetrator_address": "address",
    "incident_details||cp_incident_perpetrator_work_place": "address",
    "incident_details||cp_incident_perpetrator_work_phone": "phone",
    "incident_details||cp_incident_perpetrator_work_address": "address",
    "incident_details||abuser_notes": "full_name"
  },
  "incident_fields": {
    "national_id_no": "id",
    "other_id_no": "id",
    "abuser_notes": "full_name",
    "perpetrators_subform": "subform",
    "perpetrators_subform||cp_incident_abuser_name": "full_name",
    "perpetrators_subform||cp_incident_perpetrator_national_id_no": "id",
    "perpetrators_subform||cp_incident_perpetrator_other_id_no": "id",
    "perpetrators_subform||cp_incident_perpetrator_mobile_phone": "phone",
    "perpetrators_subform||cp_incident_perpetrator_phone": "phone",
    "perpetrators_subform||cp_incident_perpetrator_address": "address",
    "perpetrators_subform||cp_incident_perpetrator_work_place": "address",
    "perpetrators_subform||cp_incident_perpetrator_work_phone": "phone",
    "perpetrators_subform||cp_incident_perpetrator_work_address": "address",
    "perpetrators_subform||cp_incident_abuser_notes": "full_name",
    "cp_incident_abuser_name": "full_name",
    "cp_incident_perpetrator_national_id_no": "id",
    "cp_incident_perpetrator_other_id_no": "id",
    "cp_incident_perpetrator_mobile_phone": "phone",
    "cp_incident_perpetrator_phone": "phone",
    "cp_incident_perpetrator_address": "address",
    "cp_incident_perpetrator_work_place": "address",
    "cp_incident_perpetrator_work_phone": "phone",
    "cp_incident_perpetrator_work_address": "address"
  },
  "tracing_request_fields": {
    "caseworker_name": "full_name",
    "work_phone": "phone",
    "work_address": "address"
  }
}
```


Copy the couch database from the v1 production server to a v1 test server
=========================================================================

Shut down web services on your v1 test server
---------------------------------------------
On the v1 test server, stop nginx  
This is to ensure users cannot access the application before the production data has been anonymized

- $sudo service nginx stop
- $sudo service nginx status



Copy production database to the v1 test server
----------------------------------------------
- ssh to the production v1 server
- cd to /var/lib
- Be careful to preserve couchdb ownership and permissions on all the files.  (use -p to preserve these permissions)
- $ sudo cp -rp couchdb couchdb_<tag info>
        example:   sudo cp -rp couchdb couchdb_IQ_PROD_20210713
- $ sudo tar czvf couchdb_IQ_PROD_20210713.tar.gz couchdb_IQ_PROD_20210713
- Copy this tar file to /var/lib on the v1 test server
- On the v1 test server after the file has been copied...
- $ cd /var/lib
- $ sudo tar -xzvf couchdb_IQ_PROD_20210713.tar.gz

This should extract the copied couchdb into a subdirectory 'couchdb_IQ_PROD_20210713'


Make a backup of the existing couchdb directory on the v1 test server
---------------------------------------------------------------------
- $ cd /var/lib
- $ sudo cp -rp couchdb couchdb_<tag info>
        example:   sudo cp -rp couchdb couchdb_SAVE_TEST_IQ_20210713


Stop couchdb and other system processes on the v1 test server
-------------------------------------------------------------
- $ sudo /srv/primero/bin/primeroctl stop
- $ sudo /srv/primero/bin/primeroctl status   #optional - to check status of processes


Load the production data
------------------------
Copy in only the Case(Child), Incident, Tracing Request, and User couchdb records from the copied production db data

- $ cd /var/lib
- $ sudo rm couchdb/primero_child_production.couch
- $ sudo rm -rf couchdb/.primero_child_production_design
- $ sudo cp -p couchdb_IQ_PROD_20210713/primero_child_production.couch couchdb/.
- $ sudo cp -rp couchdb_IQ_PROD_20210713/.primero_child_production_design couchdb/.
(Repeat copy steps for Incident, Tracing Request, and User)


Remove the production database from the v1 test server
------------------------------------------------------
- $ cd /var/lib
- $ sudo rm -rf couchdb_IQ_PROD_20210713


Restart the services including couchdb, but not the web server
--------------------------------------------------------------
- $sudo /srv/primero/bin/primeroctl start
- $sudo /srv/primero/bin/primeroctl status
- $sudo service nginx stop
- $sudo service nginx status
- $sudo /srv/primero/bin/primeroctl status


Run the Invalid Users Report and resolve user issues
====================================================

Copy the script to the v1 test server
-------------------------------------
From the primero-v2-migration repo...  

- cd migration/v1_to_v2
- Copy the entire users directory to /home/sysadmin or /home/ubuntu on the v1 test server (depending on server setup)
             example:  scp -r users cpims-iq-alpha.primero.org:~/

On the v1 test server, run the invalid_users_report script
----------------------------------------------------------
- $ sudo -Hu primero bash
- $ cd ~/application/
- $ rails r /home/sysadmin/users/invalid_users_report.rb

Resolve user issues found on that report
----------------------------------------
Combine the .csv files generated by the script into an Excel spreadsheet and share that with the users so they can  
investigate and clean up production user data as necessary.  

For testing, resolve the issues with the user data on the v1 test server


Anonymize the data
==================

Copy the script to the v1 test server
-------------------------------------
From the primero-v2-migration repo...  

- cd migration/v1_to_v2
- Copy the entire data directory to /home/sysadmin or /home/ubuntu on the v1 test server (depending on server setup)  
             example:  scp -r data cpims-iq-alpha.primero.org:~/
                       
Copy the json field map to the v1 test server
----------------------------------------------
From the configuration repo...  

- cd <your implementation>
- Copy the script to the v1 test server  
             example:  cd iraq/anonymization  
                       scp anonymize_field_map.json cpims-iq-alpha.primero.org:~/

On the v1 test server, run the anonymization script
---------------------------------------------------
- $ sudo -Hu primero bash
- $ cd ~/application/
- $ rails r /home/sysadmin/data/anonymize_data.rb 'Case||Incident||TracingRequest' '/home/sysadmin/anonymize_field_map.json'



Disable all users
========================================

Copy the script to the v1 test server
-------------------------------------
From the primero-v2-migration repo...  

- cd migration/v1_to_v2
- Copy the entire users directory to /home/sysadmin or /home/ubuntu on the v1 test server (depending on server setup)  
             example:  scp -r users cpims-iq-alpha.primero.org:~/

On the v1 test server, run the update_disabled script
---------------------------------------------------
- $ sudo -Hu primero bash
- $ cd ~/application/
- $ rails r /home/sysadmin/users/update_disabled.rb 'true'



Restart the web server so the testing team can test
===================================================

On the v1 test server, restart the system
-----------------------------------------
- $ sudo /srv/primero/bin/primeroctl restart
- $ sudo /srv/primero/bin/primeroctl status   #optional - to check status of processes

Enable test users
-----------------
For only the users requested by the testing team...  

- Update 'disabled' to false
- Update 'password' and 'password_confirmation' to a secure password
- Share that password with the testing team via a secure communication app


Run the migration
=================
Run the data and user migration same as before in the other iterations.

- Refer to the [Data Migration README](../README.md) for more detail.  
- Refer to the [User Migration README](../../users/README.md) for more detail.
