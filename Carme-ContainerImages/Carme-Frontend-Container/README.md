# Carme-Webfrontend Container

In order to create the singularity container containing the webfrontend you need

* to have singularity installed 
* the corresponding recipe file _"recipe--carme-frontend.recipe"_
* a valid Ubuntu 18.04 sources.list saved as _/home/root-back/SOFT/sources-list/sources--18-04.list_. Note that if it is stored at a different location or has a different name edit line 12 in _"recipe--carme-frontend.recipe"_.

At least for some singularity versions you will run into the problem that you cannot install all needed python packages via the recipe-file. Therefore, and until further notice, the creation procedure is as follows (you need to be root)

1. create a sandbox image using the recipe-file
```console
# singularity build --sandbox carme-frontend-sandbox recipe--carme-frontend.recipe
```

2. enter the sandbox
```console
# singularity shell --writable carme-frontend-sandbox
```
and install the needed python packages
```console
# pip3 install django django-auth-ldap django-auth-ldap django-bootstrap-themes django-chartjs django-classy-tags django-db-logger django-filter django-js-asset django-logtailer django-maintenance-mode django-material django-material django-mptt django-nyt django-sekizai django-settings-export django-todo django-viewflow django-viewflow mysqlclient numpy rpyc whitenoise wiki
```
Note that you have to make sure that the version of _"rpyc"_ in this image and the one installed on the headnode for the _Carme-Backend_ is the same! Otherwise it will not work.

3. create the compressed singularity image from the sandbox and delete the sandbox
```console
# singularity build carme-frontend.simg carme-frontend-sandbox
# rm -r carme-frontend-sandbox
```

4. copy the singularity image to you _login-node_ e.g.
```console
# scp carme-frontend.simg login-node:/opt/Carme-Frontend-Container
```

