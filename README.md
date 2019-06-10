# Ruby::Flamegraph

A Ruby gem for generating stacktrace profile flamegraphs. Profiling is done via RubyProf, and folded stack file generation is done by https://github.com/oozou/ruby-prof-flamegraph. Most of the logic in this gem is rendering folded stack files as flamegraphs.

Inspiration is from Brendan Gregg's https://github.com/brendangregg/FlameGraph written in Perl. I created this gem to be able to generate Ruby flamegraphs without shelling out to Perl.

## Example

```ruby
# This returns an HTML document
RubyFlamegraph.profile(width: 1600) {
  User.where(id: (1..5000).to_a).to_a
}
```

![](https://i.imgur.com/oGAjc1v.png)

## Interactivity

Current interactivity:
 - Hover to show detailed info for a node

Planned interactivity:
 - Click node to zoom
 - Regexp search for node names
