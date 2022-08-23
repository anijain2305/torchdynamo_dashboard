"""
Usage - python triager.py --dtype=float32 --lastk=2
"""

import os
from datetime import datetime

import click
import pandas as pd
from tabulate import tabulate

from dashboard.config import aot_eager
from dashboard.config import dynamo_log_dir
from dashboard.config import inductor
from dashboard.config import lookup_file
from dashboard.config import suites
from dashboard.log_info import LogInfo


def get_date(log_info):
    return datetime.strptime(f"{log_info.day}", "%j").strftime("%m-%d")


def has_header(output_filename):
    header_present = False
    with open(output_filename, "r") as f:
        line = f.readline()
        if "dev" in line:
            header_present = True
    return header_present


def read_csv(output_filename):
    if has_header(output_filename):
        return pd.read_csv(output_filename)
    else:
        return pd.read_csv(
            output_filename,
            names=["dev", "name", "batch_size", "speedup"],
            header=None,
        )


def find_last_k(k, dtype):
    """
    Find the last k pairs of (day number, log_path)
    """
    df = pd.read_csv(lookup_file, names=("day", "mode", "prec", "path"))
    df = df[df["mode"] == "performance"]
    df = df[df["prec"] == dtype]
    log_infos = []
    for day, path in zip(df["day"], df["path"]):
        log_infos.append(LogInfo(day, path))

    assert len(log_infos) >= k
    log_infos = log_infos[len(log_infos) - k :]
    return log_infos


@click.command()
@click.option("--dtype")
@click.option("--lastk", type=int)
def parse(dtype, lastk):
    log_infos = find_last_k(lastk, dtype)
    all_dfs = []
    for suite in suites:
        columns = {}
        for log_info in log_infos:
            # print(log_info)
            dir_path = os.path.join(dynamo_log_dir, log_info.dir_path)
            assert os.path.exists(dir_path)

            # Get these strings common from runner.py
            models = None
            failing = {}
            for compiler in [aot_eager, inductor]:
                output_filename = f"{compiler}_{suite}_{dtype}_training_cuda.csv"
                output_filename = os.path.join(dir_path, output_filename)
                assert os.path.exists(output_filename), f"{output_filename} not found"
                # print(output_filename)
                df = read_csv(output_filename)
                if models is None:
                    models = set(df["name"].to_list())
                df = df[df["speedup"] == 0.0]
                failing[compiler] = set(df["name"].to_list())

            only_inductor_fails = failing[inductor] - failing[aot_eager]
            only_aot_eager = failing[aot_eager]
            passing = models - failing[inductor]

            triaged = []
            for model in sorted(models):
                if model in passing:
                    triaged.append("pass")
                elif model in only_inductor_fails:
                    triaged.append("inductor")
                elif model in only_aot_eager:
                    triaged.append("aot")
                else:
                    raise RuntimeError("Something bad happened")

            if "name" not in columns:
                columns["suite"] = [suite] * len(models)
                columns["name"] = list(sorted(models))
                columns["issue"] = [""] * len(models)
            columns[get_date(log_info)] = triaged

        triaged_df = pd.DataFrame(columns)
        all_dfs.append(triaged_df)

    df = pd.concat(all_dfs)
    tabform = tabulate(df, headers="keys", tablefmt="pretty", showindex="never")
    print(tabform)
    date_str = get_date(log_infos[0])
    triaged_csv = os.path.join(f"triaged_{dtype}_{date_str}.csv")
    print(triaged_csv)
    df.to_csv(triaged_csv, mode="w", index=False)


if __name__ == "__main__":
    parse()
