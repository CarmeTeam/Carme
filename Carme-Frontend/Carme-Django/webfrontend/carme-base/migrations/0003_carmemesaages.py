# Generated by Django 2.0.4 on 2019-01-18 09:35

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('carme-base', '0002_auto_20181003_1740'),
    ]

    operations = [
        migrations.CreateModel(
            name='CarmeMesaages',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('user', models.CharField(max_length=64)),
                ('message', models.CharField(default='message', max_length=512)),
                ('color', models.CharField(default='gray', max_length=16)),
            ],
        ),
    ]