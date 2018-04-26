import firebase_admin
from firebase_admin import credentials
from firebase_admin import db

cred = credentials.Certificate('../../at_stresssensor_key.json')
default_app = firebase_admin.initialize_app(cred,{
    'databaseURL': 'https://at-stress-sensor.firebaseio.com/'
})

ref = db.reference('/')

# This downloads the entire database from Firebase
raw_data = ref.get()



###########################
###########################
# Some experiments...
###########################

import json
import numpy as np
import matplotlib.pyplot as plt
import sklearn

users = raw_data['users']
first_user = list(users.values())[0] #users[users.keys()[0]]
first_user_data = first_user['data']
raw_window = list(first_user_data.values())[0]['js_data']
window = json.loads(raw_window)

snapshot = window['snapshot']
gsr_samples = snapshot['gsr_samples']
hr_samples = snapshot['hr_samples']

gsr_times = np.linspace(0,100,len(gsr_samples))
hr_times = np.linspace(0,100,len(hr_samples))


plt.figure()
plt.subplot(2,1,1)
plt.plot(gsr_times, gsr_samples)

plt.subplot(2,1,2)
plt.plot(hr_times, hr_samples)
plt.show()
