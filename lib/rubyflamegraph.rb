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

    File.open("test.html", "w") do |f|
      f.puts html
    end
    puts html
  end

  private

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

  def build_stack_trace_tree(folded_stack_lines)
    tree = {NAME: "Top Level"}
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

    tree[:TIME_SPENT] = tree[:CHILDREN].values[0][:TIME_SPENT]

    tree
  end
end
