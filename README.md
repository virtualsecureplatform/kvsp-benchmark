# kvsp-benchmark

## Benchmark for speed

```
$ ./benchmark.sh speed [-g NUM-OF-GPUS]
```

Turn results into TeX format.

```
$ tree results
results
├── Sakura Koukaryoku
│   ├── 20200413_1319.log
│   ├── 20200414_0315.log
│   └── 20200504_1700.log
├── c5.metal
│   ├── 20200502_0618.log
│   └── 20200504_1929.log
└── n1-standard-96
     ├── 20200429_2235.log
     └── 20200430_0045.log

3 directories, 15 files

$ ruby result2tex.rb results
% machine & w/ super-scalar & w/ CMUX Memory & program & # of cycles & runtime & sec./cycle\\
n1-standard-96 w/ V100x8 & Y & Y & Fibonacci & 38 & 151.29 & 3.98 \\
n1-standard-96 w/ V100x8 & Y & Y & Hamming & 832 & 2108.73 & 2.53 \\
n1-standard-96 w/ V100x8 & Y & Y & Brainf*ck & 1982 & 4900.34 & 2.47 \\
n1-standard-96 w/ V100x4 & Y & Y & Fibonacci & 38 & 137.75 & 3.63 \\
n1-standard-96 w/ V100x4 & Y & Y & Hamming & 832 & 2091.07 & 2.51 \\
n1-standard-96 w/ V100x4 & Y & Y & Brainf*ck & 1982 & 4968.43 & 2.51 \\
c5.metal & Y & Y & Fibonacci & 38 & 167.42 & 4.41 \\
c5.metal & Y & Y & Hamming & 832 & 3604.01 & 4.33 \\
c5.metal & Y & Y & Brainf*ck & 1982 & 8592.38 & 4.34 \\
Sakura Koukaryoku w/ V100x1 & N & Y & Fibonacci & 57 & 218.04 & 3.83 \\
Sakura Koukaryoku w/ V100x1 & N & Y & Hamming & 1179 & 4442.22 & 3.77 \\
Sakura Koukaryoku w/ V100x1 & N & Y & Brainf*ck & 2464 & 9258.25 & 3.76 \\
Sakura Koukaryoku w/ V100x1 & Y & Y & Fibonacci & 38 & 163.49 & 4.3 \\
Sakura Koukaryoku w/ V100x1 & Y & Y & Hamming & 832 & 3397.68 & 4.08 \\
Sakura Koukaryoku w/ V100x1 & Y & Y & Brainf*ck & 1982 & 8077.28 & 4.08 \\
```

## Benchmark for bottleneck (CPU and GPU usage)

```
$ ./benchmark.sh bottleneck [-g NUM-OF-GPUS]
```

Turn results into graph.

```
$ git submodule update --init --recursive
$ bundle install
$ bundle exec ruby bottleneck2graph.rb -f 7 -t 10 faststat.log kvsp.log # -f and -t option can be omitted.
```

## Running with Singularity (HPC / Supercomputers)

Singularity (or [Apptainer](https://apptainer.org/)) is the container runtime commonly used in HPC environments. The provided `kvsp-benchmark.def` builds a self-contained image based on Ubuntu 24.04 with all required dependencies pre-installed.

### Build the container image

Build on a machine where you have root or fakeroot access (e.g. your local workstation):

```
git clone https://github.com/virtualsecureplatform/kvsp-benchmark.git
cd kvsp-benchmark

# With sudo:
sudo singularity build kvsp-benchmark.sif kvsp-benchmark.def

# Or with fakeroot (no sudo required if fakeroot is enabled):
singularity build --fakeroot kvsp-benchmark.sif kvsp-benchmark.def
```

### Transfer to the supercomputer

```
scp kvsp-benchmark.sif user@supercomputer:/path/to/workdir/
scp -r . user@supercomputer:/path/to/workdir/kvsp-benchmark/
```

Alternatively, clone the repository directly on the supercomputer and transfer only the `.sif` file.

### Run the benchmark

On the supercomputer, from inside the `kvsp-benchmark` directory:

**With GPU(s):**
```
singularity exec --nv --pwd $(pwd) kvsp-benchmark.sif ./benchmark.sh speed -g <NUM_GPUS>
```

**CPU-only (no GPU):**
```
singularity exec --pwd $(pwd) kvsp-benchmark.sif ./benchmark.sh speed
```

The `--nv` flag passes NVIDIA drivers and CUDA libraries from the host into the container. It is required for GPU benchmarks and for GPU monitoring via `faststat`. Without it, GPU operations and NVML metrics will be unavailable.

> **Note:** Singularity automatically bind-mounts `$HOME` on most systems. If the project directory is outside `$HOME`, add `--bind $(pwd):$(pwd)` to the command.

### Example SLURM job script

```bash
#!/bin/bash
#SBATCH --job-name=kvsp-benchmark
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=<NUM_CPUS>
#SBATCH --gres=gpu:<NUM_GPUS>
#SBATCH --time=12:00:00
#SBATCH --output=kvsp-benchmark_%j.log

cd /path/to/kvsp-benchmark

singularity exec --nv --pwd $(pwd) \
    /path/to/kvsp-benchmark.sif \
    ./benchmark.sh speed -g <NUM_GPUS>
```

### Notes

- The benchmark downloads KVSP binaries and `faststat` from GitHub on first run. Internet access is required on the compute node, or pre-download them by running `./benchmark.sh speed` once before the job.
- Results are written to a timestamped directory (e.g. `speed-20250101120000/`) inside the project directory.
- The container sets `BUNDLE_APP_CONFIG` to its internal bundler config so gems at `/opt/bundle` are always used, even if the project directory contains a `.bundle/config` pointing elsewhere.
- The command name may be `apptainer` instead of `singularity` depending on the system.

## Dependency

There is Slackbot support


Ubuntu

```
git clone https://github.com/virtualsecureplatform/kvsp-benchmark.git
cd kvsp-benchmark
sudo apt update
sudo apt install -y ruby ruby-dev libgoogle-perftools-dev libomp-dev build-essential
sudo gem install bundler -v 2.1.4
sudo gem install websocket-driver -v '0.7.1' --source 'https://rubygems.org/'
bundle install
./benchmark.sh
```

AWS p3.16xlarge with Ubuntu 18.04 AMI setup (we recommend to expand EBS to 12GB. 8GB is not enough.)
```
git clone https://github.com/virtualsecureplatform/kvsp-benchmark.git&&cd kvsp-benchmark&&sudo apt update&&sudo apt upgrade -y&&sudo apt install -y ruby ruby-dev libgoogle-perftools-dev libomp-dev build-essential nvidia-driver-440&&sudo gem install bundler -v 2.1.4 &&sudo gem install websocket-driver -v '0.7.1' --source 'https://rubygems.org/'&&bundle install&&sudo reboot
```
GCP with Ubuntu 18.04
```
sudo apt update&&sudo apt upgrade -y && sudo apt install -y ruby ruby-dev libgoogle-perftools-dev libomp-dev build-essential nvidia-driver-460 git&&git clone https://github.com/virtualsecureplatform/kvsp-benchmark.git&&cd kvsp-benchmark&&sudo gem install bundler -v 2.1.4 &&sudo gem install websocket-driver -v '0.7.1' --source 'https://rubygems.org/'&&bundle install&&sudo reboot
```
AWS p3.8xlarge with Ubuntu 20.04 AMI
```
git clone https://github.com/virtualsecureplatform/kvsp-benchmark.git&&cd kvsp-benchmark&&sudo apt update&&sudo apt upgrade -y&&sudo apt install -y ruby ruby-dev libgoogle-perftools-dev libomp-dev build-essential nvidia-driver-460 libz3-dev &&sudo gem install bundler -v 2.1.4 &&sudo gem install websocket-driver -v '0.7.1' --source 'https://rubygems.org/'&&bundle install&&sudo reboot
```
AWS c5.metal Ubuntu 18.04
```
git clone https://github.com/virtualsecureplatform/kvsp-benchmark.git&&cd kvsp-benchmark&&sudo apt update&&sudo apt upgrade -y&&sudo apt install -y ruby ruby-dev libgoogle-perftools-dev libomp-dev build-essential &&sudo gem install bundler -v 2.1.4 &&sudo gem install websocket-driver -v '0.7.1' --source 'https://rubygems.org/'&&bundle install
```
