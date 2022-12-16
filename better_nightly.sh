#!/bin/bash
set -xe
source /etc/profile
source /data/home/$USER/.bashrc
source /data/shared/bin/cluster_env.sh
export INNER_DIR="${INNER_DIR}"
export CCACHE_DIR="/scratch/$USER/work/ccache"
export MAKEFLAGS=-j96
export USE_LLVM=/usr/lib/llvm-10
export TORCH_CUDA_ARCH_LIST="8.0"
export CUDA_HOME=/usr/local/cuda-11.6
export PATH=${CUDA_HOME}/bin:${PATH}
export CUDA_NVCC_EXECUTABLE=${CUDA_HOME}/bin/nvcc
export LD_LIBRARY_PATH=${CUDA_HOME}/lib:${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
eval "$(conda shell.bash hook)"


echo "##### bash: starting ####"
mode="performance"
if [[ $IS_COVERAGE == 1 ]]; then
    mode="coverage"
fi
echo "bash: USER=$USER, dtype=$DTYPE, coverage=$IS_COVERAGE, mode=$mode, nightly=$IS_NIGHTLY"

scratch_dir="/scratch/$USER"
top_dir="/scratch/$USER/dashboard"
work_dir="/scratch/$USER/dashboard/work"
env_dir="/scratch/$USER/dashboard/env"
zipped_file="/data/home/$USER/cluster/dashboard.tar.lz4"
rm -rf $top_dir
mkdir -p $top_dir
mkdir -p $work_dir

# TODO - Add instructions to build dashboard conda env from scratch
echo "#### bash: unzipping saved env at $work_dir ####"
cp $zipped_file $scratch_dir
new_zip_file="/scratch/$USER/dashboard.tar.lz4"
lz4 -dc < $new_zip_file | tar xf - -C $scratch_dir

echo "#### bash: Activating conda environment from $env_dir ####"
conda activate $env_dir
conda install -y astunparse numpy scipy ninja pyyaml mkl mkl-include setuptools cffi typing_extensions future six requests dataclasses protobuf numba cython || true
python -m pip install cmake==3.22.5
conda install -y -c pytorch magma-cuda116 || true
conda install -y -c conda-forge librosa tqdm gh gitpython || true
conda install -y -c anaconda certifi || true
conda install -y pandas==1.4.2 pip git-lfs || true
conda install -y scikit-learn || true
# Set the LD_LIBRARY PATH to first look into miniconda libs
# HACK - For some reason I need this
export LD_LIBRARY_PATH=$env_dir/lib:${LD_LIBRARY_PATH}

cd $work_dir
if [[ $IS_NIGHTLY == 1 ]]; then
    echo "#### bash: Cloning nightly PyTorch ####"
    test -e pytorch || git clone --recursive https://github.com/pytorch/pytorch.git pytorch
    cd pytorch
    git fetch && git reset --hard origin/nightly && git submodule sync && git submodule update --init --recursive --jobs 0

    echo "#### bash: Installing nightly PyTorch and dependencies ####"
    python -m pip uninstall torch torchvision torchaudio torchdata torchtext 
    python -m pip install --pre torch torchvision torchaudio torchdata torchtext --extra-index-url https://download.pytorch.org/whl/nightly/cu116
    python -m pip uninstall detectron2
    python -m pip install 'git+https://github.com/facebookresearch/detectron2.git'
    TRITON_VERSION=$(cat .github/ci_commit_pins/triton.txt)
    python -m pip uninstall triton
    python -m pip install -U "git+https://github.com/openai/triton@${TRITON_VERSION}#subdirectory=python"
    cd ../

    test -e torchbenchmark || git clone --recursive https://github.com/pytorch/benchmark torchbenchmark
    cd torchbenchmark && git pull && git submodule update --init --recursive
    python install.py --continue_on_fail
    cd ../pytorch
else
    echo "#### bash: Cloning Pytorch ####"
    rm -fr torchdynamo # FIXME
    test -e pytorch || git clone --recursive https://github.com/pytorch/pytorch.git pytorch
    cd pytorch
    git fetch && git reset --hard origin/master && git submodule sync && git submodule update --init --recursive --jobs 0
    # git apply /data/home/$USER/cluster/dashboard.patch

    echo "#### bash: Building dependenices ####"
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
    python setup.py clean && python setup.py develop

    python -m pip install regex
    cd benchmarks/dynamo
    make -f Makefile_dashboard pull-deps
    make -f Makefile_dashboard build-deps
    # ln -fs $env_dir/bin/g++ $env_dir/bin/g++-12
    cd ../..
fi

python -m pip uninstall -y transformers
python -m pip uninstall -y timm
python -m pip install transformers timm

# Remove the triton cache
rm -fr /tmp/torchinductor_$USER/

echo "#### bash: Running Models ####"
# HACK - For some reason I need to set PYTHONPATH
#PYTHONPATH=/scratch/$USER/dashboard/work/torchdynamo 
python benchmarks/dynamo/runner.py --suites=torchbench --suites=huggingface --suites=timm_models --training --dtypes=${DTYPE} --output-dir=bench_logs --update-dashboard --dashboard-archive-path=/data/home/$USER/cluster/cron_logs/
# python benchmarks/dynamo/runner.py --suites=huggingface --compilers=aot_eager --compilers=inductor --training --dtypes=${DTYPE} --output-dir=bench_logs --update-dashboard
# python benchmarks/runner.py --suites=torchbench --training --dtypes=${DTYPE} --output-dir=bench_logs --update-dashboard
echo "### bash: Finished ####"
