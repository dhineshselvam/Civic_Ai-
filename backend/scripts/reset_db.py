import os
from django.db import connection

import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

def drop_all_tables():
    with connection.cursor() as cursor:
        cursor.execute("""
            DROP SCHEMA public CASCADE;
            CREATE SCHEMA public;
            GRANT ALL ON SCHEMA public TO postgres;
            GRANT ALL ON SCHEMA public TO public;
        """)
    print("All tables dropped and public schema reset.")

if __name__ == "__main__":
    drop_all_tables()
