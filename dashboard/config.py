import os

dynamo_log_dir = "/data/home/anijain/cluster/cron_logs"
eager = "eager"
aot_eager = "aot_eager"
inductor = "inductor_cudagraphs"
suites = ["torchbench", "huggingface", "timm_models"]

lookup_file = os.path.join(dynamo_log_dir, "lookup.csv")
assert os.path.exists(lookup_file)
