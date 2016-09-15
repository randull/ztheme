#!/bin/bash
#
# This script deletes virtual hosts and drupal directory.
#
# Retrieve Domain Name from command line argument OR Prompt user to enter  
if [ "$1" == "" ]; 
  then
    echo "No arguments provided";
    read -p "Site domain to update: " domain;
  else
    echo $1;
    domain=$1;
fi
# Create variables from Domain Name
hosts=/etc/apache2/sites-available    # Set variable for Apache Host config
www=/var/www                          # Set variable for Drupal root directory
tld=`echo $domain  |cut -d"." -f2,3`  # Generate tld (eg .com)
name=`echo $domain |cut -f1 -d"."`    # Remove last for characters (eg .com) 
longname=`echo $name |tr '-' '_'`     # Change hyphens (-) to underscores (_)
shortname=`echo $name |cut -c -16`    # Shorten name to 16 characters for MySQL
machine=`echo $shortname |tr '-' '_'` # Replace hyphens in shortname to underscores
# Put Dev & Prod sites into Maintenance Mode
drush @$machine vset maintenance_mode 1 -y && drush @$machine cc all -y
# Fix File and Directory Permissions on Prod
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chown -R deploy:deploy html/*"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chown -R deploy:www-data logs/* private/* public/* tmp/*"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chmod -R ug=rw,o=r,a+X logs/* private/* public/* tmp/*"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chmod -R u=rw,go=r,a+X html/*"
# Fix File and Directory Permissions on Dev
cd /var/www/$domain
sudo chown -R deploy:deploy html/*
sudo chown -R deploy:www-data logs/* private/* public/* tmp/*
sudo chmod -R ug=rw,o=r,a+X logs/* private/* public/* tmp/*
sudo chmod -R u=rw,go=r,a+X html/*
# Checkout all changes on Development Web Server
cd /var/www/$domain/html
git add .
git reset --hard
git stash
git stash drop
git checkout -- .
# Git steps on Production Web Server
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git status"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git add . -A"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git commit -a -m \"Preparing Git Repo for Drupal Updates on Dev Server\""
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git push origin master"
# Git steps on Development
git status
git pull origin master
# Rsync steps for sites/default/files
drush -y rsync -avz @$machine.prod:%files @$machine.dev:%files
# Export DB from Prod to Dev using Drush
drush sql-sync --no-cache --skip-tables-key=common @$machine.prod @$machine.dev -y
# Prepare site for Maintenance
cd /var/www/$domain/html
drush @$machine.dev pm-disable cdn contact_google_analytics ga_tokenizer googleanalytics honeypot_entityform honeypot prod_check -y
drush @$machine.dev en devel admin_devel devel_generate devel_node_access ds_devel metatag_devel -y
# Prepare site for Development
drush @$machine cron -y && drush @$machine updb -y && drush @$machine cron -y
# Take Dev & Prod sites out of Maintenance Mode
drush @$machine vset maintenance_mode 0 -y && drush @$machine cc all -y
