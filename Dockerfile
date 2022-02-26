FROM debian:bullseye-slim

ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive
ENV TZ Europe/London

RUN ln -sf /bin/bash /bin/sh

# Supervisor implementation ###############################################################

ENV container docker

RUN apt-get update \
    && apt-get install -y tzdata cron logrotate supervisor bash-completion rsync \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Careful! Docker remove Lines with leading '#', even if they are inside an echo statement!	
RUN mkdir /etc/pre.systemd.d && echo -e "#!/bin/bash\n\
\n\
[[ -n $TZ ]] && echo \"[\$(date +'%Y-%m-%d %H:%I:%S')] Setting timezone...\" && ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone\n\
\n\
if [ -d /etc/pre.systemd.d ]; then\n\
    for i in /etc/pre.systemd.d/*.sh ; do\n\
        if [ -r \"\$i\" ]; then\n\
                /bin/bash \"\$i\" \n\
        fi\n\
    done\n\
fi\n\
\n\
/etc/rc.local &\n\
\n\
echo \"[\$(date +'%Y-%m-%d %H:%I:%S')] Starting Supervisord...\"\n\
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n\
" > /sbin/init.sh && chmod 700 /sbin/init.sh

CMD ["/sbin/init.sh"]

COPY sv-cron.conf /etc/supervisor/conf.d/cron.conf
COPY sv-pgsql.conf /etc/supervisor/conf.d/pgsql.conf
COPY sv-redis.conf /etc/supervisor/conf.d/redis.conf
COPY sv-titan.conf /etc/supervisor/conf.d/titan.conf

RUN mkdir /etc/supervisor/init.d
COPY sv-pgsql.init /etc/supervisor/init.d/pgsql
COPY sv-redis.init /etc/supervisor/init.d/redis
COPY sv-titan.init /etc/supervisor/init.d/titan

# Locale ##############################################################################

RUN apt-get update && \
	nice -n19 apt-get install -y locales && \
	localedef -i en_GB -c -f UTF-8 -A /usr/share/locale/locale.alias en_GB.UTF-8 && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/*
	
ENV LANG en_GB.UTF-8

# PreStart-Script #######################################################################

COPY pre-start.sh /etc/pre-start.sh
COPY wait-pre-start.sh /etc/wait-pre-start.sh

RUN chmod 755 /etc/pre-start.sh && \
	echo -e "#! /usr/bin/env bash\n\n/etc/pre-start.sh" > /etc/rc.local && \
	chmod 755 /etc/rc.local && \
	chmod 755 /etc/wait-pre-start.sh
	

# Busybox ##############################################################################

ENV PATH="${PATH}:/xbin"

RUN apt-get update && \
	apt-get install -y busybox  && \
	mkdir /xbin && /bin/busybox --install -s /xbin && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/ /tmp/* /var/tmp/*

# Titenembed Git-DL ####################################################################

RUN apt-get update && \
	apt-get install -y git  && \
	cd /opt && git clone https://github.com/TitanEmbeds/Titan.git titan && \
	cd titan && git reset --hard 8d7bc145fda6e9cb0b2cfe468f48663815d0ff8c && \
	apt-get purge -y git && \
	apt-get autoremove -y && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/ /tmp/* /var/tmp/*
	
########################################################################################
	
# Python ###############################################################################

# python3-six and python3-psycopg2 are gone again, 
# once we uninstall python3-pip. So we have to install them explicitly.

RUN apt-get update && \
	apt-get install -y python3 python3-pip python3-six python3-psycopg2 && \
	pip3 install -r /opt/titan/requirements.txt && \
	pip3 install alembic 'eventlet<0.30' && \
	rm -rf /root/.cache && \
	apt-get purge -y python3-pip && \
	apt-get autoremove -y && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/ /tmp/* /var/tmp/*
	
# Database #############################################################################

COPY post-pgsql.sh /etc/post-pgsql.sh

RUN apt-get update && \
	apt-get install -y postgresql redis && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/ && \
	sed -i 's/^daemonize yes/daemonize no/g' /etc/redis/redis.conf && \
	mv /var/lib/postgresql/13/main /var/lib/pgsql && \
	ln -s /var/lib/pgsql /var/lib/postgresql/13/main && \
	mkdir /etc/titan && \
	cat /opt/titan/webapp/alembic.example.ini > /etc/titan/alembic.ini && \
	sed -i "s;^\s*sqlalchemy.url =.*$;sqlalchemy.url = postgresql://titanbot:{{psqlpw}}@localhost/titan;g" /etc/titan/alembic.ini && \
	ln -s /etc/titan/alembic.ini /opt/titan/webapp/ && \
	chmod 775 /etc/post-pgsql.sh && \
	rm -rf /tmp/* /var/tmp/*

# Titan User ###########################################################################

RUN useradd -s /bin/bash -m titan

# Titan-Web ############################################################################

COPY init_web.sh /opt/titan/init_web.sh
COPY titan-default /etc/titan/titan.env
COPY ssl-selfsign.conf /etc/ssl/ssl-selfsign.conf
COPY titan-webapp-config.py /etc/titan/webapp-config.py

RUN apt-get update && \
	apt-get install -y gunicorn3 && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/ && \
	chmod 755 /opt/titan/init_web.sh && \
	echo "from titanembeds.app import app" > /opt/titan/webapp/run_gc.py && \
	ln -sf /etc/titan/webapp-config.py /opt/titan/webapp/config.py && \
	rm -rf /tmp/* /var/tmp/*
	
# Titan-Bot ############################################################################

COPY init_bot.sh /opt/titan/init_bot.sh
COPY titan-bot-config.py /etc/titan/discordbot-config.py

RUN chmod 755 /opt/titan/init_bot.sh && \
	ln -sf /etc/titan/discordbot-config.py /opt/titan/discordbot/config.py && \
	if [[ ! -d /var/log/titan ]]; then \
		mkdir /var/log/titan && \
		chown titan:titan /var/log/titan \
	;fi && \
	touch /var/log/titan/discordbot.log && \
	chown titan:titan /var/log/titan/discordbot.log && \
	ln -sf /var/log/titan/discordbot.log /opt/titan/discordbot/titanbot.log && \
	rm -rf /tmp/* /var/tmp/*
	

########################################################################################

RUN mv /etc/titan /etc/titan.dist && \
	mv /var/log/titan /var/log/titan.dist && \
	mkdir /var/log/titan && \
	chown titan:titan /var/log/titan && \
	mv /var/lib/pgsql /var/lib/pgsql.dist && \
	mv /var/lib/redis /var/lib/redis.dist && \
	mv /var/log/postgresql /var/log/postgresql.dist && \
	mv /var/log/redis /var/log/redis.dist
	
	

########################################################################################
	
VOLUME /etc/titan
VOLUME /var/lib/pgsql
VOLUME /var/lib/redis
VOLUME /var/log/titan
VOLUME /var/log/postgresql
VOLUME /var/log/redis

EXPOSE 8080

