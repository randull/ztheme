#!/bin/bash
#
# This script Creates Apache Config, DB & DB User, and empty directory within /var/www on Dev and Prod
# Also Generates Drupal site using custom Installation Profile on Dev & Clones it to Prod
#
# Retrieve Domain Name from command line argument OR Prompt user to enter
if [ "$1" == "" ]; 
  then
    echo "No domain provided";
    read -p "Site domain to generate: " domain;
  else
    echo $1;
    domain=$1;
fi
# Retrieve Business Name from command line argument OR Prompt user to enter
if [ "$2" == "" ]; 
  then
    echo "No Business Name provided";
    read -p "Please provide user friendly Business Name: " sitename;
  else
    echo $2;
    sitename=$2;
fi
# Prompt user to enter Password for User1(Hackrobats)
while true
do
    read -s -p "User1 Password: " drupalpass
    echo
    read -s -p "User1 Password (again): " drupalpass2
    echo
    [ "$drupalpass" = "$drupalpass2" ] && break
    echo "Please try again"
done
echo "Password Matches"
# Create variables from Domain Name
hosts=/etc/apache2/sites-available    # Set variable for Apache Host config
www=/var/www                          # Set variable for Drupal root directory
tld=`echo $domain  |cut -d"." -f2,3`  # Generate tld (eg .com)
name=`echo $domain |cut -f1 -d"."`    # Remove last for characters (eg .com) 
longname=`echo $name |tr '-' '_'`     # Change hyphens (-) to underscores (_)
shortname=`echo $name |cut -c -16`    # Shorten name to 16 characters for MySQL
machine=`echo $shortname |tr '-' '_'` # Replace hyphens in shortname to underscores
dbpw=$(pwgen -n 16)                   # Generate 16 character alpha-numeric password



#############################################################
#    Prepare Local Environment for Installation
#############################################################

# Create database and user
db0="CREATE DATABASE IF NOT EXISTS $machine;"
db1="GRANT ALL PRIVILEGES ON $machine.* TO $machine@local IDENTIFIED BY '$dbpw'; GRANT ALL PRIVILEGES ON $machine.* TO $machine@local.hackrobats.net IDENTIFIED BY '$dbpw';"
db2="GRANT ALL PRIVILEGES ON $machine.* TO $machine@dev IDENTIFIED BY '$dbpw'; GRANT ALL PRIVILEGES ON $machine.* TO $machine@dev.hackrobats.net IDENTIFIED BY '$dbpw';"
db3="GRANT ALL PRIVILEGES ON $machine.* TO $machine@prod IDENTIFIED BY '$dbpw'; GRANT ALL PRIVILEGES ON $machine.* TO $machine@prod.hackrobats.net IDENTIFIED BY '$dbpw';"
db4="GRANT ALL PRIVILEGES ON $machine.* TO $machine@localhost IDENTIFIED BY '$dbpw'; FLUSH PRIVILEGES;"
mysql -u deploy -e "$db0"
mysql -u deploy -e "$db1"
mysql -u deploy -e "$db2"
mysql -u deploy -e "$db3"
mysql -u deploy -e "$db4"
# Create directories necessary for Drupal installation
cd /var/www && sudo mkdir $domain && sudo chown -R deploy:www-data $domain
cd /var/www/$domain && sudo mkdir html logs private public tmp && sudo chown -R deploy:www-data html logs private public tmp
cd /var/www/$domain/html && sudo mkdir -p sites/default && sudo ln -s /var/www/$domain/public sites/default/files
cd /var/www/$domain/html && sudo mkdir -p scripts/hackrobats && sudo mkdir -p profiles/hackrobats
cd /var/www/$domain && sudo touch logs/access.log logs/error.log public/readme.md tmp/readme.md
cd /var/www/$domain/private && sudo mkdir -p backup_migrate/manual backup_migrate/scheduled
cd /var/www/$domain && sudo chown -R deploy:www-data html logs private public tmp && sudo chmod 775 html logs private public tmp
sudo chmod -R u=rw,go=r,a+X html/*
sudo chmod -R ug=rw,o=r,a+X logs/* private/* public/* tmp/*
# Create virtual host file on Dev, enable and restart apache
echo "<VirtualHost *:80>
        ServerAdmin maintenance@hackrobats.net
        ServerName local.$domain
        ServerAlias *.$domain $name.510interactive.com $name.hackrobats.net
        ServerAlias $name.5ten.co $name.cascadiaweb.com $name.cascadiaweb.net
        DocumentRoot /var/www/$domain/html
        ErrorLog /var/www/$domain/logs/error.log
        CustomLog /var/www/$domain/logs/access.log combined
        DirectoryIndex index.php
</VirtualHost>" > /etc/apache2/sites-available/$machine.conf
sudo chown deploy:www-data /etc/apache2/sites-available/$machine.conf
sudo a2ensite $machine.conf && sudo service apache2 reload
# Create /etc/cron.hourly entry
echo "#!/bin/bash
/usr/bin/wget -O - -q -t 1 http://local.$domain/sites/all/modules/elysia_cron/cron.php?cron_key=$machine" > /etc/cron.hourly/$machine
sudo chown deploy:www-data /etc/cron.hourly/$machine
sudo chmod 775 /etc/cron.hourly/$machine
# Create Drush Aliases
echo "<?php
\$aliases[\"local\"] = array(
  'root' => '/var/www/$domain/html',
  'uri' => 'http://local.$domain',
  '#name' => '$machine.local',
  '#file' => '/home/deploy/.drush/$machine.aliases.drushrc.php',
  'path-aliases' => 
  array (
    '%dump-dir' => '/var/www/$domain/tmp',
    '%private' => '/var/www/$domain/private',
    '%files' => '/var/www/$domain/public',
  ),
  'databases' =>
  array (
    'default' =>
    array (
      'default' =>
      array (
        'database' => '$machine',
        'username' => '$machine',
        'password' => '$dbpw',
        'host' => 'localhost',
        'port' => '',
        'driver' => 'mysql',
        'prefix' => '',
      ),
    ),
  ),
);
\$aliases[\"dev\"] = array(
  'root' => '/var/www/$domain/html',
  'uri' => 'http://dev.$domain',
  '#name' => '$machine.dev',
  '#file' => '/home/deploy/.drush/$machine.aliases.drushrc.php',
  'path-aliases' => 
  array (
    '%dump-dir' => '/var/www/$domain/tmp',
    '%private' => '/var/www/$domain/private',
    '%files' => '/var/www/$domain/public',
  ),
  'databases' =>
  array (
    'default' =>
    array (
      'default' =>
      array (
        'database' => '$machine',
        'username' => '$machine',
        'password' => '$dbpw',
        'host' => 'localhost',
        'port' => '',
        'driver' => 'mysql',
        'prefix' => '',
      ),
    ),
  ),
);
\$aliases[\"prod\"] = array(
  'root' => '/var/www/$domain/html',
  'uri' => 'http://www.$domain',
  '#name' => '$machine.prod',
  '#file' => '/home/deploy/.drush/$machine.aliases.drushrc.php',
  'path-aliases' => 
  array (
    '%dump-dir' => '/var/www/$domain/tmp',
    '%private' => '/var/www/$domain/private',
    '%files' => '/var/www/$domain/public',
  ),
  'databases' =>
  array (
    'default' =>
    array (
      'default' =>
      array (
        'database' => '$machine',
        'username' => '$machine',
        'password' => '$dbpw',
        'host' => 'localhost',
        'port' => '',
        'driver' => 'mysql',
        'prefix' => '',
      ),
    ),
  ),
);" > /home/deploy/.drush/$machine.aliases.drushrc.php
sudo chmod 664  /home/deploy/.drush/$machine.aliases.drushrc.php
sudo chown deploy:www-data /home/deploy/.drush/$machine.aliases.drushrc.php
# Initialize Git directory
cd /var/www/$domain/html
sudo -u deploy git init
sudo -u deploy git remote add origin git@github.com:/randull/$name.git
sudo -u deploy git pull origin master
# Create site structure using Drush Make
cd /var/www/$domain/html
drush make https://raw.github.com/randull/createsite/master/createsite.make -y



#############################################################
#    Install Drupal on Local
#############################################################

# Deploy site using Drush Site-Install
drush si createsite --db-url="mysql://$machine:$dbpw@localhost/$machine" --site-name="$sitename" --account-name="hackrobats" --account-pass="$drupalpass" --account-mail="maintenance@hackrobats.net" -y
# Remove Drupal Install files after installation
cd /var/www/$domain/html
sudo -u deploy rm -f CHANGELOG.txt COPYRIGHT.txt INSTALL.mysql.txt INSTALL.pgsql.txt INSTALL.sqlite.txt INSTALL.txt LICENSE.txt MAINTAINERS.txt README.txt UPGRADE.txt
cd /var/www/$domain/html/sites
sudo -u deploy rm -f example.sites.php README.txt all/modules/README.txt all/themes/README.txt default/default.settings.php
sudo chown -R deploy:www-data all default
sudo chmod 755 all default
sudo chmod 644 /var/www/$domain/html/sites/default/settings.php
#sudo chmod 644 /var/www/$domain/public/.htaccess
#sudo -u deploy rm -R all/libraries/plupload/examples
# Prohibit Search Engines from Flagging
#echo "
## Prohibit Search Engines from randomly Flagging/Unflagging content
#Disallow: /flag/" >> /var/www/$domain/html/robots.txt
# Enable Xtheme and set default
#drush cc all && cd /var/www/$domain/html/sites/all/themes/xtheme
#npm install
#grunt sass
# Set owner of entire directory to deploy:www-data
#cd /var/www
#sudo chown -R deploy:www-data $domain
#sudo chown -R deploy:www-data /home/deploy
# Set Cron Key & Private File Path
#cd /var/www/$domain/html
#drush vset cron_key $machine
#drush vset cron_safe_threshold 0
#drush vset error_level 0
#drush vset file_private_path /var/www/$domain/private
#drush vset file_temporary_path /var/www/$domain/tmp
#drush vset jquery_update_jquery_cdn "google"
#drush vset jquery_update_jquery_version "1.8"
#drush vset prod_check_sitemail "maintenance@hackrobats.net"
#drush vset maintenance_mode 1

#drush en advanced_help -y

#drush php-eval 'node_access_rebuild();'



#############################################################
#    Prepare Development & Production to Clone
#############################################################

# Create virtual host file on Prod, enable and restart apache
#sudo -u deploy ssh deploy@dev "echo '<VirtualHost *:80>
#        ServerAdmin maintenance@hackrobats.net
#        ServerName dev.$domain
#        ServerAlias *.$domain $name.510interactive.com $name.hackrobats.net
#        ServerAlias $name.5ten.co $name.cascadiaweb.com $name.cascadiaweb.net
#        DocumentRoot /var/www/$domain/html
#        ErrorLog /var/www/$domain/logs/error.log
#        CustomLog /var/www/$domain/logs/access.log combined
#        DirectoryIndex index.php
#</VirtualHost>' > /etc/apache2/sites-available/$machine.conf"
#sudo -u deploy ssh deploy@prod "echo '<VirtualHost *:80>
#        ServerAdmin maintenance@hackrobats.net
#        ServerName www.$domain
#        ServerAlias *.$domain $name.510interactive.com $name.hackrobats.net
#        ServerAlias $name.5ten.co $name.cascadiaweb.com $name.cascadiaweb.net
#        DocumentRoot /var/www/$domain/html
#        ErrorLog /var/www/$domain/logs/error.log
#        CustomLog /var/www/$domain/logs/access.log combined
#        DirectoryIndex index.php
#</VirtualHost>
#<VirtualHost *:80>
#        ServerName $domain
#        Redirect 301 / http://www.$domain/
#</VirtualHost>' > /etc/apache2/sites-available/$machine.conf"
# Create DB & user on Production
#db5="CREATE DATABASE IF NOT EXISTS $machine;"
#db6="GRANT ALL PRIVILEGES ON $machine.* TO $machine@local IDENTIFIED BY '$dbpw';GRANT ALL PRIVILEGES ON $machine.* TO $machine@local.hackrobats.net IDENTIFIED BY '$dbpw';"
#db7="GRANT ALL PRIVILEGES ON $machine.* TO $machine@dev IDENTIFIED BY '$dbpw';GRANT ALL PRIVILEGES ON $machine.* TO $machine@dev.hackrobats.net IDENTIFIED BY '$dbpw';"
#db8="GRANT ALL PRIVILEGES ON $machine.* TO $machine@prod IDENTIFIED BY '$dbpw';GRANT ALL PRIVILEGES ON $machine.* TO $machine@prod.hackrobats.net IDENTIFIED BY '$dbpw';"
#db9="GRANT ALL PRIVILEGES ON $machine.* TO $machine@localhost IDENTIFIED BY '$dbpw'; FLUSH PRIVILEGES;"
#sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db5\""
#sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db6\""
#sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db7\""
#sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db8\""
#sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db9\""
#sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db5\""
#sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db6\""
#sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db7\""
#sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db8\""
#sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db9\""
# Clone site directory to Production
#sudo -u deploy rsync -avzh /var/www/$domain/ deploy@dev:/var/www/$domain/
#sudo -u deploy rsync -avzh /var/www/$domain/ deploy@prod:/var/www/$domain/
# Clone Drush aliases
#sudo -u deploy rsync -avzh /home/deploy/.drush/$machine.aliases.drushrc.php deploy@dev:/home/deploy/.drush/$machine.aliases.drushrc.php
#sudo -u deploy rsync -avzh /home/deploy/.drush/$machine.aliases.drushrc.php deploy@prod:/home/deploy/.drush/$machine.aliases.drushrc.php
# Clone Apache config & reload apache
#sudo -u deploy ssh deploy@dev "sudo chown deploy:www-data /etc/apache2/sites-available/$machine.conf"
#sudo -u deploy ssh deploy@dev "sudo -u deploy a2ensite $machine.conf && sudo service apache2 reload"
#sudo -u deploy ssh deploy@prod "sudo chown deploy:www-data /etc/apache2/sites-available/$machine.conf"
#sudo -u deploy ssh deploy@prod "sudo -u deploy a2ensite $machine.conf && sudo service apache2 reload"
# Clone DB
#drush sql-sync @$machine.local @$machine.dev -y
#drush sql-sync @$machine.local @$machine.prod -y
# Clone cron entry
#sudo -u deploy rsync -avz -e ssh /etc/cron.hourly/$machine deploy@dev:/etc/cron.hourly/$machine
#sudo -u deploy ssh deploy@dev "sudo -u deploy sed -i -e 's/local./dev./g' /etc/cron.hourly/$machine"
#sudo -u deploy rsync -avz -e ssh /etc/cron.hourly/$machine deploy@prod:/etc/cron.hourly/$machine
#sudo -u deploy ssh deploy@prod "sudo -u deploy sed -i -e 's/local./www./g' /etc/cron.hourly/$machine"
# Set permissions
cd /var/www/$domain
sudo chmod -R ug=rw,o=r,a+X public/* tmp/*
sudo chmod -R u=rw,go=r,a+X html/* logs/* private/*
# Clear Drupal cache, update database, run cron
drush -y @$machine.local cc all && drush -y @$machine.local updb && drush -y @$machine.local cron
# Push changes to Git directory
sudo -u deploy git add . -A
sudo -u deploy git commit -a -m "initial commit"
sudo -u deploy git push origin master
# Prepare site for Maintenance
#cd /var/www/$domain/html
#drush @$machine.local pm-disable cdn googleanalytics google_analytics hidden_captcha honeypot_entityform honeypot prod_check -y
#drush @$machine.dev pm-disable cdn googleanalytics google_analytics hidden_captcha honeypot_entityform honeypot prod_check -y
#drush @$machine.prod pm-disable admin_devel devel_generate devel_node_access ds_devel metatag_devel devel -y
# Prepare site for Live Environment
#drush @$machine.local cron -y && drush @$machine.local updb -y && drush @$machine.local cron -y
# Take Dev & Prod sites out of Maintenance Mode
drush @$machine.local vset maintenance_mode 0 -y && drush @$machine.local cc all -y
