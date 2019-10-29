# **Carme**
![carme_stage](Images/Carme-Stage--dark--symmetric.jpg)


## **HPC meets interactive Data Science and Machine Learning**
**Carme (/ˈkɑːrmiː/ KAR-mee; Greek: Κάρμη) is a Jupiter moon, also giving the name for a Cluster of Jupiter moons (the carme group).**

_or in our case..._

an open source frame work to mange resources for **multiple users** running **interactive jobs (e.g. Theia-IDE or Jupyter notebooks)** on a **Cluster** of (GPU) compute nodes.


## **Follow us on Twitter** &rarr; [#OpenCarme](https://twitter.com/open_carme)


## **Carme Presentations**
* [Slides from our talk at ISC18 06/2018](https://www.researchgate.net/publication/325967129_Carme-An_Open_Source_Framework_for_Multi-User_Interactive_Machine_Learning_on_Distributed_GPU-Systems)
* [Slides from our talk at LRZ 10/2018](https://www.researchgate.net/publication/328161743_Carme-An_Open_Source_Framework_for_Multi-User_Interactive_Machine_Learning_on_Distributed_GPU-Systems)
* [Slides from ISC 06/2019](https://www.researchgate.net/publication/334319039_Carme_-An_Open_Source_Framework_for_Multi-User_Interactive_Machine_Learning_on_Distributed_GPU-Systems)


## **Carme Core Idea**
_Combine established open source ML and DS tools with HPC back-ends_
* uses containers &rarr; Singularity
* uses Theia-IDE and Jupyter Notebooks as main web based GUI-Frontends
* completely web front-end based (OS independent, no installation on user side needed)   
* uses HPC job management and scheduler &rarr; SLURM
* uses HPC data I/O technologies like ITWM’s BeeGFS  
* uses HPC maintenance and monitoring tools 
![scheme](Images/carme-run.png)


## **Key Features**
* **Open source**
  * *Carme* uses only opensource components that allow commercial usage
  * *Carme* is open source, allowing commercial usage  
* **User Management**
  * User quotas (GPU time, priority, GPUs per job, jobs per time, Disk quota)
  * Different User Roles (Quotas, right to add containers) 
* **Container Management**
  * Container store (user selects from predefined containers)
  * Adding of user defined containers
* **Scheduler**
  * Resource reservation
  * instant access for interactive jobs   
* **Data Management and I/O**
  * Redundant, global file system (BeeGFS), mounts directly into container
  * Temporary job FS on local SSDs for max performance (BeeOND) 
* **Web-Interface**
 * HTTPS and SSH (if allowed) access via proxy 
 * Web front-end (management and IDE)   

 
## **Carme Roadmap**
* [x] since 04/2018: _Carme prototype_ is up and running on our Cluster 
* [x] 03/2019: release r0.3.0 (first public release)
* [x] 07/2019: release r0.4.0
* [x] 11/2019: release r0.5.0 (latest)
* [ ] 12/2019: release r0.6.0 (development)
* [ ] 02/2020: release r0.7.0 (upcomming)


## **Carme Documentation**
Regarding the Documentation visit our *Carme* documentation at [doc.open-carme.org](http://doc.open-carme.org)


## **Who is behind Carme?**
_Carme_ is developed at the [machine learning group](http://itwm.fraunhofer.de/ml) of the [Competence Center for High Performance Computing](https://www.itwm.fraunhofer.de/en/departments/hpc.html) at [Fraunhofer ITWM](https://www.itwm.fraunhofer.de)

![](Images/FhG-ITWM.png)

NOTE: We are open for contributions!


## **Contact**
info@open-carme.org


## Sponsors
#### The development of *Carme* is finaced by research grants from

![](Images/BMBF.jpeg )
![](Images/RLP.jpg )
