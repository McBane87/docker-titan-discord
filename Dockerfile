FROM debian:buster-slim

ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive
ENV TZ Europe/London

RUN ln -sf /bin/bash /bin/sh

# Systemd implementation ###############################################################

ENV container docker

RUN apt-get update \
    && apt-get install -y tzdata systemd cron logrotate rsyslog bash-completion rsync \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
	
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp*
	
RUN systemctl enable rsyslog \
	&& systemctl enable cron \
	&& systemctl disable exim4

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
echo \"[\$(date +'%Y-%m-%d %H:%I:%S')] Starting Systemd...\"\n\
exec /lib/systemd/systemd\
" > /sbin/init-systemd.sh && chmod 700 /sbin/init-systemd.sh

STOPSIGNAL SIGRTMIN+3
VOLUME [ "/sys/fs/cgroup" ]
CMD ["/sbin/init-systemd.sh"]

#####################################################################################
### docker run --tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup:ro ###
#####################################################################################

# Locale ##############################################################################

RUN apt-get update && \
	apt-get install -y locales && \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
	
ENV LANG en_US.utf8

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
	apt-get install -y python3 python3-pip python3-six python3-psycopg2 rustc libssl-dev && \
	python3 -m pip install --upgrade pip && \
	python3 -m pip install -r /opt/titan/requirements.txt && \
	python3 -m pip install alembic 'eventlet<0.30' && \
	rm -rf /root/.cache && \
	apt-get purge -y python3-pip rustc libssl-dev && \
	apt-get autoremove -y && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/ /tmp/* /var/tmp/*
	
# Database #############################################################################

COPY post-pgsql.sh /etc/post-pgsql.sh

RUN apt-get update && \
	apt-get install -y postgresql redis && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/ && \
	mv /var/lib/postgresql/11/main /var/lib/pgsql && \
	ln -s /var/lib/pgsql /var/lib/postgresql/11/main && \
	systemctl enable postgresql && \
	systemctl enable redis-server && \
	mkdir /etc/titan && \
	cat /opt/titan/webapp/alembic.example.ini > /etc/titan/alembic.ini && \
	sed -i "s;^\s*sqlalchemy.url =.*$;sqlalchemy.url = postgresql://titanbot:{{psqlpw}}@localhost/titan;g" /etc/titan/alembic.ini && \
	ln -s /etc/titan/alembic.ini /opt/titan/webapp/ && \
	mkdir -p /etc/systemd/system/postgresql.service.d && \
	echo -e "[Service]\nExecStartPre=/etc/wait-pre-start.sh\nExecStartPost=/etc/post-pgsql.sh" > /etc/systemd/system/postgresql.service.d/override.conf && \
	mkdir -p /etc/systemd/system/postgresql@.service.d && \
	echo -e "[Service]\nExecStartPre=/etc/wait-pre-start.sh\nExecStartPost=/etc/post-pgsql.sh" > /etc/systemd/system/postgresql@.service.d/override.conf && \
	mkdir -p /etc/systemd/system/redis-server.service.d && \
	echo -e "[Service]\nExecStartPre=/etc/wait-pre-start.sh" > /etc/systemd/system/redis-server.service.d/override.conf && \
	chmod 775 /etc/post-pgsql.sh && \
	rm -rf /tmp/* /var/tmp/*

RUN mv /lib/systemd/system/redis-server.service /lib/systemd/system/redis-server.service.orig
COPY redis-for-docker.service /lib/systemd/system/redis-server.service

# Titan User ###########################################################################

RUN useradd -s /bin/bash -m titan

# Titan-Web ############################################################################

COPY init_web.sh /opt/titan/init_web.sh
COPY titan-default /etc/titan/titan.env
COPY titan-webapp.service /etc/systemd/system/titan-webapp.service
COPY ssl-selfsign.conf /etc/ssl/ssl-selfsign.conf
COPY titan-webapp-config.py /etc/titan/webapp-config.py

RUN apt-get update && \
	apt-get install -y gunicorn3 && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/ && \
	chmod 755 /opt/titan/init_web.sh && \
	systemctl enable titan-webapp && \
	echo "from titanembeds.app import app" > /opt/titan/webapp/run_gc.py && \
	ln -sf /etc/titan/webapp-config.py /opt/titan/webapp/config.py && \
	rm -rf /tmp/* /var/tmp/*
	
# Titan-Bot ############################################################################

COPY init_bot.sh /opt/titan/init_bot.sh
COPY titan-discord.service /etc/systemd/system/titan-discord.service
COPY titan-bot-config.py /etc/titan/discordbot-config.py

RUN chmod 755 /opt/titan/init_bot.sh && \
	systemctl enable titan-discord && \
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

