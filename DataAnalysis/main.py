###########################
# Assistive Technology KTH
###########################

import json
import numpy as np
from pathlib import Path
from os import remove
import matplotlib.pyplot as plt
from sklearn.svm import SVC, SVR
from sklearn.model_selection import train_test_split
from sklearn.metrics import confusion_matrix, f1_score
import data_download as dd

DATA_FOLDER = '../../Data/'
DB_FILEPATH = DATA_FOLDER + 'db.pkl'
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

def extract_windows(user_content, data_type):
    data = user_content.get(data_type, None)
    assert data is not None, 'No data of such type for this user'
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

def get_dataset(windows):
    X = np.array([extract_sample(w) for w in windows])
    y = np.array([float(w['label']) for w in windows])
    return X, y

def dataset_from_file(filepath):
    with open(filepath) as f:
        res = json.load(f)
        windows = res['couples']
        return get_dataset(windows)

def dataset_from_db_user_content(user_content, data_type):
    return get_dataset(extract_windows(user_content, data_type))

def dataset_from_db(user_index, data_type):

    if not Path(DB_FILEPATH).is_file():
        print('Local copy of DB not found, downloading...')
        dd.download_database(filepath=DB_FILEPATH)

    db_content = unpickle(DB_FILEPATH)
    users = db_content['users']
    print("Found data from {} users".format(len(users)))

    selected_user = list(users.values())[user_index]
    subject_name = selected_user.get('first_name', '?')
    print("Subject name: ", subject_name)

    return dataset_from_db_user_content(selected_user, data_type)

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
    y_new = np.ones([abs_diff]) * y_to_dupl

    for i in range(abs_diff):
        idx = np.random.randint(X_to_dupl.shape[0], size=1)
        sample = X_to_dupl[idx]
        X_new[i] = sample

    X_new = np.concatenate((X, X_new))
    y_new = np.concatenate((y, y_new))

    return X_new, y_new

def energy_from_test_result(test_result):
    return 1.0 - ((test_result - 0.2) / 0.8)

def relative_err(a,b,eps=1e-12):
    assert a.shape == b.shape
    return np.abs(a-b) / np.maximum(eps, np.abs(a)+np.abs(b))

def clear_cached_db():
    if Path(DB_FILEPATH).is_file():
        remove(DB_FILEPATH)


###########################
# Experiments
###########################

def get_alexa_remote_stress():
    return dataset_from_db(user_index=1, data_type='data')

def get_javi_remote_stress():
    return dataset_from_db(user_index=0, data_type='data')

def get_alexa_remote_energy():
    return dataset_from_db(user_index=1, data_type='energy_data')

def get_javi_remote_energy():
    return dataset_from_db(user_index=0, data_type='energy_data')

def get_alexa_local_stress():
    return dataset_from_file(DATA_FOLDER+'alexa-20180507/dataset.json')

def get_javi_local_stress():
    return dataset_from_file(DATA_FOLDER+'javi-20180427/dataset.json')

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

def test_dataset(X, y, silent=False):

    if not silent:
        print('\nTesting dataset...')
        n_class0 = np.sum([y == NOT_STRESSED])
        n_class1 = y.shape[0] - n_class0
        print('Stressed samples (unbalanced): ', n_class1)
        print('Not stressed samples (unbalanced): ', n_class0)
        print('Ratio: ', n_class1 / n_class0)

    X, y = balance_dataset(X, y)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.33)

    if not silent:
        print('Stressed samples (balanced): ', np.sum([y == STRESSED]))
        print('Not stressed samples (balanced): ', np.sum([y == NOT_STRESSED]))
        print('Samples used for training: ', X_train.shape[0])
        print('Samples used for validation: ', X_test.shape[0])
        print('Training...')

    svm = SVC()
    svm.fit(X_train, y_train)

    if not silent:
        print('Done')

    p_train = svm.predict(X_train)
    c_train = np.sum([p_train == y_train])
    acc_train = 100.0 * c_train / X_train.shape[0]
    conf_train = confusion_matrix(y_train, p_train)
    f1_train = f1_score(y_train, p_train)

    p_test = svm.predict(X_test)
    c_test = np.sum([p_test == y_test])
    acc_test = 100.0 * c_test / X_test.shape[0]
    conf_test = confusion_matrix(y_test, p_test)
    f1_test = f1_score(y_test, p_test)

    if not silent:
        print('Accuracy (train): {}%, F1: {}'.format(round(acc_train, 2), round(f1_train, 4)))
        print('Confusion matrix (train): \n', conf_train)
        print('Accuracy (test): {}%, F1: {}'.format(round(acc_test, 2), round(f1_test, 4)))
        print('Confusion matrix (test): \n', conf_test)

    return [acc_test, f1_test]

def test_dataset_avg(X, y, trials=1000):

    print('First result:')
    test_dataset(X, y, silent=False)

    results = np.array([test_dataset(X, y, silent=True) for _ in range(trials)])
    mean_perf = np.mean(results, axis=0)

    avg_acc_test = mean_perf[0]
    avg_f1_test = mean_perf[1]
    print('\nFinal results:')
    print('avg_acc_test', avg_acc_test)
    print('avg_f1_test', avg_f1_test)

def test_model_generalization():

    # Alexa:
    X_alexa, y_alexa = get_alexa_remote_stress()

    # Javi:
    X_javi, y_javi = get_javi_local_stress()

    for i in range(2):

        if i == 0:
            print('\nTraining with Alexa, testing with Javi...')
            X_train, X_test, y_train, y_test = X_alexa, X_javi, y_alexa, y_javi
        else:
            print('\nTraining with Javi, testing with Alexa...')
            X_train, X_test, y_train, y_test = X_javi, X_alexa, y_javi, y_alexa

        X_train, y_train = balance_dataset(X_train, y_train)

        svm = SVC()
        svm.fit(X_train, y_train)

        p_train = svm.predict(X_train)
        c_train = np.sum([p_train == y_train])
        acc_train = 100.0 * c_train / X_train.shape[0]
        conf_train = confusion_matrix(y_train, p_train)
        f1_train = f1_score(y_train, p_train)

        p_test = svm.predict(X_test)
        c_test = np.sum([p_test == y_test])
        acc_test = 100.0 * c_test / X_test.shape[0]
        conf_test = confusion_matrix(y_test, p_test)
        f1_test = f1_score(y_test, p_test)

        print('Accuracy (train): {}%, F1: {}'.format(round(acc_train, 2), round(f1_train, 4)))
        print('Confusion matrix (train): \n', conf_train)
        print('Accuracy (test): {}%, F1: {}'.format(round(acc_test, 2), round(f1_test, 4)))
        print('Confusion matrix (test): \n', conf_test)

def test_composite_model():

    # Alexa:
    X_alexa, y_alexa = get_alexa_remote_stress()

    # Javi:
    X_javi, y_javi = get_javi_local_stress()

    X = np.concatenate([X_alexa, X_javi])
    y = np.concatenate([y_alexa, y_javi])
    test_dataset_avg(X, y, trials=1000)


def test_energy_model(X, y, silent=False):

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.33)

    svr = SVR()
    svr.epsilon = 1.0# / 30.0
    svr.C = 2.0# / 30.0

    svr.fit(X_train, y_train)

    p_train = svr.predict(X_train)
    p_test = svr.predict(X_test)

    mse_train = np.mean((p_train - y_train) ** 2)
    mse_test = np.mean((p_test - y_test) ** 2)

    mean_abs_err_train = np.mean(np.abs(p_train - y_train))
    mean_abs_err_test = np.mean(np.abs(p_test - y_test))

    err_rel_train = np.mean(relative_err(p_train, y_train))
    err_rel_test = np.mean(relative_err(p_test, y_test))

    if not silent:
        print('mse_train', mse_train)
        print('mse_test', mse_test)
        print('err_rel_train', err_rel_train)
        print('err_rel_test', err_rel_test)
        print('mean_abs_err_train', mean_abs_err_train)
        print('mean_abs_err_test', mean_abs_err_test)

    return [mse_test, err_rel_test, mean_abs_err_test]

def test_energy_model_avg(X, y, trials=1000):

    print('First result:')
    test_energy_model(X, y, silent=False)

    results = np.array([test_energy_model(X, y, silent=True) for _ in range(trials)])
    mean_results = np.mean(results, axis=0)

    avg_mse_test = mean_results[0]
    avg_rel_err_test = mean_results[1]
    avg_mean_abs_err_test = mean_results[2]
    print('\nFinal results:')
    print('avg_mse_test', avg_mse_test)
    print('avg_rel_err_test', avg_rel_err_test)
    print('avg_mean_abs_err_test', avg_mean_abs_err_test)


if __name__ == '__main__':

    X_javi, y_javi = get_javi_remote_energy()
    y_javi = energy_from_test_result(y_javi)*30.0

    test_energy_model_avg(X_javi, y_javi)
