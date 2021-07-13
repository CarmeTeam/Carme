from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('carme', '0014_remove_unused_tables'),
    ]

    operations = [
        migrations.RenameModel(
            old_name='CarmeMessages',
            new_name='CarmeMessage',
        ),
        migrations.RenameModel(
            old_name='GroupResources',
            new_name='GroupResource',
        ),
        migrations.RenameModel(
            old_name='Images',
            new_name='Image',
        ),
        migrations.RenameModel(
            old_name='SlurmJobs',
            new_name='SlurmJob',
        ),
    ]
