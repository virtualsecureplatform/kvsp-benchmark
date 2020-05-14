#!/usr/bin/ruby

=begin
  ## Usage

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

  ## Support
    This tool supports automatic parsing of all versions below:

      v11_01_fib_gpu,emu,0.277184335,2020-04-13 13:19:38 +0000
      v11_01_fib_gpu,num_cycles,38,2020-04-13 13:19:38 +0000
      v11_01_fib_gpu,genkey,0.014748779,2020-04-13 13:19:38 +0000
      v11_01_fib_gpu,enc,58.301425305,2020-04-13 13:20:36 +0000
      v11_01_fib_gpu,run,166.038401777,2020-04-13 13:23:22 +0000
      v11_01_fib_gpu,dec,0.128921507,2020-04-13 13:23:22 +0000
      v11_01_fib_gpu,ctxt_size,2596634717,2020-04-13 13:23:22 +0000

      v11_01_fib_cpu,num_cycles,38,2020-04-19 13:45:53 +0000
      v11_01_fib_cpu,genkey,0.003651032,2020-04-19 13:45:53 +0000
      v11_01_fib_cpu,enc,63.825753363,2020-04-19 13:46:57 +0000
      v11_01_fib_cpu,run,329.225690856,2020-04-19 13:52:26 +0000
      v11_01_fib_cpu,dec,0.049495426,2020-04-19 13:52:26 +0000
      v11_01_fib_cpu,ctxt_size,2596634717,2020-04-19 13:52:26 +0000

      v12_01_fib_8gpu,emu,0.1957048,2020-04-29 07:54:26 +0000
      v12_01_fib_8gpu,num_cycles,38,2020-04-29 07:54:26 +0000
      v12_01_fib_8gpu,genkey,0.006129351,2020-04-29 07:54:26 +0000
      v12_01_fib_8gpu,enc,74.333132715,2020-04-29 07:55:41 +0000
      v12_01_fib_8gpu,run,151.29088248,2020-04-29 07:58:12 +0000
      v12_01_fib_8gpu,dec,0.095654218,2020-04-29 07:58:12 +0000
      v12_01_fib_8gpu,ctxt_size,2596634717,2020-04-29 07:58:12 +0000

      v14_emerald_1gpus_01_fib,cc,0.06127331,2020-05-01 22:01:03 +0900
      v14_emerald_1gpus_01_fib,elf_text_size,47,2020-05-01 22:01:03 +0900
      v14_emerald_1gpus_01_fib,emu,0.215687883,2020-05-01 22:01:03 +0900
      v14_emerald_1gpus_01_fib,num_cycles,38,2020-05-01 22:01:03 +0900
      v14_emerald_1gpus_01_fib,genkey,0.008537429,2020-05-01 22:01:03 +0900
      v14_emerald_1gpus_01_fib,enc,49.95133539,2020-05-01 22:01:53 +0900
      v14_emerald_1gpus_01_fib,run,163.095014726,2020-05-01 22:04:36 +0900
      v14_emerald_1gpus_01_fib,dec,0.081968135,2020-05-01 22:04:36 +0900
      v14_emerald_1gpus_01_fib,ctxt_size,2596634717,2020-05-01 22:04:36 +0900

      v14_emerald_1gpu_01_fib,cc,0.06334036,2020-05-02 12:57:13 +0900
      v14_emerald_1gpu_01_fib,elf_text_size,47,2020-05-02 12:57:13 +0900
      v14_emerald_1gpu_01_fib,emu,0.174886335,2020-05-02 12:57:13 +0900
      v14_emerald_1gpu_01_fib,num_cycles,38,2020-05-02 12:57:13 +0900
      v14_emerald_1gpu_01_fib,genkey,0.007853714,2020-05-02 12:57:13 +0900
      v14_emerald_1gpu_01_fib,enc,51.148494565,2020-05-02 12:58:04 +0900
      v14_emerald_1gpu_01_fib,run,165.447091338,2020-05-02 13:00:49 +0900
      v14_emerald_1gpu_01_fib,dec,0.091747761,2020-05-02 13:00:49 +0900
      v14_emerald_1gpu_01_fib,ctxt_size,2596634717,2020-05-02 13:00:49 +0900

      v15_emerald_1gpu_wCM_01_fib,cc,0.085423988,2020-05-04 17:00:07 +0900
      v15_emerald_1gpu_wCM_01_fib,elf_text_size,47,2020-05-04 17:00:07 +0900
      v15_emerald_1gpu_wCM_01_fib,emu,0.193619438,2020-05-04 17:00:07 +0900
      v15_emerald_1gpu_wCM_01_fib,num_cycles,38,2020-05-04 17:00:07 +0900
      v15_emerald_1gpu_wCM_01_fib,genkey,0.008822996,2020-05-04 17:00:07 +0900
      v15_emerald_1gpu_wCM_01_fib,enc,50.486236335,2020-05-04 17:00:58 +0900
      v15_emerald_1gpu_wCM_01_fib,run,162.875772665,2020-05-04 17:03:41 +0900
      v15_emerald_1gpu_wCM_01_fib,dec,0.081024659,2020-05-04 17:03:41 +0900
      v15_emerald_1gpu_wCM_01_fib,ctxt_size,2613051560,2020-05-04 17:03:41 +0900
=end

require "csv"

# Thanks to: https://stackoverflow.com/a/7749613
module Enumerable
  def sum
    self.inject(0) { |accum, i| accum + i }
  end

  def mean
    self.sum / self.length.to_f
  end

  def sample_variance
    m = self.mean
    sum = self.inject(0) { |accum, i| accum + (i - m) ** 2 }
    sum / (self.length - 1).to_f
  end

  def standard_deviation
    Math.sqrt(self.sample_variance)
  end
end

# Thanks to ActiveSupport
class Hash
  # File activesupport/lib/active_support/core_ext/hash/slice.rb, line 23
  def slice(*keys)
    keys.each_with_object(Hash.new) { |k, hash| hash[k] = self[k] if has_key?(k) }
  end
end

def yn(b)
  if b then "Y" else "N" end
end

def log2csv(machine_name, filepaths)
  # Normalize data
  #  [
  #    {
  #      kvsp_version: positive number,
  #      gpus: zero or positive number,
  #      program: "01_fib" | "02_hamming" | "03_bf",
  #      processor: :diamond | :emerald,
  #      cmuxmem: boolean,
  #    }
  #  ]
  #
  normalized_data = []
  filepaths.each do |filepath|
    CSV.foreach(filepath) do |row|
      normalized_row = case row[0]
        when /^v11_([0-9]+_[a-z]+)_(gpu|cpu)$/
          {
            kvsp_version: 11,
            gpus: $2 == "cpu" ? 0 : 1,
            program: $1,
            processor: :emerald,
            cmuxmem: true,
          }
        when /^v12_([0-9]+_[a-z]+)_(cpu|([0-9]+)gpu)$/
          {
            kvsp_version: 12,
            gpus: $2 == "cpu" ? 0 : $3.to_i,
            program: $1,
            processor: :emerald,
            cmuxmem: true,
          }
        when /^v([0-9]+)_(emerald|diamond)_([0-9]+)gpus?(?:_(wCM|woCM))?_([0-9]+_[a-z]+)$/
          {
            kvsp_version: $1.to_i,
            gpus: $3.to_i,
            program: $5,
            processor: $2 == "emerald" ? :emerald : :diamond,
            cmuxmem: $4 != "woCM",
          }
        else
          next
        end
      normalized_row[:action] = row[1]
      normalized_row[:data] = row[2..]
      normalized_data.push normalized_row
    end
  end

  # Non-trivial selection of data.
  # 1. Since v16 and above has optimized mux-ram, <=v15 are meaningless.
  normalized_data.select! do |row|
    # 1. Remove <=v15 if it does not use CMUX Memory.
    next false if row[:kvsp_version] <= 15 and not row[:cmuxmem]

    # All tests passed.
    true
  end

  # Make table from data
  table = {}
  normalized_data.each do |row|
    key = row.slice(:gpus, :processor, :cmuxmem, :program)
    table[key] ||= {
      num_cycles: nil,
      runtime: [],
    }

    case row[:action]
    when "num_cycles"
      ncycles = row[:data][0].to_i
      table[key][:num_cycles] ||= ncycles
      unless table[key][:num_cycles] == ncycles
        raise "Invalid data: inconsistent # of cycles"
      end
    when "run"
      table[key][:runtime].push(row[:data][0].to_f)
    end
  end

  sio = StringIO.new
  table.each do |key, value|
    machine = if key[:gpus] == 0
        machine_name
      else
        "#{machine_name} w/ V100x#{key[:gpus]}"
      end
    superscalar = yn(key[:processor] == :emerald)
    cmuxmem = yn(key[:cmuxmem])
    program = case key[:program]
      when "01_fib"
        "Fibonacci"
      when "02_hamming"
        "Hamming"
      when "03_bf"
        "Brainf*ck"
      else
        raise "Invalid program"
      end
    num_cycles = value[:num_cycles]
    runtime = value[:runtime].mean.round(2)
    sec_per_cycle = (value[:runtime].mean / value[:num_cycles]).round(2)

    sio.print [
                machine,
                superscalar,
                cmuxmem,
                program,
                num_cycles,
                runtime,
                sec_per_cycle,
              ].join(" & ")
    sio.puts " \\\\"
  end

  sio.string
end

puts "% machine & w/ super-scalar & w/ CMUX Memory & program & \# of cycles & runtime & sec./cycle\\\\"
Dir.each_child(ARGV[0]) do |machine_name|
  filepaths = Dir.glob("#{ARGV[0]}/#{machine_name}/*.log")
  puts log2csv(machine_name, filepaths)
end
