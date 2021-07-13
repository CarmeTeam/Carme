from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('carme', '0011_slurmjobs_rename_all'),
    ]

    operations = [
        migrations.AddField(
            model_name='slurmjobs',
            name='ta_port',
            field=models.IntegerField(default=-1),
        ),
    ]
