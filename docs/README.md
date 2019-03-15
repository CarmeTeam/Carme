# *Carme*
![carme_logo](Images/carme-logo.png)

## HPC meets interactive Data Science and Machine Learning 
**Carme (/ˈkɑːrmiː/ KAR-mee; Greek: Κάρμη) is a Jupiter moon, also giving the name for a Cluster of Jupiter moons (the carme group).**

Or in our case:

an open source frame work to mange resources for **multiple users** running **interactive jobs (e.g. Jupyter notebooks)** on a **Cluster** of (GPU) compute nodes.

## [Follow us on Twitter](https://twitter.com/open_carme) : #OpenCarme

## *Carme* Presentations 
* [Slides from our talk at ISC18 6/18](https://www.researchgate.net/publication/325967129_Carme-An_Open_Source_Framework_for_Multi-User_Interactive_Machine_Learning_on_Distributed_GPU-Systems)
* [Slides from our talk at LRZ 10/18](https://www.researchgate.net/publication/328161743_Carme-An_Open_Source_Framework_for_Multi-User_Interactive_Machine_Learning_on_Distributed_GPU-Systems)

## *Carme* core idea:
**Combine established open source ML and DS tools with HPC back-ends**
* Use containers -> Singularity
* Use Jupyter Notebooks as main web based GUI-Frontend
* All web front-end (OS independent, no installation on user side needed)   
* Use HPC job management and scheduler -> SLURM
* Use HPC data I/O technology -> ITWM’s BeeGFS  
* Use HPC maintenance and monitoring tools 
![scheme](Images/carme-run.png)
## Key Features
* Open source
  * *Carme* uses only opensource components that allow commercial usage
  * *Carme* is open source, allowing commercial usage  
* User Management 
  * User quotas (GPU time, priority, GPUs per job, jobs per time, Disk quota)
  * Different User Roles (Quotas, right to add containers) 
* Container Management
  * Container store (user selects from predefined containers)
  * Adding of user defined containers
* Scheduler
  * Resource reservation (calender)
  * Job queues for large jobs and instant interactive access for small jobs   
* Data Management and I/O
  * Redundant, global file system (BeeGFS), mounts into container
  * Temporary job FS on local SSDs for max performance (BeeOND) 
* Web-Interface
 * HTTPS and SSH (if allowed) access via proxy 
 * Web front-end (management and IDE)   
 
## *Carme* Roadmap
* [x] The *Carme* prototype (beta) is currently up and running on our Cluster 
* [x] **First public beta realease is here!** -> see GitHub 
* [ ] First stable release: June 2019 (ISC SuperComputing Conference)

## *Carme* Documentation
visit *Carme* documentation project: [doc.open-carme.org](http://doc.open-carme.org)

## Who is behind *Carme*?
* *Carme* is currently developed at the machine learning group of the Fraunhofer Competence Center HPC 

[http://itwm.fraunhofer.de/ml](http://itwm.fraunhofer.de/ml)

![](Images/logo.png)

* Contact: info@open-carme.org


We are open for contributions! 

## Sponsors
#### The development of *Carme* is finaced by research grants from:

![](Images/BMBF.jpeg )
![](Images/RLP.jpg )
