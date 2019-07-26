# Carme-Webfrontend Container

In order to create the singularity container containing the webfrontend you need

* to have singularity installed 
* the corresponding recipe file _"recipe--carme-proxy--debian.recipe"_


1. create a singularity image using the recipe-file
```console
# singularity build carme-proxy.simg recipe--carme-proxy--debian.recipe
```

2. copy the singularity image to you _login-node_ e.g.
```console
# scp carme-proxy.simg login-node:/opt/Carme-Proxy-Container
```

