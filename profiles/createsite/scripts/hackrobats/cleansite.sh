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