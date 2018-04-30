###########################
# Assistive Technology KTH
###########################

import firebase_admin
from firebase_admin import credentials
from firebase_admin import db
import pickle

default_app = firebase_admin.initialize_app(
    credentials.Certificate('../../at_stresssensor_key.json'),
    { 'databaseURL': 'https://at-stress-sensor.firebaseio.com/' }
)

def download_database(filepath=None):
    ref = db.reference('/')
    raw_data = ref.get()
    if raw_data is not None and filepath is not None:
        with open(filepath, 'wb') as fout:
            pickle.dump(raw_data, fout)
    return raw_data
