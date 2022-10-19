# torchdynamo_dashboard

python setup.py develop
python dashboard/differ.py --dtype=float32 --day1=234 --day2=233
python dashboard/triager.py --dtype=float32 --lastk=2


This is the crontab

~~~
# For example, you can run a backup of all your user accounts
# at 5 a.m every week with:
# 0 5 * * 1 tar -zcf /var/backups/home.tgz /home/
#
# For more information see the manual pages of crontab(5) and cron(8)
#
# m h  dom mon dow   command
PATH=/data/home/anijain/.local/bin:/data/home/anijain/bin:/usr/local/cuda-11.6/bin:/data/home/anijain/miniconda/bin:/data/home/anijain/miniconda/condabin:/usr/local/cuda-11.1/bin:/opt/amazon/openmpi/bin:/opt/amazon/efa/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/opt/slurm/bin
USER=anijain
36 22 * * * DTYPE="float32" IS_COVERAGE=0 bash /data/home/anijain/cluster/torchdynamo_dashboard/cronjob.sh
36 22 * * * DTYPE="amp"     IS_COVERAGE=0 bash /data/home/anijain/cluster/torchdynamo_dashboard/cronjob.sh
~~~
