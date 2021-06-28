import setuptools

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setuptools.setup(
    name="carme_backend",
    version="0.8.0",
    author="Philipp Reusch",
    author_email="reusch@itwm.fraunhofer.de",
    description="Backend server for high performance ai suite Carme.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/CarmeTeam/Carme",
    packages=['carme_backend'],
    scripts=['bin/carme-backend'],
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: Linux",
    ],
    python_requires='>=3.6',
    install_requires=[
        'ldap3',
        'mysqlclient',
        'rpyc>=5'
    ],
)
