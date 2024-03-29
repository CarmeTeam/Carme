# Generated by Django 4.1.5 on 2023-01-26 00:00

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('projects', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='Accelerator',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=255, unique=True)),
                ('type', models.CharField(default='NONE', max_length=50)),
                ('num_total', models.IntegerField(default=0)),
                ('num_per_node', models.IntegerField(default=0)),
                ('num_cpus_per_acc', models.IntegerField(default=0)),
                ('num_ram_per_acc', models.IntegerField(default=0)),
            ],
        ),
        migrations.CreateModel(
            name='ProjectHasTemplate',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('project', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='projects.project')),
            ],
        ),
        migrations.CreateModel(
            name='ResourceTemplate',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=255, unique=True)),
                ('maxjobs', models.IntegerField(default=4)),
                ('maxnodes_per_job', models.CharField(default='1', max_length=50)),
                ('maxaccels_per_node', models.CharField(default='1', max_length=50)),
                ('walltime', models.IntegerField(default=3)),
                ('partition', models.CharField(max_length=255)),
                ('features', models.TextField(blank=True, default='')),
                ('template', models.ManyToManyField(through='projects.ProjectHasTemplate', to='projects.project')),
            ],
        ),
        migrations.CreateModel(
            name='TemplateHasAccelerator',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('accelerator', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='projects.accelerator')),
                ('resourcetemplate', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='projects.resourcetemplate')),
            ],
            options={
                'unique_together': {('resourcetemplate', 'accelerator')},
            },
        ),
        migrations.AddField(
            model_name='projecthastemplate',
            name='template',
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='projects.resourcetemplate'),
        ),
        migrations.AddField(
            model_name='accelerator',
            name='accelerator',
            field=models.ManyToManyField(through='projects.TemplateHasAccelerator', to='projects.resourcetemplate'),
        ),
        migrations.AlterUniqueTogether(
            name='projecthastemplate',
            unique_together={('project', 'template')},
        ),
    ]
