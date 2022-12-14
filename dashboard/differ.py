"""
python differ.py --dtype=float32 --day1=233 --day2=234
"""

import argparse
import os

import pandas as pd
from tabulate import tabulate

from dashboard.config import dynamo_log_dir
from dashboard.config import lookup_file
from dashboard.config import suites
from dashboard.log_info import LogInfo


def find_log(day, dtype):
    """
    Find the last k pairs of (day number, log_path)
    """
    df = pd.read_csv(lookup_file, names=("day", "mode", "prec", "path"))
    df = df[df["mode"] == "performance"]
    df = df[df["prec"] == dtype]
    df = df[df["day"] == day]
    log_infos = []
    for day, path in zip(df["day"], df["path"]):
        log_infos.append(LogInfo(day, path))
    assert len(log_infos) == 1
    log_info = log_infos[0]
    gmean_csv = os.path.join(dynamo_log_dir, log_info.dir_path, "geomean.csv")
    passrate_csv = os.path.join(dynamo_log_dir, log_info.dir_path, "passrate.csv")
    df_gmean = pd.read_csv(gmean_csv)
    df_passrate = pd.read_csv(passrate_csv)
    return df_gmean, df_passrate


def diff(dtype, day1, day2):
    df1_gmean, df1_passrate = find_log(day1, dtype)
    df2_gmean, df2_passrate = find_log(day2, dtype)
    print(df1_gmean)

    def get_delta(df1, df2, extracter, adder):
        cols = {}
        cols["Compiler"] = df1["Compiler"]
        for suite in suites:
            day1_gmean = [extracter(i) for i in df1[suite].to_list()]
            day2_gmean = [extracter(i) for i in df2[suite].to_list()]
            delta_gmean = [
                adder(round(a - b, 2)) for (a, b) in zip(day1_gmean, day2_gmean)
            ]
            cols[suite] = delta_gmean
        return pd.DataFrame(cols)

    remove_x = lambda s: float(s.replace("x", ""))
    get_passrate = lambda s: float(s.partition("%")[0])
    gmean_delta = get_delta(df1_gmean, df2_gmean, remove_x, lambda x: f"{x}x")
    passrate_delta = get_delta(
        df1_passrate, df2_passrate, get_passrate, lambda x: f"{x}%"
    )
    tabform = tabulate(
        gmean_delta, headers="keys", tablefmt="pretty", showindex="never"
    )
    print(tabform)
    tabform = tabulate(
        passrate_delta, headers="keys", tablefmt="pretty", showindex="never"
    )
    print(tabform)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Tells which component is failing")
    parser.add_argument("--dtype", required=True, type=str, help="dtype")
    parser.add_argument("--day1", required=True, type=int, help="First day")
    parser.add_argument("--day2", required=True, type=int, help="Second day")
    args = parser.parse_args()
    diff(args.dtype, args.day1, args.day2)
