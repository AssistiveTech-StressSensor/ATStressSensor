###########################
# Assistive Technology KTH
###########################

import json
import numpy as np
from pathlib import Path
import matplotlib.pyplot as plt
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split
import data_download as dd

DB_FILEPATH = '../../Data/db.pkl'
STRESSED = 1.0
NOT_STRESSED = 0.0


###########################
# Utilities
###########################

def unpickle(filepath):
    import pickle
    with open(filepath, 'rb') as fo:
        res = pickle.load(fo, encoding='bytes')
    return res

def extract_windows(user_content):
    data = user_content['data']
    items = list(data.values())
    windows = [json.loads(item['js_data']) for item in items]
    return windows

def extract_sample(window):
    s = window['sample']
    return np.array([
        s['gsrMean'],
        s['gsrLocals'],
        s['hrMean'],
        s['hrMeanDerivative']
    ])

def get_dataset(user_content):
    windows = extract_windows(user_content)
    X = np.array([extract_sample(w) for w in windows])
    y = np.array([float(w['label']) for w in windows])
    return X, y

def balance_dataset(X, y):
    X_0, X_1 = X[y == NOT_STRESSED],  X[y == STRESSED]
    n_0, n_1 = X_0.shape[0], X_1.shape[0]

    diff = n_0 - n_1
    abs_diff = abs(diff)
    if diff == 0.0:
        return X, y

    X_to_dupl = X_0 if n_0 < n_1 else X_1
    y_to_dupl = NOT_STRESSED if n_0 < n_1 else STRESSED

    X_new = np.zeros((abs_diff, X.shape[1]))
    for i in range(abs_diff):
        idx = np.random.randint(X_to_dupl.shape[0], size=1)
        sample = X_to_dupl[idx]
        X_new[i] = sample

    X_new = np.array(X_new)
    y_new = np.ones([abs_diff]) * y_to_dupl

    X_new = np.concatenate((X, X_new))
    y_new = np.concatenate((y, y_new))

    return X_new, y_new


###########################
# Experiments
###########################

def test_signals(db_content):

    users = db_content['users']
    first_user = list(users.values())[0]
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

def main():

    if not Path(DB_FILEPATH).is_file():
        print('Local copy of DB not found, downloading...')
        dd.download_database(filepath=DB_FILEPATH)

    db_content = unpickle(DB_FILEPATH)
    users = db_content['users']
    print("Found data from {} users".format(len(users)))

    selected_user = list(users.values())[1]
    subject_name = selected_user.get('first_name', '?')
    print("Subject name: ", subject_name)

    X, y = get_dataset(selected_user)
    print('Stressed samples (unbalanced): ', np.sum([y == STRESSED]))
    print('Not stressed samples (unbalanced): ', np.sum([y == NOT_STRESSED]))

    X, y = balance_dataset(X, y)
    print('Stressed samples (balanced): ', np.sum([y == STRESSED]))
    print('Not stressed samples (balanced): ', np.sum([y == NOT_STRESSED]))

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.33)

    print('Samples used for training: ', X_train.shape[0])
    print('Samples used for validation: ', X_test.shape[0])

    print('Training...')
    svm = SVC()
    svm.fit(X_train, y_train)
    print('Done')

    p_train = svm.predict(X_train)
    c_train = np.sum([p_train == y_train])
    acc_train = 100.0 * c_train / X_train.shape[0]
    print('Accuracy (train): {}%'.format(round(acc_train, 2)))

    p_test = svm.predict(X_test)
    c_test = np.sum([p_test == y_test])
    acc_test = 100.0 * c_test / X_test.shape[0]
    print('Accuracy (test): {}%'.format(round(acc_test, 2)))

main()
