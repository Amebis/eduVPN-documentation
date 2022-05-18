#!/bin/sh

#
# Deploy a VPN controller
#

###############################################################################
# CONFIGURATION
###############################################################################

MACHINE_HOSTNAME=$(hostname -f)

# DNS name of the Web Server
printf "DNS name of the Web Server [%s]: " "${MACHINE_HOSTNAME}"; read -r WEB_FQDN
WEB_FQDN=${WEB_FQDN:-${MACHINE_HOSTNAME}}
# convert hostname to lowercase
WEB_FQDN=$(echo "${WEB_FQDN}" | tr '[:upper:]' '[:lower:]')

###############################################################################
# SOFTWARE
###############################################################################

apt update

# until ALL composer.json of the packages using sqlite have "ext-sqlite3" we'll 
# install it manually here...
DEBIAN_FRONTEND=noninteractive apt install -y apt-transport-https curl \
    apache2 php-fpm pwgen iptables-persistent sudo gnupg php-sqlite3 \
    lsb-release

DEBIAN_CODE_NAME=$(/usr/bin/lsb_release -cs)
PHP_VERSION=$(/usr/sbin/phpquery -V)

cp resources/repo+v3@eduvpn.org.asc /etc/apt/trusted.gpg.d/repo+v3@eduvpn.org.asc
echo "deb https://repo.eduvpn.org/v3/deb ${DEBIAN_CODE_NAME} main" | tee /etc/apt/sources.list.d/eduVPN_v3.list

apt update

# install software (VPN packages)
DEBIAN_FRONTEND=noninteractive apt install -y vpn-server-api \
    vpn-user-portal vpn-maint-scripts

###############################################################################
# CERTIFICATE
###############################################################################

# generate self signed certificate and key
openssl req \
    -nodes \
    -subj "/CN=${WEB_FQDN}" \
    -x509 \
    -sha256 \
    -newkey rsa:2048 \
    -keyout "/etc/ssl/private/${WEB_FQDN}.key" \
    -out "/etc/ssl/certs/${WEB_FQDN}.crt" \
    -days 90

###############################################################################
# APACHE
###############################################################################

a2enmod ssl headers rewrite proxy_fcgi setenvif 
a2dismod status
a2enconf php${PHP_VERSION}-fpm

# VirtualHost
cp resources/ssl.debian.conf /etc/apache2/mods-available/ssl.conf
cp resources/vpn.example.debian.conf "/etc/apache2/sites-available/${WEB_FQDN}.conf"
cp resources/localhost.debian.conf /etc/apache2/sites-available/localhost.conf

# update hostname
sed -i "s/vpn.example/${WEB_FQDN}/" "/etc/apache2/sites-available/${WEB_FQDN}.conf"

a2enconf vpn-server-api vpn-user-portal
a2ensite "${WEB_FQDN}" localhost
a2dissite 000-default

###############################################################################
# VPN-SERVER-API
###############################################################################

# update hostname of VPN server
sed -i "s/vpn.example/${WEB_FQDN}/" "/etc/vpn-server-api/config.php"

# update the default IP ranges
sed -i "s|10.0.0.0/25|$(vpn-server-api-suggest-ip -4)|" "/etc/vpn-server-api/config.php"
sed -i "s|fd00:4242:4242:4242::/64|$(vpn-server-api-suggest-ip -6)|" "/etc/vpn-server-api/config.php"

# initialize the CA
sudo -u www-data vpn-server-api-init

###############################################################################
# VPN-USER-PORTAL
###############################################################################

# DB init
sudo -u www-data vpn-user-portal-init

###############################################################################
# UPDATE SECRETS
###############################################################################

# update internal API secrets from the defaults to something secure
SECRET_PORTAL_API=$(pwgen -s 32 -n 1)
SECRET_NODE_API=$(pwgen -s 32 -n 1)
sed -i "s|XXX-vpn-user-portal/vpn-server-api-XXX|${SECRET_PORTAL_API}|" "/etc/vpn-user-portal/config.php"
sed -i "s|XXX-vpn-user-portal/vpn-server-api-XXX|${SECRET_PORTAL_API}|" "/etc/vpn-server-api/config.php"
sed -i "s|XXX-vpn-server-node/vpn-server-api-XXX|${SECRET_NODE_API}|" "/etc/vpn-server-api/config.php"

###############################################################################
# DAEMONS
###############################################################################

systemctl enable --now php${PHP_VERSION}-fpm
# on Debian 9 we must restart php-fpm because php-libsodium gets installed as a 
# dependency which requires a restart...
systemctl restart php${PHP_VERSION}-fpm 
systemctl restart apache2

###############################################################################
# FIREWALL
###############################################################################

cp resources/firewall/controller/iptables  /etc/iptables/rules.v4
cp resources/firewall/controller/ip6tables /etc/iptables/rules.v6

systemctl enable netfilter-persistent
systemctl restart netfilter-persistent

###############################################################################
# USERS
###############################################################################

REGULAR_USER="demo"
REGULAR_USER_PASS=$(pwgen 12 -n 1)

# the "admin" user is a special user, listed by ID to have access to "admin" 
# functionality in /etc/vpn-user-portal/config.php (adminUserIdList)
ADMIN_USER="admin"
ADMIN_USER_PASS=$(pwgen 12 -n 1)

sudo -u www-data vpn-user-portal-account --add "${REGULAR_USER}" --password "${REGULAR_USER_PASS}"
sudo -u www-data vpn-user-portal-account --add "${ADMIN_USER}" --password "${ADMIN_USER_PASS}"

###############################################################################
# SHOW INFO
###############################################################################

echo "########################################################################"
echo "# Portal"
echo "#     https://${WEB_FQDN}/"
echo "#         Regular User: ${REGULAR_USER}"
echo "#         Regular User Pass: ${REGULAR_USER_PASS}"
echo "#"
echo "#         Admin User: ${ADMIN_USER}"
echo "#         Admin User Pass: ${ADMIN_USER_PASS}"
echo "########################################################################"
