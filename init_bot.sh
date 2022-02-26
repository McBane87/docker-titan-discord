#! /usr/bin/env bash

source /etc/profile

##################################################################################################
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
##################################################################################################

source /etc/titan/titan.env

[[ ! -f /run/titan/alembic.done ]] && \
	cd /opt/titan/webapp && \
	/usr/local/bin/alembic upgrade head && \
	touch /run/titan/alembic.done

cd $DIR/discordbot && exec python3 run.py
