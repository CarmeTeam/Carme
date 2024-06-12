# Carme installation

Carme is easy to install...
**Note:** Refer to our Carme Documentation for further details.

#### Step 1: Clone the repo

- `cd /opt/` (root user is required)
- `git clone -b demo-0.9.9 --single-branch https://github.com/CarmeTeam/Carme.git Carme` 

#### Step 2: Create the config file 

- `cd /opt/Carme`
- `bash config.sh` 

#### Step 3: Run the installation script 

- `cd /opt/Carme`
- `bash start.sh` 

#### Step 4: Use Carme

- Open a browser and type `localhost:10443`.
- From a remote device, use SSH tunnel, e.g., `ssh <user>@<head-node-IP> -NL 9999:localhost:10443`. 
  Then, open a browser in the remote device and type `localhost:9999`.

**Congratulations!** Carme works in your system.
