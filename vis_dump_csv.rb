require "csv"
require "time"

raise "Usage: #{$0} IN-FILE OUT-FILE" unless ARGV.size == 2

TIME_FORMAT = "%Y-%m-%d %H:%M:%S.%L"

# Read data
rows = []
CSV.foreach(ARGV[0]) do |row|
  rows.push({
    start: Time.strptime(row[0], TIME_FORMAT),
    end: Time.strptime(row[1], TIME_FORMAT),
    index: row[2].to_i,
    id: row[3].to_i,
    kind: row[4].to_s,
    desc: row[5].to_s,
  })
end
rows.sort! do |a, b|
  next 1 if a[:start] > b[:start]
  next -1 if a[:start] < b[:start]
  next 1 if a[:end] > b[:end]
  next -1 if a[:end] < b[:end]
  0
end

# Find epoch and normalize start/end
epoch = rows[0][:start]
cell_width = 0.010 # sec
rows.each do |row|
  row[:start_cell] = ((row[:start] - epoch) / cell_width).round
  row[:end_cell] = ((row[:end] - epoch) / cell_width).round
end

# Make graph
csv_string = CSV.generate do |csv|
  rows.each do |row|
    out = []
    out.fill 1, (row[:start_cell]..row[:end_cell])
    out = [row[:start].strftime(TIME_FORMAT), row[:end].strftime(TIME_FORMAT), row[:index], row[:id], row[:kind], row[:desc]] + out
    csv << out
  end
end
open(ARGV[1], "wb").puts csv_string
