from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('carme', '0010_slurmjobs_remove_unused'),
    ]

    operations = [
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='IP',
            new_name='ip'
        ),
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='HASH',
            new_name='url_suffix'
        ),
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='NB_PORT',
            new_name='nb_port'
        ),
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='TB_PORT',
            new_name='tb_port'
        ),
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='GPUS',
            new_name='gpu_ids'
        ),
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='imageName',
            new_name='image_name'
        ),
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='NumNodes',
            new_name='num_nodes'
        ),
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='NumGPUs',
            new_name='num_gpus'
        ),
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='SLURM_ID',
            new_name='slurm_id'
        ),
        migrations.RenameField(
            model_name='slurmjobs',
            old_name='jobName',
            new_name='name'
        ),
    ]
