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
# Put Local & Prod sites into Maintenance Mode
cd /var/www/$domain/html
drush -y @$machine.local vset maintenance_mode 1
drush -y @$machine.local cc all
drush -y @$machine.prod vset maintenance_mode 1
drush -y @$machine.prod cc all 
# Fix File and Directory Permissions on Prod
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chown -Rf deploy:www-data *"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chown -Rf deploy:www-data  html/* logs/* private/* public/* tmp/*"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chmod -Rf u=rw,go=r,a+X html/* logs/*"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chmod -Rf ug=rw,o=r,a+X private/* public/* tmp/*"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chmod 775 *"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chmod 664 html/.htaccess private/.htaccess public/.htaccess tmp/.htaccess"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && sudo rm -rf modules/README.txt profiles/README.txt themes/README.txt"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && sudo rm -rf CHANGELOG.txt COPYRIGHT.txt INSTALL.mysql.txt INSTALL.pgsql.txt INSTALL.sqlite.txt INSTALL.txt LICENSE.txt MAINTAINERS.txt UPGRADE.txt"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && sudo rm -rf sites/README.txt sites/example.sites.php sites/all/libraries/plupload/examples sites/all/modules/README.txt sites/all/themes/README.txt sites/default/default.settings.php"
# Remove unecessary files
# Fix file ownership
cd /var/www/$domain
sudo chown -Rf deploy:www-data *
sudo chown -Rf deploy:www-data html/* logs/* private/* public/* tmp/*
echo "File Ownership fixed"
# Fix file permissions
sudo chmod -Rf u=rw,go=r,a+X html/* logs/*
sudo chmod -Rf ug=rw,o=r,a+X private/* public/* tmp/*
sudo chmod 775 *
sudo chmod 644 html/.htaccess private/.htaccess public/.htaccess tmp/.htaccess
echo "File Permissions fixed"
# Remove unecessary files
cd /var/www/$domain/html
sudo rm -rf modules/README.txt profiles/README.txt themes/README.txt
sudo rm -rf CHANGELOG.txt COPYRIGHT.txt INSTALL.mysql.txt INSTALL.pgsql.txt INSTALL.sqlite.txt INSTALL.txt LICENSE.txt MAINTAINERS.txt UPGRADE.txt
sudo rm -rf sites/README.txt sites/example.sites.php sites/all/libraries/plupload/examples sites/all/modules/README.txt sites/all/themes/README.txt sites/default/default.settings.php
echo "Unecessary files removed"
# Checkout all changes on Local Environment
cd /var/www/$domain/html
git status
git add . -A
git reset --hard
git stash
git stash drop
git checkout -- .
git status
# Git steps on Production Web Server
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git status"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git add . -A"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git commit -a -m \"Preparing Git Repo for Drupal Updates on Local Server\""
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git push origin master"
# Git steps on Development
git status
git diff
git pull origin master
# Rsync steps for sites/default/files
drush -y rsync -avO @$machine.prod:%files @$machine.local:%files
# Export DB from Prod to Local using Drush
drush -y sql-sync --skip-tables-key=common @$machine.prod @$machine.local
# Prepare site for Maintenance
cd /var/www/$domain/html
drush -y @$machine.local dis cdn contact_google_analytics ga_tokenizer googleanalytics honeypot_entityform honeypot prod_check
drush -y @$machine.local en devel admin_devel devel_generate devel_node_access ds_devel metatag_devel
# Take Local & Prod sites out of Maintenance Mode
drush -y @$machine.local vset maintenance_mode 0
drush -y @$machine.local cc all
drush -y @$machine.prod vset maintenance_mode 0
drush -y @$machine.prod cc all
# Prepare site for Development
drush -y @$machine.local cron
drush -y @$machine.local updb
drush -y @$machine.prod cron
drush -y @$machine.prod updb
