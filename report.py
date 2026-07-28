import gc
import csv
import glob
import os
import json
import phpserialize
import pandas
import sys
from tqdm import tqdm
from pathlib import Path
from collections import defaultdict
from multiprocessing import Pool


class Coverage:

    def __init__(self, data=None):
        self.data = data or {}

    def load(self, fp):
        cov = phpserialize.load(fp)
        self.data = {}
        for fname, lines in cov.items():
            self.data[fname] = set(lines.keys())

    def __getitem__(self, key):
        return self.data[key]

    def __or__(self, other):
        res = Coverage(self.data.copy())
        res |= other
        return res

    def __ior__(self, other):
        for fname, lines in other.data.items():
            self.data[fname] = self.data.get(fname, set()) | lines
        return self

    def __sub__(self, other):
        res = Coverage(self.data.copy())
        res -= other
        return res

    def __isub__(self, other):
        for fname, lines in other.data.items():
            our_lines = self.data.get(fname, None)
            if our_lines is not None:
                self.data[fname] = our_lines - (our_lines & lines)
        return self

    def items(self):
        return self.data.items()

    def __len__(self):
        # python 3.10 feature
        return sum(map(len, self.data.values()))

def parse_experiment(path, coverage_dir='coverage'):
    with open(os.path.join(path, 'command.txt')) as f:
        command = f.read()
    with open(os.path.join(path, 'runtime.txt')) as f:
        runtime = f.read()

    coverage_path = os.path.join(path, coverage_dir)

    experiment = str(path).split('/')[3]

    with open(os.path.join(coverage_path, 'history.json'), 'r') as f:
        history = json.load(f)

    files, history = history['files'], history['history']
    cov, cov_history = join(coverage_path, files, history)
    return experiment, command, runtime, cov, cov_history

def load_coverage(fname):
    with open(fname, 'rb') as f:
        cov = Coverage()
        cov.load(f)
    return cov

def join(path, files, history):
    res = Coverage()
    res_history = []
    processed = set()
    prev_log = 0
    for file_idx in history:
        if file_idx not in processed:
            tmp = Coverage()
            with open(os.path.join(path, files[file_idx]), 'rb') as f:
                tmp.load(f)
            res |= tmp
            processed.add(file_idx)
        res_history.append(len(res) - prev_log)
        prev_log = len(res)
    return res, res_history


if __name__ == '__main__':
    experiments_dir = 'experiments'
    data = defaultdict(list)
    prev = defaultdict(Coverage)
    idx = defaultdict(int)
    with open('out.csv', 'w') as f:
        out = csv.writer(f)
        out.writerow(['experiment', 'nav', 'pagesim', 'app', 'idx',
                      'cov', 'cumcov', 'requests', 'history_10', 'history', 'runtime'])
        for app in os.listdir(experiments_dir):
            app_dir = os.path.join(experiments_dir, app)
            for crawler in os.listdir(app_dir):
                crawler_dir = os.path.join(app_dir, crawler)
                experiment_dirs = sorted(Path(crawler_dir).iterdir(),
                                                  key=lambda x: os.path.getctime(os.path.join(x, 'command.txt')))
                with Pool(processes=20) as pool:
                    for experiment, command, runtime, cov, cov_history in tqdm(pool.map(parse_experiment, experiment_dirs)):
                        algo = command.split(' ')
                        nav = algo[algo.index('--nav')+1]
                        pagesim = algo[algo.index('-a')+1]
                        key = (app, crawler, nav, pagesim)

                        prev[key] |= cov
                        out.writerow([experiment, nav, pagesim, app, idx[key],
                                      len(cov), len(prev[key]), len(cov_history),
                                      ','.join(map(str,cov_history[:10])),
                                      ','.join(map(str,cov_history)),
                                      runtime])
                        idx[key] += 1
