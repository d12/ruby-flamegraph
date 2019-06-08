require "rubyflamegraph/version"

require "ruby-prof"
require 'ruby-prof-flamegraph'
require 'benchmark'
require 'erb'

class RubyFlamegraph
  def profile(&block)
    result = ::RubyProf.profile do
      yield
    end

    folded_stack = folded_stack(result)
    stack_trace_tree = build_stack_trace_tree(folded_stack)

    @total_time_spent = stack_trace_tree[:TIME_SPENT].to_f
    @width = 2000

    erb = ERB.new <<-ERB
      <html>
      <head>
        <style>
          span {
            font-family:verdana;
            font-size:12px;
          }

          .node-wrapper {
            display:flex;
            flex-direction:column-reverse;
          }

          .node-children {
            display:flex;
            flex-direction:row;
            justify-content:flex-end;
          }

          .text {
            text-overflow:ellipsis;
            padding-left:3px;
            display:block;
            width:100%;
            white-space:nowrap;
            overflow:hidden;
            height:15px;
            border-radius:2px;
          }

          .text-wrapper {
            padding-bottom:2px;
            display:flex;
            margin-left:0px;
            margin-top:1px;
            margin-bottom:1px;
          }
        </style>
      </head>
      <center><h1>Flame Graph!</h1></center>
        <div id="flamegraph" class="node-wrapper">
          <%= process_node(stack_trace_tree) %>
          </div>
     </html>
    ERB

    html = erb.result(binding)

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

  # Renders a node in the flamegraph. This method is recursive, as nodes have children
  # which must be rendered.
  #
  # We omit nodes that don't reach the minimum node width because every HTML node
  # has a bit of overhead (padding/margins). We get front end issues trying to render
  # a node that's smaller than the size of it's padding/margins.
  def process_node(node)
    node_width  = (@width * (node[:TIME_SPENT].to_f / @total_time_spent)).to_i
    color = ["#9b2948", "#ff7251", "#ffca7b", "#ffcd74", "#ffedbf"]
    minimum_node_width = 5

    erb = ERB.new <<-ERB
      <% if node_width > minimum_node_width %>
        <div class="text-wrapper" style='width:<%= node_width %>;'>
          <span class="text" style='background-color:<%= color.sample %>;'><%= node[:NAME] %>
        </div>
        <div style='width:<%= node_width %>;' class="node-children">
          <% node[:CHILDREN].each do |k, child| %>
            <div class="node-wrapper">
              <%= process_node(child) %>
            </div>
          <% end if node[:CHILDREN] %>
        </div>
      <% end %>
    ERB

    erb.result(binding)
  end
end
