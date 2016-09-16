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
    echo Domain = $1;
    domain=$1;
fi
# Retrieve Business Name from command line argument OR Prompt user to enter
if [ "$2" == "" ]; 
  then
    echo "No Business Name provided";
    read -p "Please provide user friendly Business Name: " sitename;
  else
    echo Sitename = $2;
    sitename=$2;
fi
# Retrieve Github account from command line argument OR Prompt user to enter
if [ "$3" == "" ]; 
  then
    echo "Not Github account provided";
    read -p "Please provide Github account used to create Private Repository: " github;
  else
    echo Github User = $3;
    github=$3;
fi
# Create variables from Domain Name
hosts=/etc/apache2/sites-available    # Set variable for Apache Host config
www=/var/www                          # Set variable for Drupal root directory
tld=`echo $domain  |cut -d"." -f2,3`  # Generate tld (eg .com)
name=`echo $domain |cut -f1 -d"."`    # Remove last four characters (eg .com) 
longname=`echo $name |tr '-' '_'`     # Change hyphens (-) to underscores (_)
shortname=`echo $name |cut -c -16`    # Shorten name to 16 characters for MySQL
machine=`echo $shortname |tr '-' '_'` # Replace hyphens in shortname to underscores
dbpw=$(pwgen -n 16)                   # Generate 16 character alpha-numeric password



#############################################################
#    Prepare Local Environment for Installation
#############################################################

# Clear Drush Cache
drush cc drush

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
mkdir -p /var/www/$domain/html
cd /var/www/$domain && mkdir logs private public tmp

# Initialize Git directory
cd /var/www/$domain/html
sudo -u deploy git init
sudo -u deploy git remote add origin git@github.com:/$github/$name.git
sudo -u deploy git pull origin master

# Create extra necessary Files and Directories
cd /var/www/$domain/html && mkdir -p sites/default && ln -s /var/www/$domain/public sites/default/files
cd /var/www/$domain && touch logs/access.log logs/error.log public/readme.md tmp/readme.md
cd /var/www/$domain/private && mkdir -p backup_migrate/manual backup_migrate/scheduled

# Create virtual host file on Dev, enable and restart apache
echo "<VirtualHost *:80>
        ServerAdmin maintenance@hackrobats.net
        ServerName local.$domain
        ServerAlias *.$domain $name.510interactive.com $name.hackrobats.net
        ServerAlias $name.5ten.co $name.cascadiaweb.com $name.cascadiaweb.net
        DocumentRoot /var/www/$domain/html
        ErrorLog /var/www/$domain/logs/error.log
        CustomLog /var/www/$domain/logs/access.log combined
        DirectoryIndex index.php index.html
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
\$aliases[\"local\"] = array (
  'root' => '/var/www/$domain/html',
  'uri' => 'local.$domain',
  '#name' => '$machine.local',
  '#file' => '/home/deploy/.drush/$machine.aliases.drushrc.php',
  'path-aliases' => array (
    '%drush' => '/usr/share/php/drush',
    '%dump-dir' => '/var/www/$domain/tmp',
    '%private' => '/var/www/$domain/private',
    '%files' => '/var/www/$domain/public',
    '%site' => 'sites/default/',
  ),
  'databases' => array (
    'default' => array (
      'default' => array (
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
\$aliases[\"dev\"] = array (
  'remote-host' => 'dev.hackrobats.net',
  'remote-user' => 'deploy',
  'root' => '/var/www/$domain/html',
  'uri' => 'dev.$domain',
  '#name' => '$machine.dev',
  '#file' => '/home/deploy/.drush/$machine.aliases.drushrc.php',
  'path-aliases' => array (
    '%drush' => '/usr/share/php/drush',
    '%dump-dir' => '/var/www/$domain/tmp',
    '%private' => '/var/www/$domain/private',
    '%files' => '/var/www/$domain/public',
    '%site' => 'sites/default/',
  ),
  'databases' => array (
    'default' => array (
      'default' => array (
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
\$aliases[\"prod\"] = array (
  'remote-host' => 'prod.hackrobats.net',
  'remote-user' => 'deploy',
  'root' => '/var/www/$domain/html',
  'uri' => 'www.$domain',
  '#name' => '$machine.prod',
  '#file' => '/home/deploy/.drush/$machine.aliases.drushrc.php',
  'path-aliases' => array (
    '%drush' => '/usr/share/php/drush',
    '%dump-dir' => '/var/www/$domain/tmp',
    '%private' => '/var/www/$domain/private',
    '%files' => '/var/www/$domain/public',
    '%site' => 'sites/default/',
  ),
  'databases' => array (
    'default' => array (
      'default' => array (
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

# Cleanup Permissions after installation
cd /var/www/$domain
sudo chown -R deploy:www-data html logs private public tmp
sudo chmod -R ug=rw,o=r,a+X public/* tmp/*
sudo chmod -R u=rw,go=r,a+X html/* logs/* private/*

# Create Temporary index.html to show Virtual Hosts are working
echo "<html>
  <body>
    <div>$sitename</div>
  </body>
</html>
<style>
html, body {height: 100%; width: 100%; margin: 0; padding: 0; }
div {display: block; position: relative; top: 45%; transform: translateY(-50%); font-size: 6em; text-align: center; }
</style>" > /var/www/$domain/html/index.html
echo "/var/www/$domain/html/index.html was created"

# Set owner of home directory to deploy:www-data
sudo chown -R deploy:www-data /var/www/$domain
sudo chown -R deploy:www-data /home/deploy

# Set ownership and permissions of entire site directory
cd /var/www/$domain
sudo chmod -R ug=rw,o=r,a+X public/* tmp/*
sudo chmod -R u=rw,go=r,a+X html/* logs/* private/*


#############################################################
#    Prepare Development & Production to Clone
#############################################################

# Create virtual host file on Prod, enable and restart apache
sudo -u deploy ssh deploy@dev "echo '<VirtualHost *:80>
        ServerAdmin maintenance@hackrobats.net
        ServerName dev.$domain
        ServerAlias *.$domain $name.510interactive.com $name.hackrobats.net
        ServerAlias $name.5ten.co $name.cascadiaweb.com $name.cascadiaweb.net
        DocumentRoot /var/www/$domain/html
        ErrorLog /var/www/$domain/logs/error.log
        CustomLog /var/www/$domain/logs/access.log combined
        DirectoryIndex index.php index.html
</VirtualHost>' > /etc/apache2/sites-available/$machine.conf"
sudo -u deploy ssh deploy@prod "echo '<VirtualHost *:80>
        ServerAdmin maintenance@hackrobats.net
        ServerName www.$domain
        ServerAlias *.$domain $name.510interactive.com $name.hackrobats.net
        ServerAlias $name.5ten.co $name.cascadiaweb.com $name.cascadiaweb.net
        DocumentRoot /var/www/$domain/html
        ErrorLog /var/www/$domain/logs/error.log
        CustomLog /var/www/$domain/logs/access.log combined
        DirectoryIndex index.php index.html
</VirtualHost>
<VirtualHost *:80>
        ServerName $domain
        Redirect 301 / http://www.$domain/
</VirtualHost>' > /etc/apache2/sites-available/$machine.conf"
# Create DB & user on Production
db5="CREATE DATABASE IF NOT EXISTS $machine;"
db6="GRANT ALL PRIVILEGES ON $machine.* TO $machine@local IDENTIFIED BY '$dbpw';GRANT ALL PRIVILEGES ON $machine.* TO $machine@local.hackrobats.net IDENTIFIED BY '$dbpw';"
db7="GRANT ALL PRIVILEGES ON $machine.* TO $machine@dev IDENTIFIED BY '$dbpw';GRANT ALL PRIVILEGES ON $machine.* TO $machine@dev.hackrobats.net IDENTIFIED BY '$dbpw';"
db8="GRANT ALL PRIVILEGES ON $machine.* TO $machine@prod IDENTIFIED BY '$dbpw';GRANT ALL PRIVILEGES ON $machine.* TO $machine@prod.hackrobats.net IDENTIFIED BY '$dbpw';"
db9="GRANT ALL PRIVILEGES ON $machine.* TO $machine@localhost IDENTIFIED BY '$dbpw'; FLUSH PRIVILEGES;"
sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db5\""
sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db6\""
sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db7\""
sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db8\""
sudo -u deploy ssh deploy@dev "mysql -u deploy -e \"$db9\""
sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db5\""
sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db6\""
sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db7\""
sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db8\""
sudo -u deploy ssh deploy@prod "mysql -u deploy -e \"$db9\""
# Clone site directory to Production
sudo -u deploy rsync -avzO /var/www/$domain/ deploy@dev:/var/www/$domain/
sudo -u deploy rsync -avzh /var/www/$domain/ deploy@prod:/var/www/$domain/
# Clone Drush aliases
sudo -u deploy rsync -avzO /home/deploy/.drush/$machine.aliases.drushrc.php deploy@dev:/home/deploy/.drush/$machine.aliases.drushrc.php
sudo -u deploy rsync -avzh /home/deploy/.drush/$machine.aliases.drushrc.php deploy@prod:/home/deploy/.drush/$machine.aliases.drushrc.php
# Clone Apache config & reload apache
sudo -u deploy ssh deploy@dev "sudo chown deploy:www-data /etc/apache2/sites-available/$machine.conf"
sudo -u deploy ssh deploy@dev "sudo -u deploy a2ensite $machine.conf && sudo service apache2 reload"
sudo -u deploy ssh deploy@prod "sudo chown deploy:www-data /etc/apache2/sites-available/$machine.conf"
sudo -u deploy ssh deploy@prod "sudo -u deploy a2ensite $machine.conf && sudo service apache2 reload"
# Clone cron entry
sudo -u deploy rsync -avz -e ssh /etc/cron.hourly/$machine deploy@dev:/etc/cron.hourly/$machine
sudo -u deploy ssh deploy@dev "sudo -u deploy sed -i -e 's/local./dev./g' /etc/cron.hourly/$machine"
sudo -u deploy rsync -avz -e ssh /etc/cron.hourly/$machine deploy@prod:/etc/cron.hourly/$machine
sudo -u deploy ssh deploy@prod "sudo -u deploy sed -i -e 's/local./www./g' /etc/cron.hourly/$machine"
# Set permissions
cd /var/www/$domain
sudo chmod -R ug=rw,o=r,a+X public/* tmp/*
sudo chmod -R u=rw,go=r,a+X html/* logs/* private/*
# Push changes to Git directory
cd /var/www/$domain/html
sudo -u deploy git add . -A
sudo -u deploy git commit -a -m "initial commit"
sudo -u deploy git push origin master

# Display Docroot, URLs, Sitename, Github Repo, DB User & PW
echo ""
echo "Docroot            = /var/www/$domain/html"
echo "Domain Name        = $domain"
echo "Site Name          = $sitename"
echo "Production URL     = http://www.$domain"
echo "Staging URL        = http://stage.$domain"
echo "Local URL          = http://local.$domain"
echo "Github Repository  = https://github.com/$github/$machine.git"
echo "Database Name/User = $machine"
echo "Database Password  = $dbpw"
