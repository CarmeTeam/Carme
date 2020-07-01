from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('carme-base', '0009_delete_runingjobs'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='slurmjobs',
            name='LDAP_ID'
        ),
        migrations.RemoveField(
            model_name='slurmjobs',
            name='URL'
        ),
        migrations.RemoveField(
            model_name='slurmjobs',
            name='comment'
        ),
        migrations.RemoveField(
            model_name='slurmjobs',
            name='imageID'
        ),
        migrations.RemoveField(
            model_name='slurmjobs',
            name='EntryNode'
        ),
    ]