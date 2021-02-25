#! /usr/bin/env bash

##################################################################################################
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
##################################################################################################

if [[ $1 == "stop" ]]; then
        MAINPID=$2
        if [[ $MAINPID != '' ]]; then
                kill -SIGINT $MAINPID 2>/dev/null
                kill -9 -- -$(/bin/ps -o pgid= $MAINPID | /bin/grep -o '[0-9]*') 2>/dev/null
        else
                MAINPID=$(cat /run/titan/webapp.pid 2>/dev/null)
                if [[ $MAINPID != '' ]]; then
                        kill -SIGINT $MAINPID 2>/dev/null
                        kill -9 -- -$(/bin/ps -o pgid= $MAINPID | /bin/grep -o '[0-9]*') 2>/dev/null
                else
                        echo "ERROR wasn't able to get PID of process! Can't stop"
                        exit 1
                fi
        fi
        exit 0
fi

source /etc/titan/titan.env

[[ ! -f /run/titan/alembic.done ]] && \
	cd /opt/titan/webapp && \
	/usr/local/bin/alembic upgrade head && \
	touch /run/titan/alembic.done

cd $DIR/webapp && gunicorn3 run_gc:app &

PID=$!
EX=$?
echo $PID > /run/titan/webapp.pid

exit $EX