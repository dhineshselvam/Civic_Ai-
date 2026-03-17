from django.db import migrations

class Migration(migrations.Migration):

    dependencies = [
        ('complaints', '0014_sensitive_location_nullable_json'),
    ]

    operations = [
        migrations.RunSQL(
            sql="ALTER TABLE complaints_complaint DROP COLUMN IF EXISTS near_sensitive_location CASCADE;",
            reverse_sql=""
        )
    ]
