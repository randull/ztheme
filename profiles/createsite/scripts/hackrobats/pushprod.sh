#!/bin/bash
#
# This script deletes virtual hosts and drupal directory.
#
# Retrieve Domain Name from command line argument OR Prompt user to enter  
if [ "$1" == "" ]; 
  then
    echo "No domain provided";
    read -p "Site domain to publish: " domain;
  else
  	echo $1;
    domain=$1;
fi
# Gather commit Notes for Github repo OR prompt the user to enter  
if [ "$2" == "" ]; 
  then
    echo "No commit notes provided";
    read -p "Please give description of planned changes: " commit;
  else
  	echo $2;
    commit=$2;
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
# Fix File and Directory Permissions on Local
cd /var/www/$domain/html
if [ -f "$www/$domain/html/README.md" ]; then
  sudo mv README.md readme.md
  echo "README.md has been changed to readme.md"
fi
if [ -f "$www/$domain/html/README.txt" ]; then
  sudo mv README.txt readme.md
  echo "README.txt has been changed to readme.md"
fi
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
# Git steps on Local
cd /var/www/$domain/html
git checkout .gitignore
git status
git add . -A
git commit -a -m "$commit"
git push origin master
# Git steps on Production
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git status"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git add . -A"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git reset --hard"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git stash"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git stash drop"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git checkout -- ."
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git pull origin master"
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
# Take Local & Prod sites out of Maintenance Mode and Clear Cache
drush -y @$machine.local vset maintenance_mode 0
drush -y @$machine.local cc all
drush -y @$machine.prod vset maintenance_mode 0
drush -y @$machine.prod cc all
# Prepare site for Maintenance
cd /var/www/$domain/html
drush -y @$machine.local en admin_devel devel_generate devel_node_access ds_devel metatag_devel devel
drush -y @$machine.local dis cdn googleanalytics honeypot_entityform honeypot prod_check
drush -y @$machine.prod en cdn googleanalytics honeypot_entityform honeypot prod_check
drush -y @$machine.prod dis admin_devel devel_generate devel_node_access ds_devel metatag_devel devel
# Prepare site for Live Environment
drush -y @$machine.local cron
drush -y @$machine.local updb
drush -y @$machine.prod cron
drush -y @$machine.prod updb
