config = {
    'bot-token': "",
    
    'database-uri': "postgresql://titanbot:{{psqlpw}}@localhost/titan",
    
    'redis-uri': "redis://",
    
    'titan-web-url': "",
    
    'titan-web-app-secret': "{{SECRET}}",
    
    'discord-bots-org-token': "",
    
    'bots-discord-pw-token': "",
    
    # Is not working, still writes to /opt/titan/discordbot/titanbot.log
    'logging-location': "/var/log/titan/discordbot.log",
    
    "sentry-dsn": "",
}