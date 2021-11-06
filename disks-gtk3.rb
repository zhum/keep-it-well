#!/usr/bin/env ruby
# frozen_string_literal: true
#
require 'fileutils'
require 'yaml'

# Require all ruby files in the application folder recursively
application_root_path = File.expand_path(__dir__)
Dir[File.join(application_root_path, 'app', '**', '*.rb')].each { |file| require file }

# Define the source & target files of the glib-compile-resources command
resource_xml = File.join(application_root_path, 'resources', 'gresources.xml')
resource_bin = File.join(application_root_path, 'gresource.bin')

# Build the binary
system("glib-compile-resources",
       "--target", resource_bin,
       "--sourcedir", File.dirname(resource_xml),
       resource_xml)

resource = Gio::Resource.load(resource_bin)
Gio::Resources.register(resource)

at_exit do
  # Before existing, please remove the binary we produced, thanks.
  FileUtils.rm_f(resource_bin)
end

def load_yaml()#tree, model)
  descr_dir = '.'
  $descr_path = './descr.yml'
  # root = model.append( nil )
  # root[0] = "Root" #.set_value( 0, "Root" )
  list = if ARGV[0].nil?
    Dir.glob("*.yml")
  elsif File.file? ARGV[0]
    ARGV
  else
    if ARGV[0].include? '/'
      descr_dir = ARGV[0]
    else
      descr_dir = ARGV[0].capitalize
    end
    $descr_path = "#{descr_dir}/descr.yml"
    Dir.glob("#{descr_dir}/*.yml").reject{|x| x == $descr_path}
  end

  # warn "DD=#{descr_dir}"
  $descr = load_descr($descr_path)

  full=[]
  list.each{ |file|
    yaml = begin YAML.safe_load(File.read(file)) rescue nil end
    next if yaml.nil? || yaml.empty?
    #warn ".. #{yaml.class}"
    # yaml.each{ |k,v|
      # val=model.append(root)
      # val.set_value(0,k)
      # d = $descr[k] || {}
      # val.set_value(1,d['rate'].to_s || '-')
      # val.set_value(2,d['genre'] || '-')
      # val.set_value(3,d['descr'] || '+')
      # #val.set_value(1,"Root/#{k}")
      # #warn "++ #{val}, #{model}, #{k}/#{v}"
      # add_tree(val,model,yaml[k],"Root/#{k}")
    # }
    full << yaml
  }
  full
end

def load_descr(path=nil)
  path = $descr_path if path.nil?
  yaml = YAML.safe_load(File.read(path))
  yaml || {}
end

# def build_tree( tree, model )
#    load_yaml(tree, model)
#    @window.show_all
# end

full = load_yaml

warn ARGV[0].downcase.gsub(/[^a-z0-9]/,'')
def_genres = case ARGV[0].downcase.gsub(/[^a-z0-9]/,'')
  when 'anime'
    %w(Сёнен Махосёдзе Сёдзе Детектив Мистика Повседневность Другое)
  when 'abooks', 'books'
    %w(Фэнтези Детектив История Фантастика Научпоп Деловые Саморазвитие)
  when 'music'
    %w(Рок Кантри Русское 60-е Классика)
  else
    []
  end

 
main = Application.new(full, $descr, $descr_path, def_genres)
# main.set_default_size(600, 400)
# main.show_all

# Gtk.main
puts main.run

