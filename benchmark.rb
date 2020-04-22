#!/usr/bin/ruby

require "shellwords"
require "open3"
require "pathname"
require "csv"
require "optparse"

def quote(str, prefix = "> ")
  prefix + str.gsub("\n", "\n#{prefix}")
end

def run_command(command, args = [])
  path = command
  res, err, code = Open3.capture3("#{Shellwords.join([path.to_s] + args)}")
  raise "Unexpected status code: #{code}\n#{quote(res)}\n#{quote(err)}" if code != 0
  res
end

class Logger
  def self.open(path)
    @@csv = CSV.open(path, "wb")
  end

  def self.log(args)
    data = args.dup
    data << Time.now

    $stderr.puts(CSV.generate { |csv| csv << data })

    raise "hoge" if @@csv.nil?
    @@csv << data
  end
end

class KVSPRunner
  def initialize(path)
    @kvsp_path = (Pathname.new(path) / "bin" / "kvsp").to_s
  end

  def run(id, args = [])
    start_time = Time.now
    res = run_command @kvsp_path, args
    end_time = Time.now
    elapsed = end_time - start_time
    Logger.log [id, args[0], elapsed]
    res
  end
end

def benchmark_kvsp(id, kvsp, elf_path, num_gpus, cmd_options = [])
  emu_res = kvsp.run id, (["emu", elf_path] + cmd_options)
  raise "cycle estimation failed" unless emu_res =~ /^#cycle\t([0-9]+)$/
  num_cycles = $1
  Logger.log [id, "num_cycles", num_cycles]

  kvsp.run id, ["genkey", "-o", "_secret.key"]
  kvsp.run id, (["enc", "-k", "_secret.key", "-i", elf_path, "-o", "_req.packet"] + cmd_options)
  kvsp.run id, ["run", "-i", "_req.packet", "-o", "_res.packet", "-c", num_cycles, "-g", num_gpus]
  kvsp.run id, ["dec", "-k", "_secret.key", "-i", "_res.packet"]

  ctxt_size = run_command "du", ["-b", "_req.packet"]
  raise "du failed" unless ctxt_size =~ /^([0-9]+)\t_req\.packet$/
  Logger.log [id, "ctxt_size", $1]
end

Logger.open(Time.now.strftime "%Y%m%d_%H%M.log")

num_gpus = 0
opt = OptionParser.new
opt.on("-g NGPUS") { |v| num_gpus = v.to_i }
opt.parse!(ARGV)

runners = {}
runners["v12"] = KVSPRunner.new "kvsp_v12" # With emerald
#runners["v10"] = KVSPRunner.new "kvsp_v10" # With emerald
#runners["v9"] = KVSPRunner.new "kvsp_v9"   # CB on CPU for RAM with CUDA
#runners["v8"] = KVSPRunner.new "kvsp_v8"   # CB on CPU for ROM with CUDA
#runners["v5"] = KVSPRunner.new "kvsp_v5"   # CB on CPU for ROM and RAM without CUDA
#runners["v3"] = KVSPRunner.new "kvsp_v3"   # Naive implementation on CPU and CUDA

mode = if num_gpus > 0 then "#{num_gpus}gpu" else "cpu" end
10.times do
  runners.each do |name, runner|
    benchmark_kvsp "#{name}_01_fib_#{mode}", runner, "elf/01_fib", num_gpus, ["5"]
    benchmark_kvsp "#{name}_02_hamming_#{mode}", runner, "elf/02_hamming", num_gpus,
                   ["10", "10", "10", "10", "de", "ad", "be", "ef"]
    benchmark_kvsp "#{name}_03_bf_#{mode}", runner, "elf/03_bf", num_gpus, ["++++[>++++++++++<-]>++"]
  end
end
