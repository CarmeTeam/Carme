import os
import subprocess
import rpyc 
from IPython.display import HTML
from IPython.display import display_html

CARME_BACKEND_SERVER=os.environ['CARME_BACKEND_SERVER']
CARME_BACKEND_PORT=os.environ['CARME_BACKEND_PORT']

"""Carme Python API

   a python module that allows users to access the carme system 

"""

def getHomePath():
    """ get the user home directory

    """
    return os.environ['HOME']

def getUserName():
    """ get the user name inside the container

    """
    return os.environ['USER']

def getSessionID():
    """ get secret session id

    """
    return os.environ['HASH']
    
def getHomeURL():
    """ get web link to Jupter Lab Entry point of this jom

    """
    return HTML('<A href="https://gpu-cluster.itwm.fraunhofer.de/nb_'+str(getSessionID())+'/">link to home</A>')

def getTensorBordURL():
    """ get web link to TensorBoard Entry Point of this job

    """
    url= 'https://gpu-cluster.itwm.fraunhofer.de/tb_'+str(getSessionID())+'/'
    return HTML('<A HREF="'+str(url)+'">'+str(url)+'</A>')

def getExcercise(course, chapter):
    repo='/home/UEBUNGEN/'+str(course)+'/'+str(chapter)
    execute= "cd "+str(getHomePath())+";git clone "+str(repo)+"; git checkout -b "+getUserName()
    #print (execute)
    os.system(execute)
    return str(getHomePath())+"/"+str(chapter)
   
def WhoAmI(): 
    """ get user authenticaton from Carme backend

    """
    user=getUserName() 
    key="/home/"+user+"/.carme/"+user+".key"
    cert="/home/"+user+"/.carme/"+user+".crt"  
    conn = rpyc.ssl_connect(CARME_BACKEND_SERVER, CARME_BACKEND_PORT, keyfile=key, certfile=cert)  
    name = conn.root.whoami()                                                                                                                                                                       
    conn.close()
    return name

def sendNotification(text):
    """ send a Mattermost message

        # Arguments
            text: message text

        # Comments
            can be used to post job status and other information
    """
    user=getUserName()
    key="/home/"+user+"/.carme/"+user+".key"
    cert="/home/"+user+"/.carme/"+user+".crt"
    text= "User Notification: "+text
    conn = rpyc.ssl_connect(CARME_BACKEND_SERVER, CARME_BACKEND_PORT, keyfile=key, certfile=cert)
    if conn.root.SendMessage(user,text) != 0:
        raise Exception("ERROR sending notification")
    conn.close()

    
def addCarmePythonPath(path, message=True):
    """ add a local path to ancaonda search path
        
        # Arguments
            path: path to module
            message: bool

        # Comments
            allows import of own modules anywhere in Carme
    """

    with open('/opt/anaconda3/lib/python3.6/site-packages/conda.pth', 'a') as file:
        file.write(str(path)+"\n")
    if (message):
        print(path + ' added to Carme python path')
        print('NOTE: this opperation has a global affect for all new kernels within this ob')
        print('NOTE: this opperation only takes effect after resetting the kernel - carme.resetKernel()')

def resetKernel():
    """ resets the kernel of a juyter notebook

    """
    display_html("<script>Jupyter.notebook.kernel.restart()</script>",raw=True)

