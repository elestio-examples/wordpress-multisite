#set env vars
set -o allexport; source .env; set +o allexport;

echo "Waiting for WP to be ready ...";
# sleep 180s;

cat << EOF > ./installWP-CLI.sh
#install wp-cli
docker-compose exec -T wordpress bash -c "cd /tmp/ && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp;"

docker-compose exec -T wordpress bash -c "/usr/local/bin/wp core multisite-install --allow-root --title='Welcome to the WordPress' --admin_user='admin' --admin_password='${ADMIN_PASSWORD}' --admin_email='${ADMIN_EMAIL}' --url='${URL}'"

docker-compose exec -T wordpress bash -c "wp plugin install wp-super-cache --activate --allow-root --path='/var/www/html'"
docker-compose exec -T wordpress bash -c "wp plugin install wordpress-seo --activate --allow-root --path='/var/www/html'"
#docker-compose exec -T wordpress bash -c "wp plugin install elementor --activate --allow-root --path='/var/www/html'"
docker-compose exec -T wordpress bash -c "wp plugin install contact-form-7 --activate --allow-root --path='/var/www/html'"
docker-compose exec -T wordpress bash -c "wp plugin install redis-cache --activate --allow-root --path='/var/www/html'"

#set permissions
sudo chown -R www-data:www-data ./wordpress;
EOF
chmod +x ./installWP-CLI.sh;

#install now wp-cli and plugins: 
echo "Installing WP CLI & default plugins ...";
./installWP-CLI.sh;


rm -rf ./wordpress/.htaccess

cat << EOF > ./wordpress/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index.php$ - [L]

# uploaded files
RewriteRule ^([_0-9a-zA-Z-]+/)?files/(.+)  wp-includes/ms-files.php?file=\$2 [L]

# add a trailing slash to /wp-admin
RewriteRule ^([_0-9a-zA-Z-]+/)?wp-admin$ \$1wp-admin/ [R=301,L]

RewriteCond %{REQUEST_FILENAME} -f [OR]
RewriteCond %{REQUEST_FILENAME} -d
RewriteRule ^ - [L]
RewriteRule  ^([_0-9a-zA-Z-]+/)?(wp-(content|admin|includes).*) \$2 [L]
RewriteRule  ^([_0-9a-zA-Z-]+/)?(.*.php)$ \$2 [L]
RewriteRule . index.php [L]
</IfModule>
# END WordPress
EOF

sed -i "s~/\* That's all, stop editing! Happy publishing. \*/~define('WP_REDIS_HOST', '172.17.0.1');\\
define('WP_REDIS_PORT', '6379');\\
define( 'WP_REDIS_DISABLED', false );\\
\\
define('WP_SITEURL', 'https://' . \$_SERVER['HTTP_HOST']);\\
define('WP_HOME', 'https://' . \$_SERVER['HTTP_HOST']);\\
/\* That's all, stop editing! Happy publishing. \*/ \\
~g" ./wordpress/wp-config.php