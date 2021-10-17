#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'pp'

MAX_DISTANCE = 8
MIN_CUT = 4
WHITE_DIRS = ['00_VID', '10_DVD']

BLACKLIST = [
  Regexp.new('^bonus', Regexp::IGNORECASE),
  Regexp.new('^(rus )?subs?', Regexp::IGNORECASE),
  Regexp.new('^mkv', Regexp::IGNORECASE)
].freeze

class MyStr
  def initialize(str, count, path = nil)
    @str = str
    @count = count
    @path = path
  end

  def to_h
    { 'str' => @str, 'count' => @count, 'path' => @path }
  end

  def to_s
    to_h.to_s
  end

  def path=(p)
    @path = p
    self
  end
end

#
# Convert almost any type to reasonable string
# @param [a] any string, hash, or something else...
#
# @return String string representation
def my_tostr(a)
  return a if a.is_a? String
  return a.keys[0] if a.is_a? Hash
  warn "Ooops! a is a #{a.class}"
  a.to_s
end

def my_ord c
  c.between?('0', '9') ? 0 : c.downcase.ord
end

def string_diff(a, b)
  len = [a.size, b.size].min
  b_ord = b.chars.map { |c| my_ord c }
  ret = []
  a.chars[0..len].each_with_index do |c, i|
    next if (my_ord(c) == b_ord[i])
    ret << i
  end
  ret
end

# def check_for_similarity(list)
#   last = nil
#   # warn "list=#{list}"
#   # exclude_blacklisted(list.map { |e| my_tostr(e) })
#   # .sort { |a, b| my_tostr(a) <=> my_tostr(b) }
#   list
#     .each do |el|
#       s = my_tostr(el)
#       # warn "el=#{s}"
#       next if BLACKLIST.any? { |re| re =~ s }
#       unless last.nil?
#         diff = string_diff last, s
#         warn "d=#{diff.size} // #{last} // #{s}"
#         return false if diff.size > MAX_DISTANCE
#       end
#       last = s
#     end
#   true
# end

def cut_title(title, count, diff)
  cut = if count > 1 then title.size
        elsif diff[0] > MIN_CUT then diff[0] else title.size
        end
  # "#{title[0..cut]}#{count > 1 ? " (#{count})" : ''}".tr('_', ' ')
  MyStr.new(title[0..cut].tr('_', ' '), count)
end

def squeeze_list(list, title)
  last = nil
  # warn "list=#{list}"
  # exclude_blacklisted(list.map { |e| my_tostr(e) })
  new_list = []
  count = 0
  list
    .sort { |a, b| my_tostr(a) <=> my_tostr(b) }
    .each do |el|
      if el.is_a? Hash
        k = el.keys[0]
        squeezed_list = squeeze_list(el[k], k)
        new_list <<
          if squeezed_list.size == 1
            squeezed_list[0]
          else
            { k => squeezed_list }
          end
      else
        s = my_tostr(el)
        next if BLACKLIST.any? { |re| re =~ s }
        unless last.nil?
          diff = string_diff last, s
          # warn "d=#{diff.size} // #{last} // #{s}"
          if diff.size > MAX_DISTANCE
            new_list << cut_title(last, count, diff)
            count = 0
          end
        end
        count += 1
        last = s
      end
    end
  if new_list.size.positive?
    # something is pushed already
    new_list << cut_title(last, count, [0]) if last
  else
    new_list << cut_title(title, count, [0])
  end
  new_list
end

def squeeze_disk(list, name)
  return nil unless list && list[list.keys[0]]
  l3 = list[list.keys[0]].select do |x|
    x.is_a?(Hash) &&
      x.keys.any? { |z| WHITE_DIRS.include?(z) }
  end
  { name => squeeze_list(l3, name) }
end

def short_path(str, path = nil)
  if str.is_a? String
    # warn ">> #{str}"
    MyStr.new(str, 0, path)
  elsif str.is_a? MyStr
    # warn "!! #{str}"
    # path ? "#{str} [#{path}]" : str
    str.path = path
    str
  elsif str.is_a? Array
    str.map { |s| short_path(s, path) }
  else
    short_path(str.values[0], path ? "#{path} / #{str.keys[0]}" : str.keys[0])
  end
end

if ARGV[0].nil?
  warn 'No file specified'
  exit 1
end

list = []
begin
  ARGV.each do |a|
    text = File.read(a)
    disk = YAML.safe_load(text)
    sd = squeeze_disk(disk, a.gsub(/disks-(.*).ya?ml/, '\1'))
    list << sd if sd
  end
rescue => e
  warn "Oops! #{e.message}\n#{e.backtrace.join("\n")}"
  exit 2
end

final_list = []

list.each do |disk|
  disk.each do |key, dir|
    # puts dir.to_yaml
    final_list << {
      'disk' => key,
      'data' => dir.map { |d| short_path(d) }.flatten.map(&:to_h)
    }
  end
end

puts final_list.to_yaml
