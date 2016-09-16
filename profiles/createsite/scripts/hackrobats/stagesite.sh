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
# Put Dev & Prod sites into Maintenance Mode
drush @$machine vset maintenance_mode 1 -y && drush @$machine cc all -y
# Fix File and Directory Permissions on Dev
cd /var/www/$domain/html
sudo -u deploy rm CHANGELOG.txt COPYRIGHT.txt install.php INSTALL.mysql.txt INSTALL.pgsql.txt INSTALL.sqlite.txt INSTALL.txt LICENSE.txt MAINTAINERS.txt README.txt UPGRADE.txt
cd /var/www/$domain/html/sites
sudo -u deploy rm README.txt all/modules/README.txt all/themes/README.txt
cd /var/www/$domain
sudo chown -R deploy:deploy html/* logs/*
sudo chown -R www-data:www-data public/* private/* tmp/*
sudo chmod -R ug=rw,o=r,a+X logs/* private/* public/* tmp/*
sudo chmod -R u=rw,go=r,a+X html/*
# Git steps on Development
cd /var/www/$domain/html
git add . -A
git commit -a -m "$commit"
git push origin master
# Git steps on Production
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git stash"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain/html && git pull origin master"
# Fix File and Directory Permissions on Prod
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chown -R deploy:deploy html/* logs/*"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chown -R www-data:www-data public/* private/* tmp/*"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chmod -R ug=rw,o=r,a+X logs/* private/* public/* tmp/*"
sudo -u deploy ssh deploy@prod "cd /var/www/$domain && sudo chmod -R u=rw,go=r,a+X html/*"
# Prepare site for Live Environment
drush @$machine cron -y && drush @$machine updb -y && drush @$machine cron -y
# Take Dev & Prod sites out of Maintenance Mode
drush @$machine vset maintenance_mode 0 -y && drush @$machine cc all -y
