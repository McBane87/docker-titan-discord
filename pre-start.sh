#! /usr/bin/env bash

rm -rf /run/*
rm -rf /var/run/*

if [[ -f /etc/titan/titan.env ]]; then
	source /etc/titan/titan.env
else
	source /etc/titan.dist/titan.env
fi

function chUID() {
	local TARGET_USR=$1
	local TARGET_UID=$2
	
	if [[ $TARGET_USR == "" || $TARGET_UID == "" ]]; then
		return
	fi
	
	if [[ -n $TARGET_UID && $(id -u $TARGET_USR 2>/dev/null) != $TARGET_UID ]]; then
		echo "##################################################"
		echo "Configured user id of \"$TARGET_USR\" changed. Setting permissions..."
		echo "##################################################"
		find / -user $TARGET_USR -exec chown -vhR $TARGET_UID {} \; 2>/dev/null
		usermod -u $TARGET_UID $TARGET_USR 2>/dev/null
		echo "##################################################"
		echo
	fi
}

function chGID() {
	local TARGET_GRP=$1
	local TARGET_GID=$2
	
	if [[ $TARGET_GRP == "" || $TARGET_GID == "" ]]; then
		return
	fi
	
	if [[ -n $TARGET_GID && $(id -g $TARGET_GRP 2>/dev/null) != $TARGET_GID ]]; then
		echo "###################################################"
		echo "Configured group id of \"$TARGET_GRP\" changed. Setting permissions..."
		echo "###################################################"
		find / -group $TARGET_GRP -exec chgrp -vhR $TARGET_GID {} \; 2>/dev/null
		groupmod -g $TARGET_GID $TARGET_GRP 2>/dev/null
		echo "###################################################"
		echo
	fi
}

if [[ ! -d /var/lib/pgsql || -z "$(ls -A /var/lib/pgsql)" ]]; then
	rsync -a /var/lib/pgsql.dist/ /var/lib/pgsql/
fi
if [[ ! -d /var/lib/redis || -z "$(ls -A /var/lib/redis)" ]]; then
	rsync -a /var/lib/redis.dist/ /var/lib/redis/
fi
if [[ ! -d /var/log/postgresql || -z "$(ls -A /var/log/postgresql)" ]]; then
	rsync -a /var/log/postgresql.dist/ /var/log/postgresql/
fi
if [[ ! -d /var/log/redis || -z "$(ls -A /var/log/redis)" ]]; then
	rsync -a /var/log/redis.dist/ /var/log/redis/
fi

[[ ! -d /etc/titan ]] && cp -a /etc/titan.dist /etc/titan
distFiles=$(find /etc/titan.dist/ -mindepth 1 -maxdepth 1 -type f)
while read f; do
	if [[ ! -f /etc/titan/$(basename $f) ]]; then
		cp -a $f /etc/titan/
	fi
done <<< "$distFiles"

if [[ -z "$(ls -A /var/log/titan)" ]]; then
	cp -a /var/log/titan/* /var/log/titan/
fi

if [[ ! -d /etc/titan/ssl || -z "$(ls -A /etc/titan/ssl)" ]]; then
	[[ ! -d /etc/titan/ssl ]] && mkdir /etc/titan/ssl
	CONFDIR=/etc/titan
	SSLCONF=/etc/ssl/ssl-selfsign.conf
	openssl req -new \
		-newkey rsa:4096 -sha256 -nodes -keyout $CONFDIR/ssl/selfsigned.key \
		-days 99365 \
		-x509 -out $CONFDIR/ssl/selfsigned.crt \
		-config $SSLCONF
	cat $CONFDIR/ssl/selfsigned.{key,crt} > $CONFDIR/ssl/selfsigned.chain
	openssl pkcs12 -export -passout pass: \
		-in $CONFDIR/ssl/selfsigned.chain \
		-out $CONFDIR/ssl/selfsigned.pfx
fi

chown --no-dereference -R titan:titan /etc/titan/ssl

chk_psql_1=$(grep '{{psqlpw}}' /etc/titan/alembic.ini >/dev/null 2>&1)$?
chk_psql_2=$(grep '{{psqlpw}}' /etc/titan/webapp-config.py >/dev/null 2>&1)$?
chk_psql_3=$(grep '{{psqlpw}}' /etc/titan/discordbot-config.py >/dev/null 2>&1)$?

if [[ $chk_psql_1 -eq 0 && $chk_psql_2 -eq 0 && $chk_psql_3 -eq 0 ]]; then
	psqlpw=$(openssl rand -base64 10)
	echo $psqlpw > /run/psqlp.tmp
	sed -i "s;{{psqlpw}};${psqlpw};g"  /etc/titan/alembic.ini
	sed -i "s;{{psqlpw}};${psqlpw};g" /etc/titan/webapp-config.py
	sed -i "s;{{psqlpw}};${psqlpw};g" /etc/titan/discordbot-config.py
fi

chk_web_1=$(grep '{{SECRET}}' /etc/titan/webapp-config.py >/dev/null 2>&1)$?
chk_web_2=$(grep '{{SECRET}}' /etc/titan/discordbot-config.py >/dev/null 2>&1)$?

if [[ $chk_web_1 -eq 0 && $chk_web_2 -eq 0 ]]; then
	websecret=$(openssl rand -base64 10)
	sed -i "s;{{SECRET}};${websecret};g" /etc/titan/webapp-config.py
	sed -i "s;{{SECRET}};${websecret};g" /etc/titan/discordbot-config.py
fi

chUID "titan" $TITAN_UID
chGID "titan" $TITAN_GID

chUID "postgres" $POSTGRES_UID
chGID "postgres" $POSTGRES_GID

chUID "redis" $REDIS_UID
chGID "redis" $REDIS_UID

#########################################################################################

# User Part
[[ -x /etc/titan/pre-start.sh ]] && \
	/etc/titan/pre-start.sh
	
#########################################################################################

touch /run/pre-start.done