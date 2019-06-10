require "rubyflamegraph/version"

require "ruby-prof"
require 'ruby-prof-flamegraph'
require 'benchmark'
require 'erb'

class RubyFlamegraph
  def profile(width: 2000, &block)
    result = ::RubyProf.profile do
      yield
    end

    folded_stack = folded_stack(result)
    stack_trace_tree = build_stack_trace_tree(folded_stack)

    total_time_spent = stack_trace_tree[:TIME_SPENT].to_f

    flamegraph_erb = File.read(File.join(File.dirname(__FILE__), "rubyflamegraph", "views", "flamegraph.html.erb"))
    node_erb = File.read(File.join(File.dirname(__FILE__), "rubyflamegraph", "views", "node.html.erb"))

    erb = ERB.new(flamegraph_erb)
    html = erb.result_with_hash(width: width, node_erb: node_erb, total_time_spent: total_time_spent, stack_trace_tree: stack_trace_tree)

    puts html
  end

  private

  # Given a rubyprof profile, use RubyProf::FlameGraphPrinter to generate a folded stack file.
  # Thread and Fiber lines are filtered out.
  #
  # E.g. return value
  #
  # [
  #  ["RubyFlameGraph#profile (1) 1.04"],
  #  ["RubyFlameGraph#profile (1)", "Array.map (1) 4.52"],
  #  ["RubyFlameGraph#profile (1)", "Array.map (1)", "FixNum#- (500) 25.35"],
  #  ["RubyFlameGraph#profile (1)", "main.puts (1) 3.09"]
  # ]
  def folded_stack(profile)
    string_io = StringIO.new
    new_printer = RubyProf::FlameGraphPrinter.new(profile).print(string_io)
    raw_string = string_io.string

    lines = raw_string.lines.map do |s|
      string_segments = s.strip.split(";")

      line_segments = []
      string_segments.each do |segment|
        line_segments << segment unless (segment.start_with?("Thread:") || segment.start_with?("Fiber:"))
      end

      line_segments
    end
  end

  # Given the folded stack, generate the flamegraph stack trace tree.
  # The time indicated on each line of the folded stack is only the time for that particular method
  # But in a flamegraph, if foo calls bar, bar's runtime is included in foo.
  # While building this tree, we add method runtimes to each ancestor method
  def build_stack_trace_tree(folded_stack_lines)
    tree = {}
    folded_stack_lines.each do |line|
      current_pos = tree

      line_length = line.length
      next if line_length == 0

      match  = line.last.match(/(.+)\s(\d+\.?\d*)\z/)
      next unless match && match.captures[1]

      time_spent = match.captures[1].to_f

      line.each_with_index do |line_seg, i|
        if i == line.length - 1
          name, time_spent = line_seg.match(/(.+)\s(\d+\.?\d*)\z/).captures

          current_pos[:CHILDREN] ||= {}
          current_pos[:CHILDREN][name] = {}
          current_pos[:CHILDREN][name][:TIME_SPENT] = time_spent.to_f
          current_pos[:CHILDREN][name][:NAME] = name
        else
          current_pos[:CHILDREN][line_seg][:TIME_SPENT] ||= 0.0
          current_pos[:CHILDREN][line_seg][:TIME_SPENT] += time_spent

          current_pos = current_pos[:CHILDREN][line_seg]
        end
      end
    end

    tree[:CHILDREN].values.first
  end
end
