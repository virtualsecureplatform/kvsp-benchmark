#!/usr/bin/ruby

require "shellwords"
require "open3"
require "pathname"
require "csv"
require "optparse"
require "json"

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
  def self.path
    @@path
  end

  def self.open(path)
    @@path = path
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
  def initialize(version:, superscalar:, num_gpus:)
    @kvsp_path = Pathname.new("kvsp_v#{version}")
    @cahp_proc = superscalar ? "emerald" : "diamond"
    @cahp_proc_llvm = superscalar ? "emerald" : "generic"
    @num_gpus = num_gpus
    #@use_cmux_memory = use_cmux_memory

    @id_prefix = "v#{version}_#{@cahp_proc}_#{@num_gpus}gpu_"
  end

  def bench(c_path, cmd_options)
    id = @id_prefix + c_path.basename(".*").to_s

    # Compile
    #kvsp_run id, ["cc", c_path.to_s, "-o", "_elf", "-mcpu=#{@cahp_proc_llvm}"]
    kvsp_run id, ["cc", c_path.to_s, "-o", "_elf"]
    Logger.log [id, "elf_text_size", get_elf_text_size("_elf")]

    # Emulate to get necessary # of cycles
    emu_res = kvsp_run id, ["emu", "--cahp-cpu", @cahp_proc, "_elf"], cmd_options
    raise "cycle estimation failed" unless emu_res =~ /^#cycle\t([0-9]+)$/
    num_cycles = $1
    Logger.log [id, "num_cycles", num_cycles]

    # Run
    kvsp_run id, ["genkey", "-o", "_secret.key"]
    kvsp_run id, ["enc", "-k", "_secret.key", "-i", "_elf", "-o", "_req.packet"], cmd_options
    kvsp_run id, ["run", "-i", "_req.packet", "-o", "_res.packet", "-c", num_cycles, "-g", @num_gpus, "--cahp-cpu", @cahp_proc]
    kvsp_run id, ["dec", "-k", "_secret.key", "-i", "_res.packet"]

    ctxt_size = run_command "du", ["-b", "_req.packet"]
    raise "du failed" unless ctxt_size =~ /^([0-9]+)\t_req\.packet$/
    Logger.log [id, "ctxt_size", $1]
  end

  private

  def kvsp_run(id, args0 = [], args1 = [])
    args = args0 + args1
    start_time = Time.now
    res = run_command (@kvsp_path / "bin" / "kvsp").to_s, args
    end_time = Time.now
    elapsed = end_time - start_time
    Logger.log [id, args[0], elapsed]
    res
  end

  def get_elf_text_size(path)
    readelf = run_command (@kvsp_path / "bin" / "llvm-readelf").to_s, ["-S", "_elf"]
    line = readelf.lines.filter { |line| line.include?(" .text ") }[0]
    raise "Invalid readelf result" if line.nil?
    size = line.split(/ +/)[7]
    raise "Invalid readelf result" if size.nil?
    size.to_i(16)
  end
end

# Parse command-line options
# Default is all off
version = nil
num_gpus = 0
superscalar = false
cmux_memory = false
opt = OptionParser.new
opt.on("--kvsp-ver VERSION") { |v| version = v.to_i }
opt.on("-g NGPUS") { |v| num_gpus = v.to_i }  # GPU
opt.on("--superscalar") { |v| superscalar = v } # super-scalar
opt.on("--cmux-memory") { |v| cmux_memory = v } # CMUX Memory # FIXME
opt.parse!(ARGV)
raise "Specify KVSP version with option --kvsp-ver" if version.nil?

# Prepare
Logger.open(Time.now.strftime "%Y%m%d_%H%M.log")
runner = KVSPRunner.new(version: version,
                        superscalar: superscalar,
                        num_gpus: num_gpus)
program_and_data = [
  ["01_fib.c", ["5"]],
  ["02_hamming.c", ["10", "10", "10", "10", "de", "ad", "be", "ef"]],
  ["03_bf.c", ["++++[>++++++++++<-]>++"]],
].map { |p| [Pathname.new(p[0]), p[1]] }

# Run
program_and_data.each do |p|
  runner.bench *p
end

# Send the result to Slack if possible
if ENV.key?("SLACK_API_TOKEN") && ENV.key?("SLACK_CHANNEL")
  require "slack-ruby-client"

  Slack.configure do |config|
    config.token = ENV["SLACK_API_TOKEN"]
  end
  client = Slack::Web::Client.new
  client.auth_test

  title = Pathname.new(Logger.path).basename.to_s
  spec = { version: version, num_gpus: num_gpus, superscalar: superscalar, cmux_memory: cmux_memory }
  client.files_upload channels: ENV["SLACK_CHANNEL"],
                      content: open(Logger.path).read,
                      title: title,
                      initial_comment: JSON.pretty_generate(spec)
end
