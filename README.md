# Carme installation

Carme is easy to install in...

- Linux Base Distribution
  - Ubuntu 20.04-focal, 22.04-jammy, and 24.04-noble.
  - Debian 11-bullseye, 12-bookworm.

- Devices
  - Laptops, PCs, RPis, VMs using Linux or WSL. Windows users, refer to our documentation.

    Check [Carme Install Documentation](https://docs.open-carme.org/InstallDoc/) for further details

#### Step 1: Clone the repo

**Note**: root user is required.

```
git clone -b demo-0.9.9 --single-branch https://github.com/CarmeTeam/Carme.git /opt/Carme
```

#### Step 2: Create the config file 

```
cd /opt/Carme && bash config.sh
```

#### Step 3: Run the installation script 

```
bash start.sh
```

#### Step 4: Access Carme

- Open a browser and type `localhost:10443`.
- From a remote device, use SSH tunnel, e.g., `ssh <user>@<head-node-IP> -NL 9999:localhost:10443`.
  Then, open a browser in the remote device and type `localhost:9999`.

  **Congratulations!** Carme works in your system.

#### Step 5: Use Carme 

- [Carme User Documentation](https://docs.open-carme.org/UserDoc/).
- [Carme Admin Documentation](https://docs.open-carme.org/AdminDoc/).

