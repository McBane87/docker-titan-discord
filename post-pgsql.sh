#! /usr/bin/env bash

source /etc/titan/titan.env

if [[ -f /run/psqlp.tmp && $(cat /run/psqlp.tmp) != "" ]]; then
	psqlpw=$(cat /run/psqlp.tmp)
	usrExists=$(su -c "psql postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='titanbot'\"" postgres 2>/dev/null)
	dbExists=$(su -c "psql postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='titan'\"" postgres 2>/dev/null)
	
	if [[ $usrExists == "1" ]]; then
		su -c "psql -c \"ALTER USER titanbot WITH PASSWORD '${psqlpw}'\"" postgres
	else	
		su -c "psql -c \"create role titanbot with login password '$psqlpw'\"" postgres
	fi
	
	if [[ $dbExists != "1" ]]; then
		su -c "psql -c \"create database titan owner=titanbot\"" postgres
	fi
fi

#########################################################################################

# User Part
[[ -x /etc/titan/post-pgsql.sh ]] && \
	/etc/titan/post-pgsql.sh
	
#########################################################################################

exit 0