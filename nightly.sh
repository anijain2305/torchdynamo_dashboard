#!/bin/bash --init-file
source /etc/profile
source /data/home/$USER/.bashrc
source /data/shared/bin/cluster_env.sh
export INNER_DIR="${INNER_DIR}"
export CCACHE_DIR="/scratch/anijain/work/ccache"
export MAKEFLAGS=-j96
export USE_LLVM=/usr/lib/llvm-10
export TORCH_CUDA_ARCH_LIST="8.0"
export CUDA_HOME=/usr/local/cuda-11.6
export PATH=${CUDA_HOME}/bin:${PATH}
export CUDA_NVCC_EXECUTABLE=${CUDA_HOME}/bin/nvcc
export LD_LIBRARY_PATH=${CUDA_HOME}/lib:${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
eval "$(conda shell.bash hook)"


echo "##### bash: starting ####"
echo "Running Models"
echo "${mode} run"
echo $USER
echo $IS_COVERAGE
echo "dtype = ${DTYPE}"
mode="performance"
if [ $IS_COVERAGE == 1 ]; then
    mode="coverage"
fi

scratch_dir="/scratch/$USER"
top_dir="/scratch/$USER/dashboard"
work_dir="/scratch/$USER/dashboard/work"
env_dir="/scratch/$USER/dashboard/env"
zipped_file="/data/home/$USER/cluster/dashboard.tar.lz4"
rm -rf $top_dir
mkdir -p $work_dir


echo "#### bash: unzipping saved env at $work_dir ####"
cp $zipped_file $scratch_dir
new_zip_file="/scratch/$USER/dashboard.tar.lz4"
lz4 -dc < $new_zip_file | tar xf - -C $scratch_dir


# echo "Making your working directory at: $work_dir"
# mkdir -p $work_dir

# echo "Setting your conda env directory at: $work_dir"
# cp $zipped_file $top_dir/
# new_zip_file="/scratch/$USER/dashboard/dashboard_env.tar.lz4"
# lz4 -dc < $new_zip_file | tar xf - -C $top_dir
# mv $top_dir/dashboard_env $env_dir
# mkdir -p $env_dir

echo "#### bash: Activating conda environment from $env_dir ####"
# conda create -y -p $CONDA_DIR
conda activate $env_dir
conda install -y astunparse numpy scipy ninja pyyaml mkl mkl-include setuptools cmake cffi typing_extensions future six requests dataclasses protobuf numba cython
conda install -y -c pytorch magma-cuda116
conda install -y -c conda-forge librosa tqdm gh gitpython
conda install -y -c anaconda certifi
conda install -y pandas==1.4.2 pip git-lfs
conda install -y scikit-learn


echo "#### bash: Cloning TorchDynamo ####"
cd $work_dir
git clone --recursive https://github.com/pytorch/torchdynamo.git
cd torchdynamo
git fetch && git reset --hard origin/main
# git apply /data/home/$USER/cluster/dashboard.patch
make setup

echo "#### bash: Build dependenices ####"
# Setup flags for fast pytorch build
# export CXX=clang++-10
# export CC=clang-10
# export CXXFLAGS="-fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"
export USE_CUDA=1
export REL_WITH_DEB_INFO=1
export BUILD_CAFFE2=0
export USE_XNNPACK=0
export USE_FBGEMM=0
export USE_QNNPACK=0
export USE_NNPACK=0
export BUILD_TEST=0
export USE_GOLD_LINKER=1
export USE_PYTORCH_QNNPACK=0
export USE_GOLD_LINKER=1
export DEBUG=0
make pull-deps
make build-deps
python -m pip uninstall -y transformers
python -m pip uninstall -y timm
python -m pip install transformers timm

echo "#### bash: Building TorchDynamo ####"
python setup.py develop

echo "### bash: Running Models ####"
if [ $IS_COVERAGE == 1 ]; then
    python benchmarks/runner.py --suites=torchbench --suites=huggingface --suites=timm_models --profile_compiler --dtypes=float32 --output=bench_logs |& tee coverage.log
    mv coverage.log bench_logs/
else
    python benchmarks/runner.py --suites=torchbench --suites=huggingface --suites=timm_models --training --dtypes=${DTYPE} --output-dir=bench_logs |& tee benchmarking.log
    mv benchmarking.log bench_logs/
fi

echo "#### bash: Moving artifacts to shared cluster ####"
cd /fsx/users/anijain/cron_logs/
DAY=`date +%j`
DATE=`date +%m_%d_%y`
LOGDIR="day_${DAY}_${DATE}_${mode}_${DTYPE}_${RANDOM}"
echo "${DAY},${mode},${DTYPE},${LOGDIR}" >> lookup.csv
mkdir $LOGDIR
latest_dir=latest_${mode}_${DTYPE}
rm -rf ${latest_dir}
mkdir ${latest_dir}
cp -rf $work_dir/torchdynamo/bench_logs/* $LOGDIR/
cp -rf $work_dir/torchdynamo/bench_logs/* ${latest_dir}



echo "#### bash: Make a comment #####"
if [ $IS_COVERAGE == 1 ]; then
    cd /fsx/users/anijain/cron_logs/${latest_dir}/
    cat gh_profile_compiler.txt > github_comment.txt
else
    cd /fsx/users/anijain/cron_logs/${latest_dir}/
    cat gh_training.txt gh_build_summary.txt > github_comment.txt

    echo "## Graphs ##" >> github_comment.txt
    for i in *.png; do
        echo "$i : ![](`/fsx/users/anijain/bin/imgur.sh $i`)" >> github_comment.txt
    done
fi

cd /fsx/users/anijain/torchdynamo
/data/home/anijain/miniconda/bin/gh issue comment 681 -F /fsx/users/anijain/cron_logs/${latest_dir}/github_comment.txt
rm -fr /fsx/users/anijain/cron_logs/${latest_dir}
echo "### bash: Finished ####"
