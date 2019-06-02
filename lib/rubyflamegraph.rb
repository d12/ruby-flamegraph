require "rubyflamegraph/version"

require "ruby-prof"
require 'ruby-prof-flamegraph'
require 'benchmark'
require 'erb'

class FlameGraphPrinterToLines
  def initialize
    @lines = []
  end

  def puts(string)
    string_segments = string.split(";")

    line_segments = []
    string_segments.each do |segment|
      line_segments << segment unless (segment.start_with?("Thread:") || segment.start_with?("Fiber:"))
    end

    @lines << line_segments
  end

  def lines
    @lines
  end
end

class RubyFlamegraph
  def foo(&block)
    result = ::RubyProf.profile do
      yield
    end

    printer = RubyProf::FlameGraphPrinter.new(result)
    stack_trace = FlameGraphPrinterToLines.new

    printer.print(stack_trace, {})

    lines = stack_trace.lines

    @chart = {NAME: "Top Level"}
    lines.each do |line|
      current_pos = @chart

      line_length = line.length
      match  = line.last.match(/(.+)\s(\d+\.?\d*)\z/)
      next unless match && match.captures[1]
      time_spent = match.captures[1].to_f

      line.each_with_index do |line_seg, i|
        if i == line.length - 1
          # End of the line, add an entry in the @chart
          # First, remove the time spent from name
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

    @chart[:TIME_SPENT] = @chart[:CHILDREN].values[0][:TIME_SPENT]

    @total_time_spent = @chart[:TIME_SPENT].to_f
    @width = 16000

    def process_node(node)
      @node = node
      @node_width  = (@width * (node[:TIME_SPENT].to_f / @total_time_spent)).to_i
      @color = ["#9b2948", "#ff7251", "#ffca7b", "#ffcd74", "#ffedbf"]

      erb = ERB.new <<-ERB
        <div style='padding-bottom:2px;display:flex;width:<%= @node_width %>;margin-left:1px;margin-top:1px;margin-bottom:1px;'>
          <span style='text-overflow:ellipsis;display:block;width:100%;white-space: nowrap;overflow:hidden;height:15px;border-radius:2px;padding-left:4px;background-color:<%= @color.sample %>;'><%= @node[:NAME] %>
        </div>
        <div style='display:flex;flex-direction:row;width:<%= @node_width %>'>
          <div class="filler" style="flex-grow:1"></div>
          <% @node[:CHILDREN].each do |k, child| %>
            <div style='display:flex;flex-direction:column-reverse;'>
              <%= process_node(child) %>
            </div>
          <% end if @node[:CHILDREN] %>
        </div>
      ERB

      erb.result(binding)
    end

    erb = ERB.new <<-ERB
      <html>
      <center><h1>Flame Graph!</h1></center>
        <div id="flamegraph" style='display:flex; flex-direction:column-reverse;font-family:verdana;font-size:12px;'>
          <%= process_node(@chart) %>
          </div>
     </html>
    ERB

    html = erb.result(binding)

    File.open("test.html", "w") do |f|
      f.puts html
    end
    puts html
  end
end
