# ---------------------------------------------- 
# Carme
# ----------------------------------------------
# dbrouters.py                                                                                                                                                                     
#                                                                                                                                                                                                            
# see Carme development guide for documentation: 
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
#
# Copyright 2019 by Fraunhofer ITWM  
# License: http://open-carme.org/LICENSE.md 
# Contact: info@open-carme.org
# ---------------------------------------------
from .models import CarmeJobTable, CarmeAssocTable

""" db drivers for accessing external dbs

"""
class MyDBRouter(object):
    """ read only access to the slum db

    """
    def db_for_read(self, model, **hints):
        """ reading SomeModel from otherdb """
        if model == CarmeJobTable:
            return 'slurm'
        elif model == CarmeAssocTable:
            return 'slurm'
        return None
