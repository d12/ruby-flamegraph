# Ruby::Flamegraph

A Ruby gem for generating stacktrace profile flamegraphs. Profiling is done via RubyProf, and folded stack file generation is done by https://github.com/oozou/ruby-prof-flamegraph. Most of the logic in this gem is rendering folded stack files as flamegraphs.

## Example

```ruby
RubyFlamegraph.profile(width: 1600) {
  User.where(id: (1..5000).to_a).to_a
}
```

![](https://i.imgur.com/oGAjc1v.png)
