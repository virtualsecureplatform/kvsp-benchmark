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
require "pretty_round"

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
  if b then "Yes" else "No" end
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
        when /^v([0-9]+)_(emerald|diamond|ruby|pearl)_([0-9]+)gpus?(?:_(wCM|woCM))?_([0-9]+_[a-z]+)$/
          {
            kvsp_version: $1.to_i,
            gpus: $3.to_i,
            program: $5,
            processor: $2.to_sym,
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
  # 1. <=v23 have different architectures, so doesn't matter.
  # 2. only cahp-pearl and cahp-ruby does matter.
  normalized_data.select! do |row|
    # 1. <=v23 have different architectures, so doesn't matter.
    next false if row[:kvsp_version] <= 23
    # 2. only cahp-pearl and cahp-ruby does matter.
    next false unless [:pearl, :ruby].include? row[:processor]

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

  # Sort table
  table = table.sort do |l, r|
    # :gpus
    next 1 if l[0][:gpus] > r[0][:gpus]
    next -1 if l[0][:gpus] < r[0][:gpus]

    # :processor
    tbl = { diamond: 0, emerald: 1, ruby: 3, pearl: 2 }
    next 1 if tbl[l[0][:processor]] > tbl[r[0][:processor]]
    next -1 if tbl[l[0][:processor]] < tbl[r[0][:processor]]

    # :cmuxmem
    tbl = { false => 0, true => 1 }
    next 1 if tbl[l[0][:cmuxmem]] > tbl[r[0][:cmuxmem]]
    next -1 if tbl[l[0][:cmuxmem]] < tbl[r[0][:cmuxmem]]

    l[0][:program] <=> r[0][:program]
  end.to_h

  sio = StringIO.new
  table.each do |key, value|
    machine = machine_name
    pipeline = yn(key[:processor] == :ruby)
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
    ntries = value[:runtime].size

    if value[:runtime].length == 1 then
      runtime = sprintf("$%.1f \\pm NaN$", value[:runtime].mean)
      sec_per_cycle = sprintf("$%.02f \\pm NaN$", value[:runtime].mean / value[:num_cycles])
    else
      runtimestdv = value[:runtime].standard_deviation
      runtimemean = value[:runtime].mean
      runtimedigit = (Math.log10(runtimemean)-Math.log10(runtimestdv)).floor + 1
      runtime = sprintf("$%.1f \\pm %.1f$", runtimemean.sround(runtimedigit+1),runtimestdv)
      sec_per_cycle = sprintf("$%.03f \\pm %.3f$", runtimemean / num_cycles,runtimestdv/num_cycles)
    end

    sio.print [
                machine,
                key[:gpus],
                pipeline,
                cmuxmem,
                program,
                num_cycles,
                runtime,
                sec_per_cycle,
              ].join(" & ")
    sio.print " \\\\"
    sio.puts "%\t#{value[:runtime].standard_deviation}\t#{ntries} #{if ntries == 1 then "try" else "tries" end}"
  end

  sio.string
end

puts "% Machine & \\# of V100 & Pipelining? & CMUX Memory? & Program & \\# of cycles & Runtime & sec./cycle\\\\"
Dir.each_child(ARGV[0]) do |machine_name|
  filepaths = Dir.glob("#{ARGV[0]}/#{machine_name}/*.log")
  s = log2csv(machine_name, filepaths)
  puts s unless s.empty?
end
