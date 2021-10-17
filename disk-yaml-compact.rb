#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'pp'

MAX_DISTANCE = 6

def levenshtein_distance(s, t)
  m = s.length
  n = t.length
  return [m, []] if n.zero?
  return [n, []] if m.zero?
  d = Array.new(m + 1) { Array.new(n + 1) }
  changes = []

  (0..m).each { |i| d[i][0] = i }
  (0..n).each { |j| d[0][j] = j }
  (1..n).each do |j|
    (1..m).each do |i|
      d[i][j] =
        if s[i - 1] == t[j - 1]  # adjust index into string
          d[i - 1][j - 1]        # no operation required
        else
          [
            d[i - 1][j] + 1,      # deletion
            d[i][j - 1] + 1,      # insertion
            d[i - 1][j - 1] + 1,  # substitution
          ].min
        end
      #      print "%3d"%d[i][j]
    end
    #    puts ""
  end

  last = d[m][n]
  i = m
  j = n
  flag = :no_diff
  loop do
    # warn "#{last}: i=#{i};j=#{j}"
    break if i.zero? && j.zero?
    i2 = i.zero? ? 0 : i - 1
    j2 = j.zero? ? 0 : j - 1
    last2 = last - 1
    flag2 = :no_diff
    if d[i2][j2] == last2
      i = i2
      j = j2
    elsif d[i][j2] == last2
      j = j2
    elsif d[i2][j] == last2
      i = i2
    else
      # warn "-> i=#{i};j=#{j}"
      flag2 = :diff
      last2 = last
      if d[i2][j2] == last
        i = i2
        j = j2
      elsif d[i][j2] == last
        j = j2
      elsif d[i2][j] == last
        i = i2
      end
    end
    last = last2
    changes << i if flag != flag2
    flag = flag2
  end
  [d[m][n], changes]
end

def my_tostr(a)
  return a if a.is_a? String
  return a.keys[0] if a.is_a? Hash
  warn "Ooops! a is a #{a.class}"
  a.to_s
end

def check_list(list)
  new_list = []
  last = nil
  collapsed = nil
  list.sort { |a, b| my_tostr(a) <=> my_tostr(b) }.each do |el|
    if el.is_a? Hash
      k = el.keys[0]
      new_list << { k => check_list(el[k]) }
    elsif last.nil?
      # new_list << el
      last = el
    else
      (distance, changes) = levenshtein_distance(last, el)
      if distance > MAX_DISTANCE
        new_list << collapsed if collapsed
        new_list << last
        last = el
        collapsed = nil
      else
        # begin
        changes.reverse!
        # c=changes.clone
        string =
          if changes[0].zero? # first letters are different!
            changes[1] ||= last.length
            last[changes[0], changes[1] - changes[0]]
          else
            # changes[0] ||= last.length
            last[0, changes[0]]
          end
        # rescue => e
        #   warn "---> #{e.message}"
        #   warn "last: #{last}"
        #   warn "curr: #{el}"
        #   warn "changes: #{changes.join(';')} / #{c.join(';')}"
        # end
        warn "#{last} -> #{changes} -> #{string}"
        collapsed = "*** %s" % string
      end
    end
  end
  new_list << collapsed if collapsed
  new_list
end

if ARGV[0].nil?
  warn 'No file specified'
  exit 1
end

list = []
begin
  text = File.read(ARGV[0])
  list = YAML.safe_load(text)
rescue => e
  warn "Oops! #{e.message}"
  exit 2
end

list2 = check_list(list[list.keys[0]])
puts list2.to_yaml
