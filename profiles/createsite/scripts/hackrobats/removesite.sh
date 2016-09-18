#!/bin/bash
#
# This script deletes virtual hosts and drupal directory.
#
# Retrieve Domain Name from command line argument OR Prompt user to enter  
if [ "$1" == "" ]; 
  then
    echo "No domain provided";
    read -p "Site domain to remove: " domain;
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
# Notify user of MySQL password requirement
echo "MySQL verification required."
# Delete Database & User
mysql -u deploy -e "drop database $machine; drop user $machine@localhost; drop user $machine@local; drop user $machine@local.hackrobats.net; flush privileges;"
sudo -u deploy ssh deploy@dev "mysql -u deploy -e 'drop database $machine; drop user $machine@localhost; drop user $machine@dev; drop user $machine@dev.hackrobats.net; flush privileges;'"
sudo -u deploy ssh deploy@prod "mysql -u deploy -e 'drop database $machine; drop user $machine@localhost; drop user $machine@prod; drop user $machine@prod.hackrobats.net;flush privileges;'"
echo "$machine database and user dropped"
# Disable sites-enabled symlink
sudo a2dissite $machine.conf
sudo -u deploy ssh deploy@dev "sudo a2dissite $machine.conf"
sudo -u deploy ssh deploy@prod "sudo a2dissite $machine.conf"
# Reload Apache2
sudo service apache2 reload
sudo -u deploy ssh deploy@dev "sudo service apache2 reload"
sudo -u deploy ssh deploy@prod "sudo service apache2 reload"
# Restart Apache2
sudo service apache2 restart
sudo -u deploy ssh deploy@dev "sudo service apache2 restart"
sudo -u deploy ssh deploy@prod "sudo service apache2 restart"
# Remove Virtual Host entry
sudo rm -R $hosts/$machine.conf
if [ -d "$hosts/$machine\.conf" ]; then
  echo "$machine\.conf directory still exists in /etc/apache2/sites-available"
fi
echo "$domain Apache2 conf disabled and removed from Local"
sudo -u deploy ssh deploy@dev "sudo rm -R $hosts/$machine.conf"
sudo -u deploy ssh deploy@dev "if [ -d "$hosts/$machine\.conf" ]; then
  echo '$machine\.conf directory still exists in /etc/apache2/sites-available'
fi"
echo "$domain Apache2 conf disabled and removed from Dev"
sudo -u deploy ssh deploy@prod "sudo rm -R $hosts/$machine.conf"
sudo -u deploy ssh deploy@prod "if [ -d "$hosts/$machine\.conf" ]; then
  echo '$machine\.conf directory still exists in /etc/apache2/sites-available'
fi"
echo "$domain Apache2 conf disabled and removed from Prod"
# Remove /etc/cron.hourly entry
cd /etc/cron.hourly
sudo rm -R $machine
if [ -d "/etc/cron.hourly/$machine" ]; then
  echo "$machine entry still exists in /etc/cron.hourly"
fi
echo "$machine entry removed from /etc/cron.hourly on Local"
sudo -u deploy ssh deploy@dev "cd /etc/cron.hourly && sudo rm -R $machine"
sudo -u deploy ssh deploy@dev "if [ -d '/etc/cron.hourly/$machine' ]; then
  echo '$machine entry still exists in /etc/cron.hourly'
fi"
echo "$machine entry removed from /etc/cron.hourly on Dev"
sudo -u deploy ssh deploy@prod "cd /etc/cron.hourly && sudo rm -R $machine"
sudo -u deploy ssh deploy@prod "if [ -d '/etc/cron.hourly/$machine' ]; then
  echo '$machine entry still exists in /etc/cron.hourly'
fi"
echo "$machine entry removed from /etc/cron.hourly on Prod"
# Remove Drush alias
cd /home/deploy/.drush && sudo rm -R $machine.aliases.drushrc.php
sudo -u deploy ssh deploy@dev "cd /home/deploy/.drush && sudo rm -R $machine.aliases.drushrc.php"
sudo -u deploy ssh deploy@prod "cd /home/deploy/.drush && sudo rm -R $machine.aliases.drushrc.php"
# Delete Docroot excluding, Destroy anything except .git & .gitignore & readme.md
cd /var/www/$domain
sudo mv /var/www/$domain/html/README.md /var/www/$domain/readme.md
sudo mv /var/www/$domain/html/readme.md /var/www/$domain/readme.md
sudo rm -R html/*
sudo mv /var/www/$domain/README.md /var/www/$domain/html/readme.md
sudo mv /var/www/$domain/readme.md /var/www/$domain/html/readme.md
# Push Changes to Github
cd /var/www/$domain/html
git status
git add . -A
git commit -a -m "Purging"
git push origin master
# Delete File Structure
cd $www
sudo rm -R $domain
if [ -d "$www/$domain" ]; then
  echo "$domain directory still exists in /var/www"
fi
echo "$domain directory removed from /var/www on Local"
sudo -u deploy ssh deploy@dev "cd $www && sudo rm -R $domain"
sudo -u deploy ssh deploy@dev "if [ -d '$www/$domain' ]; then
  echo '$domain directory still exists in /var/www'
fi"
echo "$domain directory removed from /var/www on Dev"
sudo -u deploy ssh deploy@prod "cd $www && sudo rm -R $domain"
sudo -u deploy ssh deploy@prod "if [ -d '$www/$domain' ]; then
  echo '$domain directory still exists in /var/www'
fi"
echo "$domain directory removed from /var/www on Prod"