config = {
    # Create an app over here https://discordapp.com/developers/applications/me
    # and fill these fields out
    'client-id': "",
    'client-secret': "",
    'bot-token': "",
    
    # Rest API in https://developer.paypal.com/developer/applications
    'paypal-client-id': "",
    'paypal-client-secret': "",
    
    # V2 reCAPTCHA from https://www.google.com/recaptcha/admin
    'recaptcha-site-key': "",
    'recaptcha-secret-key': "",
    
    # Patreon
    'patreon-client-id': "",
    'patreon-client-secret': "",

    'app-location': "/opt/titan/webapp/",
    'app-secret': "{{SECRET}}",

    'database-uri': "postgresql://titanbot:{{psqlpw}}@localhost/titan",
    'redis-uri': "redis://",
    #'websockets-mode': "LITTERALLY None or eventlet or gevent",
    'websockets-mode': "eventlet",
    'engineio-logging': True,
    
    # https://titanembeds.com/api/webhook/discordbotsorg/vote
    'discordbotsorg-webhook-secret': "",
    
    # Sentry.io is used to track and upload errors
    "sentry-dsn": "",
    "sentry-js-dsn": "",

    #"redirect_uri": "",
}