###########################
# Assistive Technology KTH
###########################

import json
import numpy as np
from pathlib import Path
from os import remove
import matplotlib.pyplot as plt
import pandas as pd
from sklearn.svm import SVC, SVR
from sklearn.model_selection import train_test_split, cross_val_score, cross_val_predict
from sklearn.metrics import confusion_matrix, f1_score, r2_score, accuracy_score, mean_squared_error
import data_download as dd

DATA_FOLDER = '../../Data/'
FIGS_FOLDER = '../../PaperFigs'
DB_FILEPATH = DATA_FOLDER + 'db.pkl'
COARSE_SEARCH_JAVI_PATH = f'{DATA_FOLDER}/javi_energy_coarse.pkl'
FINE_SEARCH_JAVI_PATH = f'{DATA_FOLDER}/javi_energy_fine.pkl'
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
    # print("Found data from {} users".format(len(users)))

    selected_user = list(users.values())[user_index]
    subject_name = selected_user.get('first_name', '?')
    print(f"Loading data of subject '{subject_name}'...")

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

def shuffle_samples(a, b):
    perm = np.random.permutation(a.shape[0])
    return a[perm], b[perm]

def cat_models(lhs, rhs, shuffle=False):
    res = tuple(np.concatenate((lhs[i], rhs[i])) for i in range(len(lhs)))
    if shuffle:
        res = shuffle_samples(*res)
    return res


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

def test_dataset(X, y, silent=False, balance=True):

    if not silent:
        print('\nTesting dataset...')
        n_class0 = np.sum([y == NOT_STRESSED])
        n_class1 = y.shape[0] - n_class0
        print('Stressed samples (unbalanced): ', n_class1)
        print('Not stressed samples (unbalanced): ', n_class0)
        print('Ratio: ', n_class1 / n_class0)

    while True:
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.13)
        if y_train.min() != y_train.max() and y_test.min() != y_test.max():
            break

    if balance:
        X_train, y_train = balance_dataset(X_train, y_train)
        X_test, y_test = balance_dataset(X_test, y_test)

    if not silent:
        if balance:
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

def test_dataset_avg(X, y, trials=1000, balance=True):

    print('First result:')
    test_dataset(X, y, silent=False, balance=balance)

    results = np.array([test_dataset(X, y, silent=True, balance=balance) for _ in range(trials)])
    mean_perf = np.mean(results, axis=0)

    avg_acc_test = mean_perf[0]
    avg_f1_test = mean_perf[1]
    print('\nFinal results:')
    print('avg_acc_test', avg_acc_test)
    print('avg_f1_test', avg_f1_test)

def test_dataset_cv(X, y, cv=5, balance=True):
    svm = SVC()
    if balance:
        X, y = balance_dataset(X, y)
    cv_score = cross_val_score(svm, X, y, cv=cv)
    y_pred = cross_val_predict(svm, X, y, cv=cv)
    cv_acc = accuracy_score(y, y_pred)
    cv_f1 = f1_score(y, y_pred)
    print('cv_score', cv_score)
    print('cv_acc', cv_acc)
    print('cv_f1', cv_f1)

def test_model_generalization():

    # Alexa:
    X_alexa, y_alexa = get_alexa_remote_stress()

    # Javi:
    X_javi, y_javi = get_javi_remote_stress()

    for i in range(2):

        if i == 0:
            print('\nTraining with Alexa, testing with Javi...')
            X_train, X_test, y_train, y_test = X_alexa, X_javi, y_alexa, y_javi
        else:
            print('\nTraining with Javi, testing with Alexa...')
            X_train, X_test, y_train, y_test = X_javi, X_alexa, y_javi, y_alexa

        X_train, y_train = balance_dataset(X_train, y_train)
        X_test, y_test = balance_dataset(X_test, y_test)

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
    X_javi, y_javi = get_javi_remote_stress()

    X = np.concatenate([X_alexa, X_javi])
    y = np.concatenate([y_alexa, y_javi])
    test_dataset_avg(X, y, trials=1000)

def test_energy_model_cv(X, y, epsilon=0.0841395, C=0.122, cv=5, silent=False):

    svr = SVR()
    svr.epsilon = epsilon
    svr.C = C

    cv_score = cross_val_score(svr, X, y, cv=cv)
    y_pred = cross_val_predict(svr, X, y, cv=cv)

    cv_mse = mean_squared_error(y, y_pred)
    cv_r2 = r2_score(y, y_pred)

    if not silent:
        print('cv_score', cv_score)
        print('cv_r2', cv_r2)
        print('cv_mse', cv_mse)

    return {
        'cv_score': cv_score,
        'cv_r2': cv_r2,
        'cv_mse': cv_mse
    }

def test_energy_model(X, y, epsilon=0.0841395, C=0.122, seed=None, silent=False):

    # best eps = 0.08413951416
    # best C = 0.122

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.33, random_state=seed)

    svr = SVR()
    svr.epsilon = epsilon
    svr.C = C

    svr.fit(X_train, y_train)

    p_train = svr.predict(X_train)
    p_test = svr.predict(X_test)

    mse_train = np.mean((p_train - y_train) ** 2)
    mse_test = np.mean((p_test - y_test) ** 2)

    mean_abs_err_train = np.mean(np.abs(p_train - y_train))
    mean_abs_err_test = np.mean(np.abs(p_test - y_test))

    err_rel_train = np.mean(relative_err(p_train, y_train))
    err_rel_test = np.mean(relative_err(p_test, y_test))

    score_train = r2_score(y_train, p_train)
    score_test = r2_score(y_test, p_test)

    results = {
        'mse_train': mse_train,
        'mse_test': mse_test,
        'err_rel_train': err_rel_train,
        'err_rel_test': err_rel_test,
        'mean_abs_err_train': mean_abs_err_train,
        'mean_abs_err_test': mean_abs_err_test,
        'score_train': score_train,
        'score_test': score_test,
        'y_train': y_train,
        'p_train': p_train,
        'y_test': y_test,
        'p_test': p_test,
    }

    if not silent:
        print(results)

    return results

def test_energy_model_avg(X, y, trials=1_000):

    print('First result:')
    test_energy_model(X, y, silent=False)

    all_results = pd.DataFrame([test_energy_model(X, y, silent=True) for _ in range(trials)])

    mse_test = np.array(all_results['mse_test'])
    err_rel_test = np.array(all_results['err_rel_test'])
    mean_abs_err_test = np.array(all_results['mean_abs_err_test'])
    score_test = np.array(all_results['score_test'])

    best_idx_by_score = np.argmax(score_test)
    y_train = all_results['y_train'][best_idx_by_score]
    p_train = all_results['p_train'][best_idx_by_score]
    y_test = all_results['y_test'][best_idx_by_score]
    p_test = all_results['p_test'][best_idx_by_score]

    avg_mse_test = np.mean(mse_test)
    avg_rel_err_test = np.mean(err_rel_test)
    avg_mean_abs_err_test = np.mean(mean_abs_err_test)
    avg_score_test = np.mean(score_test)

    print('\nFinal results:')
    print('avg_mse_test', avg_mse_test)
    print('avg_rel_err_test', avg_rel_err_test)
    print('avg_mean_abs_err_test', avg_mean_abs_err_test)
    print('max mean_abs_err_test', mean_abs_err_test.max())
    print('min mean_abs_err_test', mean_abs_err_test.min())
    print('avg_score_test', avg_score_test)


###########################
# Parameters Search
###########################

def get_configs(n, min_eps, max_eps, min_c, max_c):
    configs = []

    for i in range(n):
        min_e, max_e = (np.log10(min_eps), np.log10(max_eps))
        e = min_e + (max_e - min_e) * np.random.rand()
        eps = 10 ** e

        min_e, max_e = (np.log10(min_c), np.log10(max_c))
        e = min_e + (max_e - min_e) * np.random.rand()
        c = 10 ** e

        configs.append({'epsilon': eps, 'C': c})

    return configs


def params_search(X, y, configs, trials_per_config):

    all_results = []
    seed = 42

    for config in configs:
        eps, c = config.values()
        config_results = [test_energy_model(X, y, epsilon=eps, C=c, seed=(seed+i), silent=True) for i in range(trials_per_config)]
        config_results = pd.DataFrame(config_results)
        all_results.append({
            'config': config,
            'results': config_results
        })

    all_results = pd.DataFrame(all_results)

    scores_only = []
    for i, res in enumerate(all_results['results']):
        score_test = np.array(res['score_test'])
        scores_only.append({
            **configs[i],
            'score_test_min': score_test.min(),
            'score_test_max': score_test.max(),
            'score_test_avg': score_test.mean()
        })

    scores_only = pd.DataFrame(scores_only)
    return scores_only


def coarse_search(X, y, output_path=None):
    n_configs = 500
    trials_per_config = 100
    # configs = get_configs(n_configs, 0.01, 0.5, 0.001, 100)
    configs = get_configs(n_configs, 10**(-5.0), 10**(0.0), 10**(-2.0), 10**(3.0))
    results = params_search(X, y, configs, trials_per_config)
    if output_path is not None:
        results.to_pickle(output_path)
    return results


def fine_search(X, y, output_path=None):
    n_configs = 1_000
    trials_per_config = 100
    # configs = get_configs(n_configs, 10**(-1.6), 10**(-0.7), 10**(-5), 10**(-1))
    # configs = get_configs(n_configs, 10**(-1.5), 10**(-1.1), 10**(-5), 10**(-1.7))

    # Horizontal ==
    # configs = get_configs(n_configs, 10**(-2.0), 10**(-0.7), 10**(-1.2), 10**(3.0))

    # Vertical ||
    # configs = get_configs(n_configs, 10**(-5.0), 10**(-0.7), 10**(-1.2), 10**(0.0))

    # Intersection
    # configs = get_configs(n_configs, 10 ** (-1.4), 10 ** (-0.8), 10 ** (-1.3), 10 ** (0.0))

    # Zoom on intersection
    configs = get_configs(n_configs, 10 ** (-1.2), 10 ** (-1.0), 10 ** (-1.2), 10 ** (-0.7))

    # best eps = 0.08413951416
    # best C = 0.122

    results = params_search(X, y, configs, trials_per_config)
    if output_path is not None:
        results.to_pickle(output_path)
    return results


def plot_search(x, output_path=None):
    plt.figure()
    plt.scatter(np.log10(x['C']), np.log10(x['epsilon']), c=x['score_test_max'], marker='^')
    cb = plt.colorbar()
    cb.set_label('Max. $R^2$ score (validation)')
    plt.xlabel(r'$log_{10}(C)$')
    plt.ylabel(r'$log_{10}(epsilon)$')
    if output_path is not None:
        plt.savefig(output_path, bbox_inches='tight')
    plt.show()

###################################################




def params_search_cv(X, y, configs, cv=5):

    all_results = []

    for config in configs:
        eps, c = config.values()
        config_results = test_energy_model_cv(X, y, epsilon=eps, C=c, cv=cv, silent=True)
        # config_results = pd.DataFrame(config_results)
        all_results.append({
            'config': config,
            'results': config_results
        })

    all_results = pd.DataFrame(all_results)

    r2s = []
    for i, res in enumerate(all_results['results']):
        # cv_r2 = np.array(res['cv_r2'])
        r2s.append({
            **configs[i],
            **res
        })

    r2s = pd.DataFrame(r2s)
    return r2s


def coarse_search_cv(X, y, output_path=None):
    n_configs = 2_000
    #configs = get_configs(n_configs, 10**(-2.0), 10**(-0.5), 10**(-10.0), 10**(6.0))
    #configs = get_configs(n_configs, 10**(-1.45), 10**(-1.1), 10**(-26.0), 10**(0.0))
    #configs = get_configs(n_configs, 10**(-1.05), 10**(-0.75), 10**(-26.0), 10**(1.0))
    configs = get_configs(n_configs, 10**(-1.3), 10**(-0.8), 10**(-1.0), 10**(6.0))
    results = params_search_cv(X, y, configs)
    if output_path is not None:
        results.to_pickle(output_path)
    return results


def fine_search_cv(X, y, output_path=None):
    n_configs = 2_000
    # configs = get_configs(n_configs, 10**(-1.6), 10**(-0.7), 10**(-5), 10**(-1))
    # configs = get_configs(n_configs, 10**(-1.5), 10**(-1.1), 10**(-5), 10**(-1.7))

    # Horizontal ==
    # configs = get_configs(n_configs, 10**(-2.0), 10**(-0.7), 10**(-1.2), 10**(3.0))

    # Vertical ||
    # configs = get_configs(n_configs, 10**(-5.0), 10**(-0.7), 10**(-1.2), 10**(0.0))

    # Intersection
    # configs = get_configs(n_configs, 10 ** (-1.4), 10 ** (-0.8), 10 ** (-1.3), 10 ** (0.0))

    # Zoom on intersection
    # configs = get_configs(n_configs, 10 ** (-1.2), 10 ** (-1.0), 10 ** (-1.2), 10 ** (-0.7))

    configs = get_configs(n_configs, 10 ** (-1.225), 10 ** (-1.08), 10 ** (-0.9), 10 ** (0.25))

    # best eps = 0.08413951416
    # best C = 0.122

    results = params_search_cv(X, y, configs)
    if output_path is not None:
        results.to_pickle(output_path)
    return results


def plot_search_cv(x, output_path=None):
    plt.figure()
    plt.scatter(np.log10(x['C']), np.log10(x['epsilon']), c=x['cv_r2'], marker='^')
    cb = plt.colorbar()
    cb.set_label('$R^2$ score (cross-validation)')
    plt.xlabel(r'$log_{10}(C)$')
    plt.ylabel(r'$log_{10}(epsilon)$')
    if output_path is not None:
        plt.savefig(output_path, bbox_inches='tight')
    plt.show()

def test_search_cv():

    X_javi, y_javi = get_javi_remote_energy()
    X_alexa, y_alexa = get_alexa_remote_energy()
    X_comb, y_comb = cat_models((X_javi, y_javi), (X_alexa, y_alexa), shuffle=True)

    # m_name = 'javi'
    # X, y = X_javi, y_javi

    # m_name = 'alexa'
    # X, y = X_alexa, y_alexa

    m_name = 'comb'
    X, y = X_comb, y_comb


    y = energy_from_test_result(y)

    coarse_file = f'{DATA_FOLDER}/{m_name}_energy_coarse.pkl'
    fine_file = f'{DATA_FOLDER}/{m_name}_energy_fine.pkl'


    if not True or not Path(coarse_file).is_file():
        coarse_search_cv(X, y, coarse_file)

    results_coarse = unpickle(coarse_file)
    plot_search_cv(results_coarse, f'{FIGS_FOLDER}/coarse_{m_name}.eps')

    # exit(0)

    if True or not Path(fine_file).is_file():
        fine_search_cv(X, y, fine_file)

    results_fine = unpickle(fine_file)
    plot_search_cv(results_fine, f'{FIGS_FOLDER}/fine_{m_name}.eps')

    # X_alexa, y_alexa = get_alexa_remote_energy()
    # y_alexa = energy_from_test_result(y_alexa)
    # test_energy_model_avg(X_alexa, y_alexa)



def test_search():

    X_javi, y_javi = get_javi_remote_energy()
    y_javi = energy_from_test_result(y_javi)

    test_energy_model_avg(X_javi, y_javi)
    exit(0)

    # remove(COARSE_SEARCH_JAVI_PATH)

    if not Path(COARSE_SEARCH_JAVI_PATH).is_file():
        coarse_search(X_javi, y_javi, COARSE_SEARCH_JAVI_PATH)

    results_coarse_javi = unpickle(COARSE_SEARCH_JAVI_PATH)
    plot_search(results_coarse_javi, f'{FIGS_FOLDER}/coarse_javi.eps')

    # exit(0)
    # remove(FINE_SEARCH_JAVI_PATH)

    if not Path(FINE_SEARCH_JAVI_PATH).is_file():
        fine_search(X_javi, y_javi, FINE_SEARCH_JAVI_PATH)

    results_fine_javi = unpickle(FINE_SEARCH_JAVI_PATH)
    plot_search(results_fine_javi, f'{FIGS_FOLDER}/fine_javi.eps')

    # X_alexa, y_alexa = get_alexa_remote_energy()
    # y_alexa = energy_from_test_result(y_alexa)
    # test_energy_model_avg(X_alexa, y_alexa)


###########################
# Main
###########################

def main():

    test_search_cv()
    print('\n\n\n\n\n\n')
    exit(0)

    X_alexa, y_alexa = get_alexa_remote_energy()
    y_alexa = energy_from_test_result(y_alexa)

    test_energy_model_cv(X_alexa, y_alexa, epsilon=0.0841, C=0.122, cv=5)
    print(f'N={y_alexa.shape[0]}, mu={y_alexa.mean()}')

    print('\n\n')

    X_javi, y_javi = get_javi_remote_energy()
    # X_javi, y_javi = (X_javi[-40:], y_javi[-40:])
    y_javi = energy_from_test_result(y_javi)

    test_energy_model_cv(X_javi, y_javi, epsilon=0.0841, C=0.122, cv=5)
    print(f'N={y_javi.shape[0]}, mu={y_javi.mean()}')

    print('\n\n')

    X_comp, y_comp = cat_models((X_javi, y_javi), (X_alexa, y_alexa))

    test_energy_model_cv(X_comp, y_comp, epsilon=0.0841, C=0.122, cv=5)
    print(f'N={y_comp.shape[0]}, mu={y_comp.mean()}')

    print('\n\n')
    exit(0)


    #test_model_generalization()
    #exit(0)

    # clear_cached_db()

    #X_alexa, y_alexa = cat_models(get_alexa_remote_stress(), get_alexa_local_stress())
    #test_dataset_avg(X_alexa, y_alexa)

    #X_javi, y_javi = cat_models(get_javi_remote_stress(), get_javi_local_stress())
    #test_dataset_avg(X_javi, y_javi, balance=False)


    # test_composite_model()
    #exit(0)

    X_javi, y_javi = get_javi_local_stress()
    X_comp, y_comp = cat_models((X_javi[-40:], y_javi[-40:]), get_alexa_remote_stress())
    test_dataset_cv(X_comp, y_comp, balance=True)

    #X_alexa, y_alexa = get_alexa_remote_stress()
    # test_dataset_avg(X_alexa, y_alexa, balance=True)
    #test_dataset_cv(X_alexa, y_alexa)

    print('\n\n')

    #X_javi, y_javi = get_javi_remote_stress()
    #test_dataset_avg(X_javi, y_javi)

    #X_javi, y_javi = get_javi_local_stress()
    #test_dataset_avg(X_javi[-40:], y_javi[-40:], balance=True)



if __name__ == '__main__':
    main()
