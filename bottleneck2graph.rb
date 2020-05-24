#!/usr/bin/ruby

require "optparse"
require "csv"
require "time"
require "gnuplot"

params = ARGV.getopts("f:t:").map { |k, v| [k.to_sym, v] }.to_h
params[:f] = if params[:f].nil? then 0 else params[:f].to_i end
params[:t] = if params[:t].nil? then -1 else params[:t].to_i end

unless ARGV.size == 2
  raise "Usage: ruby bottleneck2graph.rb [-f START-CLOCK] [-t END-CLOCK] FASTSTAT-LOG-FILE KVSP-LOG-FILE"
end

faststat_log_file = ARGV[0]
kvsp_log_file = ARGV[1]
faststat_log = CSV.read(faststat_log_file)[1..-1].map { |row|
  [Time.strptime(row[0], "%Y-%m-%d %H:%M:%S.%L")] + row[1..-1].map(&:to_f)
}
kvsp_log = CSV.read(kvsp_log_file).map { |row|
  [Time.strptime(row[0], "%Y-%m-%d %H:%M:%S.%L"), row[1]]
}.select { |row| row[1] == "start" }

unless faststat_log.size > 0 and kvsp_log.size > 0
  raise "Invalid log files"
end

epoch_time = kvsp_log[0][0]
start_time = kvsp_log[params[:f]][0]
end_time = kvsp_log[params[:t]][0]
faststat_log = faststat_log.select { |row| start_time <= row[0] and row[0] <= end_time }
kvsp_log = kvsp_log.select { |row| start_time <= row[0] and row[0] <= end_time }

cpu_stat = faststat_log.map { |row|
  [
    row[0] - epoch_time,
    100 - row[4],  # total - idle
  ]
}.transpose
gpu_stat = faststat_log.map { |row| [row[0] - epoch_time, row[11]] }.transpose

Gnuplot.open do |gp|
  Gnuplot::Plot.new(gp) do |plot|
    plot.title "#{faststat_log_file}, #{kvsp_log_file}"
    plot.ylabel "Usage"
    plot.xlabel "Time"
    plot.xrange "[#{start_time - epoch_time}:#{end_time - epoch_time}]"
    plot.set "size ratio 0.25"

    kvsp_log.each do |row|
      x = row[0] - epoch_time
      plot.arrow "from first #{x}, graph 0 to #{x}, graph 1 nohead lw 1 lc rgb 'red'"
    end

    plot.data << Gnuplot::DataSet.new(cpu_stat) do |ds|
      ds.title = "CPU"
      ds.with = "lines"
      ds.linewidth = 0.5
    end

    plot.data << Gnuplot::DataSet.new(gpu_stat) do |ds|
      ds.title = "GPU"
      ds.with = "lines"
      ds.linewidth = 0.5
    end
  end
end
