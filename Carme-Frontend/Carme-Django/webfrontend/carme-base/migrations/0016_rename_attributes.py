from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('carme-base', '0015_rename_models'),
    ]

    operations = [
        # Image
        migrations.RenameField(
            model_name='Image',
            old_name='image_name',
            new_name='name'
        ),
        migrations.RenameField(
            model_name='Image',
            old_name='image_path',
            new_name='path'
        ),
        migrations.RenameField(
            model_name='Image',
            old_name='image_group',
            new_name='group'
        ),
        migrations.RenameField(
            model_name='Image',
            old_name='image_mounts',
            new_name='flags'
        ),
        migrations.RenameField(
            model_name='Image',
            old_name='image_comment',
            new_name='comment'
        ),
        migrations.RenameField(
            model_name='Image',
            old_name='image_status',
            new_name='status'
        ),
        migrations.RenameField(
            model_name='Image',
            old_name='image_owner',
            new_name='owner'
        ),
        # GroupResource
        migrations.RenameField(
            model_name='GroupResource',
            old_name='group_name',
            new_name='name'
        ),
        migrations.RenameField(
            model_name='GroupResource',
            old_name='group_partition',
            new_name='partition'
        ),
        migrations.RenameField(
            model_name='GroupResource',
            old_name='group_default',
            new_name='default'
        ),
        migrations.RenameField(
            model_name='GroupResource',
            old_name='group_max_jobs',
            new_name='max_jobs'
        ),
        migrations.RenameField(
            model_name='GroupResource',
            old_name='group_max_nodes',
            new_name='max_nodes'
        ),
        migrations.RenameField(
            model_name='GroupResource',
            old_name='group_max_gpus_per_node',
            new_name='max_gpus_per_node'
        ),
    ]
