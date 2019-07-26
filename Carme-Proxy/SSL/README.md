# Certificates and Traefik

In order to use certificates in traefik one has to use key-files that are not password protected. If you use a key-file that has a password traefik cannot read it an therefore cannot varify the certificate.

To remove the password from a key-file you can use the following command
```console
# openssl rsa -in CERTNAME.key -out CERTNAME-without-password.key
```
Then it is up to you to delete the old key-file and rename the new one or edit the _traefik.toml_ in such a way that it uses the key-file that is not password protected.

