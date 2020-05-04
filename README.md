# kvsp-benchmark

CPU mode

```
./benchmark.sh
```

GPU mode

```
./benchmark.sh -g number-of-GPUs-you-have
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


# Dependency

Ubuntu

```
sudo apt update
sudo apt install ruby libgoogle-perftools-dev libomp-dev
```
