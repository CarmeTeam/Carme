# Generated by Django 3.2.23 on 2023-11-27 08:41

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('projects', '0005_alter_project_classification_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='Flag',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(default='none', max_length=255, unique=True)),
                ('type', models.CharField(default='none', max_length=255)),
            ],
        ),
        migrations.CreateModel(
            name='Image',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(default='Base', max_length=255, unique=True)),
                ('type', models.CharField(default='carme', max_length=255)),
                ('path', models.CharField(default='', max_length=255)),
                ('information', models.TextField(blank=True, default='')),
                ('status', models.BooleanField(default=False)),
                ('owner', models.CharField(default='admin', max_length=50)),
            ],
        ),
        migrations.RenameField(
            model_name='accelerator',
            old_name='num_ram_per_acc',
            new_name='main_mem_per_node',
        ),
        migrations.RenameField(
            model_name='accelerator',
            old_name='num_cpus_per_acc',
            new_name='num_cpus_per_node',
        ),
        migrations.RemoveField(
            model_name='accelerator',
            name='num_total',
        ),
        migrations.AddField(
            model_name='accelerator',
            name='node_name',
            field=models.CharField(default='local', max_length=255, unique=True),
        ),
        migrations.AddField(
            model_name='accelerator',
            name='node_status',
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name='project',
            name='type',
            field=models.CharField(default='none', max_length=255),
        ),
        migrations.AddField(
            model_name='resourcetemplate',
            name='type',
            field=models.CharField(default='none', max_length=255),
        ),
        migrations.AlterField(
            model_name='accelerator',
            name='name',
            field=models.CharField(default='none', max_length=255),
        ),
        migrations.AlterField(
            model_name='accelerator',
            name='type',
            field=models.CharField(default='none', max_length=50),
        ),
        migrations.CreateModel(
            name='TemplateHasImage',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('image', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='projects.image')),
                ('resourcetemplate', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='projects.resourcetemplate')),
            ],
            options={
                'unique_together': {('resourcetemplate', 'image')},
            },
        ),
        migrations.CreateModel(
            name='ImageHasFlag',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('flag', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='projects.flag')),
                ('image', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='projects.image')),
            ],
            options={
                'unique_together': {('image', 'flag')},
            },
        ),
        migrations.AddField(
            model_name='image',
            name='image',
            field=models.ManyToManyField(through='projects.TemplateHasImage', to='projects.ResourceTemplate'),
        ),
        migrations.AddField(
            model_name='flag',
            name='flag',
            field=models.ManyToManyField(through='projects.ImageHasFlag', to='projects.Image'),
        ),
    ]