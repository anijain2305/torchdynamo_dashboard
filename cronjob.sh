#!/bin/bash
mode="performance"
if [[ $IS_COVERAGE == 1 ]]; then
    mode="coverage"
fi
logfile="/fsx/users/$USER/cron_${mode}_${DTYPE}_${RANDOM}.job"
echo $logfile
echo "Starting" > $logfile
echo "HOME=$HOME" >> $logfile
echo "PATH=$PATH" >> $logfile
echo "SHELL=$SHELL" >> $logfile
echo "USER=$USER" >> $logfile
echo "mode=${mode}" >> $logfile
srun -p train -G 1 -c96 --exclusive bash /data/home/$USER/cluster/torchdynamo_dashboard/better_nightly.sh >> $logfile 2>&1
# srun -p train -G 1 -c96 --exclusive bash /data/home/$USER/cluster/torchdynamo_dashboard/nightly.sh --output=$logfile
