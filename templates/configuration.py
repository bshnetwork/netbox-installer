ALLOWED_HOSTS = ['@@SERVER_FQDN@@', '@@SERVER_IP@@', 'localhost', '127.0.0.1', '@@LOCAL_NETWORK@@']

DATABASE = {
    'ENGINE': 'django.db.backends.postgresql',
    'NAME': '@@NETBOX_DB@@',
    'USER': '@@NETBOX_USER@@',
    'PASSWORD': '@@NETBOX_DB_PASSWORD@@',
    'HOST': 'localhost',
    'PORT': '',
    'CONN_MAX_AGE': 300,
}

REDIS = {
    'tasks': {
        'HOST': 'localhost',
        'PORT': 6379,
        'PASSWORD': '',
        'DATABASE': 0,
        'SSL': False,
    },
    'caching': {
        'HOST': 'localhost',
        'PORT': 6379,
        'PASSWORD': '',
        'DATABASE': 1,
        'SSL': False,
    }
}

SECRET_KEY = '@@SECRET_KEY@@'
