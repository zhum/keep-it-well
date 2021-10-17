#!/usr/bin/env ruby

require "yaml"
require "pathname"
require 'fileutils'
require "pp"

#
# $0 outfile.yml path-to-dir [type]
#
# В каталоге есть файл anime.txt => все файлы тут отдельные произведения
# В каталоге нет такого файла => это каталог с сериалом
#
# Кроме anime.txt могут быть audio.txt, video.txt
# Тип передаётся третьим аргументом:
#    anime [default]
#    audio
#    abooks
#    music
#    [e]books
#    video
#    amv


#MAX_DEPTH=20

class DirToYaml

  def initialize(options={})
    @opt = options
    @opt[:max_depth] ||= 20
    # search ONLY in directories with [type].txt files (audio.txt, video.txt, anime.txt, ...)
    @type =  @opt[:type] || 'anime'
    @reg = []
    if @opt[:ext]
      @reg += mk_reg @opt[:ext]
    end
    if @opt[:reg]
      @reg += @opt[:reg]
    end
  end

  def dir d, name, depth=0
    check_dir nil, d, depth, name, false
  end

  def check_dir prefix, dir, depth=0, name=nil, is_checking=false
    cwd="#{pr(prefix)}#{dir}"
    if depth>@opt[:max_depth]
      warn "Max depth. #{cwd}"
      return []
    end
    list=[]
    begin
      check_files = File.exist? "#{cwd}/#{@type}.txt"
      is_checking ||= check_files
      #warn "-- #{cwd} #{@type} (files=#{check_files.inspect}, is_check=#{is_checking.inspect})"
      list=Dir.new(cwd).entries.sort.collect { |file|
        next if file[-1]=='.'
        next if File.symlink? file
        path="#{cwd}/#{file}"
        if File.directory? path
          if !is_checking || File.exist?("#{cwd}/#{file}/#{@type}.txt")
            check_dir cwd, file, depth+1, nil, is_checking
          else
            # this is series dir
            file
          end
        elsif check_files && File.file?(path)
          if @reg.find{|r| r.match file}
            file
          else
            nil
          end
        end
      }.reject{|e| e.nil? or (e.class==Array && e.empty?)}
      #warn "<< #{list}"
    rescue => e
      warn "Hmmm. Strange thing: #{e.message}"
    end
    if list.size>0
      {(name || dir) => list}
    else
      nil
    end
  end

private
  def mk_reg list
    list.map { |e| Regexp.new ".*\\.#{e}$" } 
  end

  def pr prefix
    if prefix.nil?
      ""
    else
      "#{prefix}/"
    end
  end

  def levenshtein_distance(s, t)
    m = s.length
    n = t.length
    return [m,[]] if n == 0
    return [n,[]] if m == 0
    d = Array.new(m+1) {Array.new(n+1)}
    changes=[]

    (0..m).each {|i| d[i][0] = i}
    (0..n).each {|j| d[0][j] = j}
    (1..n).each do |j|
      (1..m).each do |i|
        d[i][j] = if s[i-1] == t[j-1]  # adjust index into string
                    d[i-1][j-1]       # no operation required
                  else
                    [ d[i-1][j]+1,    # deletion
                      d[i][j-1]+1,    # insertion
                      d[i-1][j-1]+1,  # substitution
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
    loop{
      #warn "#{last}: i=#{i};j=#{j}"
      break if i==0 && j==0
      i2= i==0 ? 0 : i-1
      j2= j==0 ? 0 : j-1
      last2 = last-1
      flag2 = :no_diff
      if d[i2][j2]==last2
        i=i2
        j=j2
      elsif d[i][j2]==last2
        j=j2
      elsif d[i2][j]==last2
        i=i2
      else
        #warn "-> i=#{i};j=#{j}"
        flag2 = :diff
        last2=last
        if d[i2][j2]==last
          i=i2
          j=j2
        elsif d[i][j2]==last
          j=j2
        elsif d[i2][j]==last
          i=i2
        end
      end
      last=last2
      changes<<i if flag!=flag2
      flag=flag2
    }
    return [d[m][n], changes]
  end
end


################################################################################
#
#
#
################################################################################
EXT_V=['mkv','avi','mp4','webm','mpg','mov','wmv','vob']
EXT_A=['mp3','mp4','aac','wav','m4b','awb','mka']
EXT_T=['txt','doc','docx','fb2','fb2.zip','epub','pdf','rtf']

EXT = {
    'audio' => EXT_A,
    'abooks' => EXT_A,
    'music' => EXT_A,
    'books' => EXT_T,
    #'ebooks' => EXT_T,
    'video' => EXT_V,
    'anime' => EXT_V,
    'amv' => EXT_V,
}
################################################################################
#
#
#
################################################################################

file = ARGV[0].to_s
if file == '' || %r'^-{1,2}h(elp)?$'.match?(file)
  warn "Usage: disk2yaml yaml-file [DIR] [audio|video|anime|music|[e]books|abooks]"
  exit 1
end

yaml = begin
  YAML.load(File.open(file,'r') { |f| f.read })
rescue Errno::ENOENT
  warn "No file #{file}. Will create new for you!"
  {}
rescue Exception => e
  warn "Ooops! #{e.class} / #{e.message}"
  exit 1
end

yaml ||= {}

dir=ARGV[1] || '.'

full = (dir[0] == '/') ? dir : "#{Pathname.getwd}/#{dir}"
p = Pathname.new full
section = p.realpath.split[-1].to_s

warn "section=#{section}; full=#{full}"

ARGV[2] = 'ebooks' if ARGV[2] == 'books'
ext = EXT[ARGV[2]]
unless ext
  warn "Bad type!"
  exit 1
end
checker = DirToYaml.new(:ext => ext, :type => ARGV[2])
list = checker.dir(full,section)
if list
  pp list.keys
  yaml.merge! list
#  list.each_pair{|k,v|
#    yaml[k] = v
#  }
end
#warn PP.pp(list,"")

text = yaml.to_yaml
newfile = "#{file}.new"
written = IO.write(newfile, text)
if written == text.bytesize
  if FileUtils.mv  newfile, file
    warn "OK!"
  else
    warn "Update failed"
  end
else
  warn "Ooops! written #{written} of #{text.size}"
end
#File.open(file, "w") { |f| f.puts yaml.to_yaml}



