#!/usr/bin/ruby

require "toml-rb"

def change_blueprint(path, cmux_memory)
  blueprint = TomlRB.load_file(path)
  blueprint["builtin"].each do |builtin|
    case builtin["type"]
    when "rom", "mux-rom"
      builtin["type"] = cmux_memory ? "rom" : "mux-rom"
    when "ram", "mux-ram"
      builtin["type"] = cmux_memory ? "ram" : "mux-ram"
    end
  end
  open(path, "w") do |fh|
    fh.write(TomlRB.dump(blueprint))
  end
end

if __FILE__ == $0
  require "optparse"

  params = ARGV.getopts("", "cmux-memory")
  params["cmux-memory"] ||= false
  raise "Usage: #{$0} [--cmux-memory] blueprint-path" unless ARGV.size == 1
  change_blueprint ARGV[0], params["cmux-memory"]
end
