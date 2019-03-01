# carme

## getHomePath
```python
getHomePath()
```
get the user home directory


## getUserName
```python
getUserName()
```
get the user name inside the container


## getSessionID
```python
getSessionID()
```
get secret session id


## getHomeURL
```python
getHomeURL()
```
get web link to Jupter Lab Entry point of this jom


## getTensorBordURL
```python
getTensorBordURL()
```
get web link to TensorBoard Entry Point of this job


## WhoAmI
```python
WhoAmI()
```
get user authenticaton from Carme backend


## sendNotification
```python
sendNotification(text)
```
send a Mattermost message

__Arguments__

- __text__: message text

__Comments__

    can be used to post job status and other information

## addCarmePythonPath
```python
addCarmePythonPath(path, message=True)
```
add a local path to ancaonda search path

__Arguments__

- __path__: path to module
- __message__: bool

__Comments__

    allows import of own modules anywhere in Carme

## resetKernel
```python
resetKernel()
```
resets the kernel of a juyter notebook


