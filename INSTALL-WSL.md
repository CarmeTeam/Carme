# Carme installation on WSL

If you have [WSL](https://learn.microsoft.com/en-us/windows/wsl/) installed on your Windows machine, you can easily create a test environment for Carme.
It can currently run on Ubuntu 20.04 and Ubuntu 22.04.
Below are instructions in PowerShell to create a separate WSL distribution for Carme and then discard it afterwards.

## Ubuntu 20.04

Download the WSL tar file for Ubuntu 20.04:

```
Invoke-WebRequest https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64-wsl.rootfs.tar.gz -OutFile ubuntu-20.04-server-cloudimg-amd64-wsl.rootfs.tar.gz
```

Import the tar file as a new distribution:

```
wsl --import carme-ubuntu20.04 carme-ubuntu20.04 ubuntu-20.04-server-cloudimg-amd64-wsl.rootfs.tar.gz
wsl -d carme-ubuntu20.04
```

Enable systemd in the new distribution and then exit:

```
cat << 'EOF' >> /etc/wsl.conf
[boot]
systemd=true
EOF
exit
```

Restart the new distribution:

```
wsl --terminate carme-ubuntu20.04
wsl -d carme-ubuntu20.04
```

Add a new user in the new distribution:

```
adduser --gecos "" --disabled-password ubuntu
echo "ubuntu:password" | chpasswd
```

Clone the repository to the Carme directory:

```
git clone <repository> /opt/Carme
```

Change into the Carme directory and then start the installation:

```
cd /opt/Carme/
bash start.sh
```

Once the installation is finished, you can open [http://localhost:10443/](http://localhost:10443/) in your browser to use Carme.

Once you finish testing Carme, you can finally discard the distribution:

```
wsl --terminate carme-ubuntu20.04
wsl --unregister carme-ubuntu20.04
Remove-Item -Recurse carme-ubuntu20.04
```

## Ubuntu 22.04

Download the WSL tar file for Ubuntu 22.04:

```
Invoke-WebRequest https://cloud-images.ubuntu.com/wsl/releases/22.04/current/ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz -OutFile ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz
```

Import the tar file as a new distribution:

```
wsl --import carme-ubuntu22.04 carme-ubuntu22.04 ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz
wsl -d carme-ubuntu22.04
```

Enable systemd in the new distribution and then exit:

```
cat << 'EOF' >> /etc/wsl.conf
[boot]
systemd=true
EOF
exit
```

Restart the new distribution:

```
wsl --terminate carme-ubuntu22.04
wsl -d carme-ubuntu22.04
```

Add a new user in the new distribution:

```
adduser --gecos "" --disabled-password ubuntu
echo "ubuntu:password" | chpasswd
```

Clone the repository to the Carme directory:

```
git clone <repository> /opt/Carme
```

Change into the Carme directory and then start the installation:

```
cd /opt/Carme/
bash start.sh
```

Once the installation is finished, you can open [http://localhost:10443/](http://localhost:10443/) in your browser to use Carme.

Once you finish testing Carme, you can finally discard the distribution:

```
wsl --terminate carme-ubuntu22.04
wsl --unregister carme-ubuntu22.04
Remove-Item -Recurse carme-ubuntu22.04
```
