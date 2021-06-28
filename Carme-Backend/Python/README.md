# Carme Backend

The Carme backend is distributed as a python wheel file and can be installed systemwide or in a python/conda env.

## Build

To build the Carme backend module, an environment with the required dependencies has to be created.

```
# create conda env and install python and pip
conda create -n carme-backend python=3 pip
conda activate carme-backend

# install setuptools and build carme-backend
pip install --upgrade setuptools
python setup.py bdist_wheel
```

The resulting wheel file will be saved to `dist/*.whl`.

## Known errors

The following error during installation is a known problem with the ``mysqlclient`` dependency.

```
    ERROR: Command errored out with exit status 1:
     command: /home/reusch/.conda/envs/carme-backend/bin/python -c 'import sys, setuptools, tokenize; sys.argv[0] = '"'"'/tmp/pip-install-6jlzjckd/mysqlclient_48f043e64a454648aab07c445615c1aa/setup.py'"'"'; __file__='"'"'/tmp/pip-install-6jlzjckd/mysqlclient_48f043e64a454648aab07c445615c1aa/setup.py'"'"';f=getattr(tokenize, '"'"'open'"'"', open)(__file__);code=f.read().replace('"'"'\r\n'"'"', '"'"'\n'"'"');f.close();exec(compile(code, __file__, '"'"'exec'"'"'))' egg_info --egg-base /tmp/pip-pip-egg-info-kzwpawu8
         cwd: /tmp/pip-install-6jlzjckd/mysqlclient_48f043e64a454648aab07c445615c1aa/
    Complete output (15 lines):
    /bin/sh: 1: mysql_config: not found
    /bin/sh: 1: mariadb_config: not found
    /bin/sh: 1: mysql_config: not found
    mysql_config --version
    mariadb_config --version
    mysql_config --libs
    Traceback (most recent call last):
      File "<string>", line 1, in <module>
      File "/tmp/pip-install-6jlzjckd/mysqlclient_48f043e64a454648aab07c445615c1aa/setup.py", line 15, in <module>
        metadata, options = get_config()
      File "/tmp/pip-install-6jlzjckd/mysqlclient_48f043e64a454648aab07c445615c1aa/setup_posix.py", line 70, in get_config
        libs = mysql_config("libs")
      File "/tmp/pip-install-6jlzjckd/mysqlclient_48f043e64a454648aab07c445615c1aa/setup_posix.py", line 31, in mysql_config
        raise OSError("{} not found".format(_mysql_config_path))
    OSError: mysql_config not found
    ----------------------------------------
ERROR: Command errored out with exit status 1: python setup.py egg_info Check the logs for full command output.
```

The problem is, that dependencies for mysql client executables are missing. On Debian this can be solved by installing ``python-dev libmysqlclient-dev``. For other distributions other dependencies have to be installed.
