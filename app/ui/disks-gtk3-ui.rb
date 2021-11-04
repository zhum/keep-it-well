#!/usr/bin/env ruby
# frozen_string_literal: true
#
require 'gtk3'
require 'yaml'


class Application < Gtk::Application
  def initialize(yaml, descr, descr_path)
    super 'ru.sergzhum.keep-it-well', Gio::ApplicationFlags::FLAGS_NONE

    signal_connect :activate do |application|
      window = DisksView.new(application, yaml, descr, descr_path)
      window.present
    end
  end
end
##
## @brief      Show and edit collections with descriptions
##
class DisksView < Gtk::ApplicationWindow
  TITLE_COLUMN, RATE_COLUMN, GENRE_COLUMN, DESCR_COLUMN = 0, 1, 2, 3
  ISANUMBER = Regexp.new '[0-9]+'

  type_register

  class << self
    def init
      # Set the template from the resources binary
      set_template resource: '/ru/sergzhum/keep-it-well/ui/application_window.ui'
      bind_template_child 'search'
      bind_template_child 'search_line'
      bind_template_child 'expand'
      bind_template_child 'collapse'
      bind_template_child 'quit'
      bind_template_child 'get_data'
      bind_template_child 'scroll'
      bind_template_child 'tree_view'
      bind_template_child 'data_label'
    end
  end

  ##
  ## @brief      contructor
  ##
  ## @param      yaml        collection hash
  ## @param      descr       description hash ('item' => {rate: n, genre: 'genre', 'descr': 'description'})
  ## @param      descr_path  path to the description file
  ##
  def initialize(app, yaml, descr, descr_path)
    super application: app

    @descr_path = descr_path
    @descr = descr

    set_title 'KeepItWell!'

    search.signal_connect 'clicked' do |button, application|
      do_search(@model, search_line.text)
    end

    expand.signal_connect 'clicked' do |button, application|
      tree_view.expand_all
    end

    collapse.signal_connect 'clicked' do |button, application|
      tree_view.collapse_all
    end

    get_data.signal_connect 'clicked' do |button, application|
      do_get_data(tree_view, @model)
    end

    quit.signal_connect 'clicked' do |button, application|
      close #Gtk.main_quit
    end

    # signal_connect('destroy') do
    #   Gtk.main_quit
    # end

    # signal_connect("key_press_event") do |widget, event|
    #   if event.state.control_mask? and event.keyval == Gdk::Keyval::GDK_KEY_q
    #     destroy
    #     true
    #   else
    #     false
    #   end
    # end

    @completion = create_completion_model(descr)
    create_tree(yaml,descr)

    # if false
    #   vbox = Gtk::Box.new(:vertical)
    #   add(vbox)

    #   tree = create_tree(yaml,descr)
    #   scrolled_window = Gtk::ScrolledWindow.new
    #   scrolled_window.set_policy :automatic, :automatic
    #   scrolled_window.add(tree)
    #   vbox.pack_start(scrolled_window, :expand => true, :fill => true, :padding => 0)

    #   # buttons = Gtk::Box.new(:horizontal) 
    #   # vbox.pack_start(buttons, expand: true, fill: true, padding: 2 )
    #   frame = Gtk::Frame.new( "Actions" )
    #   vbox.pack_start(frame, expand: false, fill: true, padding: 0)
    #   vbox2 = Gtk::Box.new( :vertical )
    #   frame.add( vbox2 )
    #   # vbox2.pack_start( frame, false, false, 0 )

    #   hbox = Gtk::Box.new( :horizontal )
    #   text = Gtk::Entry.new
    #   text.signal_connect("activate"){ do_search(tree, @model, text.text)}
    #   hbox.pack_start( text,  :expand => true, :fill => true, :padding => 0 )
    #   search_button = Gtk::Button.new(label: "Search")
    #   search_button.signal_connect("clicked"){ do_search(tree, @model, text.text) }
    #   hbox.pack_start( search_button,  :expand => true, :fill => true, :padding => 0 )
    #   vbox2.pack_start( hbox,  :expand => true, :fill => true, :padding => 0 )

    #   ## 1st row
    #   hbox = Gtk::Box.new(:horizontal)
    #   button = Gtk::Button.new(label:  "Expand all" )
    #   button.signal_connect( "clicked" ) { tree.expand_all }
    #   hbox.pack_start( button,  :expand => true, :fill => true, :padding => 0 )

    #   button = Gtk::Button.new(label:  "Collapse all" )
    #   button.signal_connect( "clicked" ) { tree.collapse_all }
    #   hbox.pack_start( button,  :expand => true, :fill => true, :padding => 0 )
    #   vbox2.pack_start( hbox,  :expand => true, :fill => true, :padding => 0 )

    #   ## 4th row
    #   hbox = Gtk::Box.new( :horizontal )
    #   button = Gtk::Button.new(label:  "Get Data" )
    #   button.signal_connect( "clicked" ) {get_data(tree, @model)}
    #   hbox.pack_start( button,  :expand => true, :fill => true, :padding => 0 )

    #   button = Gtk::Button.new(label:  "Quit" )
    #   button.signal_connect( "clicked" ) {Gtk.main_quit}
    #   hbox.pack_start( button,  :expand => true, :fill => true, :padding => 0 )
    #   vbox2.pack_start( hbox,  :expand => true, :fill => true, :padding => 0 )

    #   hbox = Gtk::Box.new( :horizontal )
    #   @label = Gtk::Label.new("")
    #   hbox.pack_start( @label,  :expand => true, :fill => true, :padding => 0 )
    #   vbox2.pack_start( hbox,  :expand => true, :fill => true, :padding => 0 )
    # end
  end

  ##
  ## @brief      Add new word to genres autocompletion list
  ##
  ## @param      word  new word to add
  ##
  def completion_check_update(word)
    return if @completion_words.include?(word) || word.empty?
    @completion_words << word
    @completion_words.sort
    completion_update_model(@completion_words)  
  end

  ##
  ## @brief      Replace genres autocompletion list
  ##
  ## @param      words  New list of words
  ##
  def completion_update_model(words)
    store = Gtk::ListStore.new(String)
    @completion_words = words
    words.each do |word|
      iter = store.append
      iter[0] = word.to_s
    end
    @completion.model = store
  end

  ##
  ## @brief      Creates a completion model.
  ##
  ## @param      descr  The descriptions hash
  ##
  def create_completion_model(descr)
    store = Gtk::ListStore.new(String)

    # arr = extract_genres(descr)
    arr = descr.values.map { |e| e['genre'] }
    .concat %w(Фэнтези Детектив История Фантастика Научпоп Деловые Саморазвитие)
    .flatten
    arr.reject! { |e| e.nil? }
    arr.reject! { |e| e.empty? }
    # warn arr.inspect
    arr = arr.uniq.sort
    arr.each do |word|
      iter = store.append
      iter[0] = word
    end

    @completion_words = arr
    completion = Gtk::EntryCompletion.new
    # Create a tree model and use it as the completion model
    completion.model = store
    completion.text_column = 0
    completion.minimum_key_length = 0
    completion.inline_completion = true
    completion
  end

  ##
  ## @brief      Fills the model with data recursively
  ##
  ## @param      model   The model
  ## @param      descr   The descriptions hash
  ## @param      source  The element to add
  ## @param      parent  The parent to add to
  ##
  def append_children(model, descr, source, parent = nil)
    case source
    when Array
      source.each do |el|
        append_children(model, descr, el, parent)
      end
    when Hash
      source.each_pair do |k,v|
        iter = model.append(parent)
        iter.set_value(0,k)
        d = descr[k] || {'rate' => '', 'genre' => '', 'descr' => ''}
        iter.set_value(0,k)
        iter.set_value(1,d['rate'].to_s=='0' ? '' : d['rate'].to_s)
        iter.set_value(2,d['genre'].to_s)
        iter.set_value(3,d['descr'].to_s)
        append_children(model, descr, v, iter)
      end
    when String
      iter = model.append(parent)
      d = descr[source] || {'rate' => '', 'genre' => '', 'descr' => ''}
      iter.set_value(0,source)
      iter.set_value(1,d['rate'].to_s=='0' ? '' : d['rate'].to_s)
      iter.set_value(2,d['genre'].to_s)
      iter.set_value(3,d['descr'].to_s)
    else
      warn "Ooops! Unexpected #{source.inspect}"
      exit 1
    end
  end

  ##
  ## @brief      Appends a new column.
  ##
  ## @param      model      The model
  ## @param      tree_view  The tree_view object
  ## @param      title      The column title
  ## @param      min_width  The minimum column width [100]
  ## @param      block      The code block to execute on editing finish
  ##
  def append_column(model, tree_view, title, min_width = 100, &block)
    renderer = Gtk::CellRendererText.new
    renderer.editable = true
    renderer.signal_connect('edited') do |*args|
      block.call(*args.push(model))
    end
    if title=='Genre'
      renderer.signal_connect('editing-started') do |*args|
        (renderer_auto, editable, path) = args
        # warn "Start! #{renderer_auto.inspect}\n#{editable.inspect}"
        editable.set_completion(@completion)
      end
    end
    index = tree_view.insert_column(-1, title, renderer,
                           {
                             :text => tree_view.columns.size
                           })
    eval "def renderer.column; #{index-1}; end"
    col = tree_view.get_column(index-1)
    col.sizing = :autosize # Sets the column on a fixed width
    col.resizable = true
    col.min_width = min_width
    col.expand = true
  end


  ##
  ## @brief      Creates a tree.
  ##
  ## @param      yml    The collection hash
  ## @param      descr  The descriptions hash
  ##
  def create_tree(yml, descr)
    @model = Gtk::TreeStore.new(String, String, String, String)
    # tree_view = Gtk::TreeView.new
    # tree_view.rules_hint = true
    # tree_view.selection.mode = Gtk::SelectionMode::SINGLE

    tree_view.set_model(@model)
    selection = tree_view.selection

    selection.set_mode(:browse)
    tree_view.set_size_request(200, -1)

    append_children(@model, descr, yml) #generate_index)

    append_column(@model, tree_view, "Name", 200) do |cell, path_string, new_text, model|
      false
    end      

    append_column(@model, tree_view, "Rate", 30) { |cell, path_string, new_text, model|
      path = Gtk::TreePath.new(path_string)
      iter = model.get_iter(path)
      if cell.text != new_text && (new_text == '' || ISANUMBER.match(new_text))
        iter.set_value(RATE_COLUMN, new_text)
        d = @descr[iter.get_value(0)] ||= {'rate' => '', 'genre' => '', 'descr' => ''}
        d['rate'] = new_text.to_i
        save_descr
      end
    }

    append_column(@model, tree_view, "Genre") do |cell, path_string, new_text, model|
      path = Gtk::TreePath.new(path_string)

      if cell.text != new_text
        iter = model.get_iter(path)
        iter.set_value(GENRE_COLUMN, new_text)
        d = @descr[iter.get_value(0)] ||= {'rate' => '', 'genre' => '', 'descr' => ''}
        d['genre'] = new_text
        save_descr
        completion_check_update(new_text)
      end
    end

    append_column(@model, tree_view, "Description", 200) do |cell, path_string, new_text, model|
      path = Gtk::TreePath.new(path_string)
      if cell.text != new_text
        iter = model.get_iter(path)
        iter.set_value(DESCR_COLUMN, new_text)
        d = @descr[iter.get_value(0)] ||= {'rate' => '', 'genre' => '', 'descr' => ''}
        d['descr'] = new_text
        save_descr
      end
    end      

    style_provider = Gtk::CssProvider.new()
    css = <<_CSS
GtkTreeView row:nth-child(even) {
    background-color: #FF00FF;
}
GtkTreeView row:nth-child(odd) {
    background-color: #00FFFF;
}
_CSS
    style_provider.load_from_data(css)
    # Gdk::Screen.default().add_style_provider(style_provider,Gtk::StyleProvider::PRIORITY_APPLICATION)
    Gtk::StyleContext.add_provider_for_screen(Gdk::Screen.default(), style_provider,Gtk::StyleProvider::PRIORITY_APPLICATION)
    tree_view.expand_all
    return tree_view
  end

  ##
  ## @brief      Check if left path is lower than right path
  ##
  ## @param      l left path
  ## @param      r right path
  ## @return     true if left path is lower
  ##
  def left_is_lower(l, r)
    return false if l==r
    # warn "--- #{l.split(':').join(':')} / #{r.split(':').join(':')}"
    ar = r.split(':').map{|n| n.to_i}

    l.split(':').map{|n| n.to_i}.each_with_index do |n,i|
      return false if ar[i].nil?
      if n < ar[i]
        # warn "#{n} < #{ar[i]}"
        return true
      elsif n > ar[i]
        # warn ">"
        return false
      end
    end
    r[0, l.length] == l
  end

  def get_depth( tree, model )
     select = tree.selection
     if iter = select.selected
        data_label.set_text( "Iter Depth: #{model.iter_depth( iter ).to_s}" )
     end
  end

  def do_get_data(tree, model)
     select = tree.selection
     data=nil
     iter = select.selected
     if iter
        data = model.get_value(iter, 0)
        #data[1] = model.get_value(iter, 1)
     end

     if ! data.nil?
        path = [data]
        iter = iter.parent
        while iter
          path << model.get_value(iter,0)
          iter = iter.parent
        end
        data_label.set_text( "Data Value: #{path.reverse.join('/')}" )
     else
        data_label.set_text( '' )
     end
  end

  def do_search(model, text, first_time = true)
    low_text = text.downcase
    start = nil
    if first_time
      start = tree_view.selection.selected
      start = start.nil? ? "0" : start.path.to_s
    else
      start = "0"
    end

    # puts "start: #{start.to_s}"
    ret = start
    model.each do |m,t,i|
      if i[0].downcase.index(low_text)
        # puts "text: #{text}"
        # puts "t: #{t}"
        # puts "i: #{i[0].inspect}"
        #tree.expand_row(t,true)
        if left_is_lower start, t.to_s
          tree_view.expand_to_path(t)
          tree_view.set_cursor(t,nil,false)
          ret = t.to_s
          break
        # else
        #   warn "next!!!"
        end
      end
    end
    if ret == start && first_time
      do_search(model, text, false)
    else
      ret
    end
  end

  def save_descr(path=nil)
    path = @descr_path if path.nil?
    # warn "SAVE: #{path}, #{@descr.to_yaml}"
    File.rename(path,"#{path}.bak")
    File.open(path,'w'){ |f| f.write @descr.to_yaml }
  end

end

# def load_yaml()#tree, model)
#   descr_dir = '.'
#   $descr_path = './descr.yml'
#   # root = model.append( nil )
#   # root[0] = "Root" #.set_value( 0, "Root" )
#   list = if ARGV[0].nil?
#     Dir.glob("*.yml")
#   elsif File.file? ARGV[0]
#     ARGV
#   else
#     if ARGV[0].include? '/'
#       descr_dir = ARGV[0]
#     else
#       descr_dir = ARGV[0].capitalize
#     end
#     $descr_path = "#{descr_dir}/descr.yml"
#     Dir.glob("#{descr_dir}/*.yml").reject{|x| x == $descr_path}
#   end

#   warn "DD=#{descr_dir}"
#   $descr = load_descr($descr_path)

#   full=[]
#   list.each{ |file|
#     yaml = begin YAML.safe_load(File.read(file)) rescue nil end
#     next if yaml.nil? || yaml.empty?
#     #warn ".. #{yaml.class}"
#     # yaml.each{ |k,v|
#       # val=model.append(root)
#       # val.set_value(0,k)
#       # d = $descr[k] || {}
#       # val.set_value(1,d['rate'].to_s || '-')
#       # val.set_value(2,d['genre'] || '-')
#       # val.set_value(3,d['descr'] || '+')
#       # #val.set_value(1,"Root/#{k}")
#       # #warn "++ #{val}, #{model}, #{k}/#{v}"
#       # add_tree(val,model,yaml[k],"Root/#{k}")
#     # }
#     full << yaml
#   }
#   full
# end

# def load_descr(path=nil)
#   path = $descr_path if path.nil?
#   yaml = YAML.safe_load(File.read(path))
#   yaml || {}
# end

# full = load_yaml

# main = DiskView.new(full, $descr, $descr_path)
# main.set_default_size(600, 400)
# main.show_all

# Gtk.main

__END__


def add_tree(root, model, part, path)
  list=[]
  part.each do |el|
    if el.is_a? String
      list<<el
    elsif el.is_a? Hash
      el.each_key do |kk|
        val=model.append(root)
        val.set_value(0,kk)
        d = $descr[kk] || {}
        val.set_value(1,d['rate'].to_s || '-')
        val.set_value(2,d['genre'] || '-')
        val.set_value(3,d['descr'] || '')
        #val.set_value(2,"#{path}/#{kk}")
        add_tree(val, model, el[kk],"#{path}/#{kk}")
      end
    else
      warn "OOOOOOPS!!!! el=#{el} (#{el.class})"
    end
  end
  # add string elements
  list.each do |li|
    val=model.append(root)
    val.set_value(0,li)
    d = $descr[li] || {}
    val.set_value(1,d['rate'].to_s || '-')
    val.set_value(2,d['genre'] || '-')
    val.set_value(3,d['descr'] || '--')
    #val.set_value(1,"qwe")
    #val.set_value(2,"#{path}/#{li}")
  end
end

##################################################################
##################################################################
##################################################################

Gtk.init
@window = Gtk::Window.new( Gtk::Window::TOPLEVEL )
@window.set_size_request( 1500, 500 )
@window.signal_connect( "delete_event" ) { Gtk.main_quit }
@window.set_border_width( 5 )
@window.set_title( "Video searcher" );

vbox2 = Gtk::VBox.new( false, 0 )
scroller = Gtk::ScrolledWindow.new
scroller.set_policy( Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC )
@window.add( vbox2 )
vbox2.pack_start( scroller, true, true, 0 )

# Create the TreeStore with columns
model = Gtk::TreeStore.new(String, String, String, String, String)

# Create the TreeView adding the TreeStore
tree = Gtk::TreeView.new( model )

tree.signal_connect('key-press-event'){ |_,e|
  #warn "#{Gdk::Keyval.to_name(e.keyval)} #{tree.selection.selected}"
  if Gdk::Keyval.to_name(e.keyval) == 'Return'
    tree.expand_row(tree.selection.selected.path,true)
  end
  if Gdk::Keyval.to_name(e.keyval) == 'space'
    tree.expand_row(tree.selection.selected.path,false)
  end
  #false = just this row
}

## Create the renderer and set properties
render = Gtk::CellRendererText.new
render.set_property( "background", "black" )
render.set_property( "foreground", "white" )

# Create the editable renderer and set properties
edit_render1 = Gtk::CellRendererText.new
edit_render1.set_property( "background", "black" )
edit_render1.set_property( "foreground", "white" )
edit_render1.editable = true
edit_render1.signal_connect('edited') do |renderer, val, var|
  # use Treeview#selection#selected to modify the
  # model. var contains the new text.
  #warn "#{renderer.class}/#{val.class}/#{var.class} = #{renderer}/#{val}/#{var}"
  iter = model.get_iter(val)
  warn "1 #{iter[0]}: #{iter[1]},#{iter[2]},#{iter[3]}"
  iter[1] = var
  #$descr[iter[0]] = var
  #save_descr
  get_data(tree, model)
end

# Create the editable renderer and set properties
edit_render2 = Gtk::CellRendererText.new
edit_render2.set_property( "background", "black" )
edit_render2.set_property( "foreground", "white" )
edit_render2.editable = true
edit_render2.signal_connect('edited') do |renderer, val, var|
  # use Treeview#selection#selected to modify the
  # model. var contains the new text.
  #warn "#{renderer.class}/#{val.class}/#{var.class} = #{renderer}/#{val}/#{var}"
  iter = model.get_iter(val)
  warn "2 #{iter[0]}: #{iter[1]},#{iter[2]},#{iter[3]}"
  iter[2] = var
  #$descr[iter[0]] = var
  #save_descr
  get_data(tree, model)
end

# Create the editable renderer and set properties
edit_render3 = Gtk::CellRendererText.new
edit_render3.set_property( "background", "black" )
edit_render3.set_property( "foreground", "white" )
edit_render3.editable = true
edit_render3.signal_connect('edited') do |renderer, val, var|
  # use Treeview#selection#selected to modify the
  # model. var contains the new text.
  #warn "#{renderer.class}/#{val.class}/#{var.class} = #{renderer}/#{val}/#{var}"
  iter = model.get_iter(val)
  warn "3 #{iter[0]}: #{iter[1]},#{iter[2]},#{iter[3]}"
  iter[3] = var
  warn "3 #{iter[0]}: #{iter[1]},#{iter[2]},#{iter[3]}"
  #$descr[iter[0]] = var
  #save_descr
  get_data(tree, model)
end

# Create the columns
c1 = Gtk::TreeViewColumn.new( "Title", render, {:text => 0} )
c1.resizable = true
c1.max_width = 300
c2 = Gtk::TreeViewColumn.new( "Rate", edit_render1, {:text => 1} )
c2.resizable = true
c3 = Gtk::TreeViewColumn.new( "Genre", edit_render2, {:text => 1} )
c3.resizable = true
c4 = Gtk::TreeViewColumn.new( "Descr", edit_render3, {:text => 1} )
c4.resizable = true
# append the columns to treeview
tree.append_column( c1 )
tree.append_column( c2 )
tree.append_column( c3 )
tree.append_column( c4 )

# add the treeview to the scroller
scroller.add( tree )

#$descr = load_descr('./descr.yml')
#warn "#{$descr}"
build_tree( tree, model )

## Button Frame
frame = Gtk::Frame.new( "Actions" )
vbox = Gtk::VBox.new( false, 0 )
frame.add( vbox )
vbox2.pack_start( frame, false, false, 0 )

   hbox = Gtk::HBox.new( true, 0 )
   text = Gtk::Entry.new
   text.signal_connect("activate"){ do_search(tree,model,text.text)}
   hbox.pack_start( text, true, true, 0 )
   search_button = Gtk::Button.new("Search")
   search_button.signal_connect("clicked"){ do_search(tree, model, text.text) }
   hbox.pack_start( search_button, true, true, 0 )
   vbox.pack_start( hbox, false, false, 0 )

   ## 1st row
   hbox = Gtk::HBox.new( true, 0 )
   button = Gtk::Button.new( "Expand all" )
   button.signal_connect( "clicked" ) { tree.expand_all }
   hbox.pack_start( button, true, true, 0 )

   button = Gtk::Button.new( "Collapse all" )
   button.signal_connect( "clicked" ) { tree.collapse_all }
   hbox.pack_start( button, true, true, 0 )
   vbox.pack_start( hbox, false, false, 0 )

   ## 4th row
   hbox = Gtk::HBox.new( true, 0 )
   button = Gtk::Button.new( "Get Data" )
   button.signal_connect( "clicked" ) {get_data(tree, model)}
   hbox.pack_start( button, true, true, 0 )

   button = Gtk::Button.new( "Get Iter Depth" )
   button.signal_connect( "clicked" ) {get_depth(tree, model)}
   hbox.pack_start( button, true, true, 0 )
   vbox.pack_start( hbox, false, false, 0 )

   hbox = Gtk::HBox.new( true, 0 )
   @label = Gtk::Label.new("")
   hbox.pack_start( @label, true, true, 0 )
   vbox.pack_start( hbox, false, false, 0 )


# tree.signal_connect("select-cursor-row"){warn "sel"; get_data(tree,model)}
tree.signal_connect("cursor-changed"){|t| get_data(t,model)}

@window.show_all
Gtk.main


# def add_node(tree, model )
#    select = tree.selection
#    if iter = select.selected
#       iter2 = model.append( iter )
#       iter2.set_value(0, "This is inserted data.")
#    end
# end

# def del_node(tree, model )
#    select = tree.selection
#    if iter = select.selected
#       model.remove( iter )
#    end
# end



   ## 2nd row
   # hbox = Gtk::HBox.new( true, 0 )
   # button = Gtk::Button.new( "Insert a Leaf" )
   # button.signal_connect( "clicked" ) {add_node(tree, model)}
   # button.signal_connect( "clicked" ) {}
   # hbox.pack_start( button, true, true, 0 )

   # button = Gtk::Button.new( "Remove Node/Leaf" )
   # button.signal_connect( "clicked" ) {del_node(tree, model)}
   # hbox.pack_start( button, true, true, 0 )
   # vbox.pack_start( hbox, false, false, 0 )

   # ## 3rd row
   # hbox = Gtk::HBox.new( true, 0 )
   # button = Gtk::Button.new( "Remove All" )
   # button.signal_connect( "clicked" ) { model.clear }
   # hbox.pack_start( button, true, true, 0 )

   # button = Gtk::Button.new( "Add New Tree" )
   # button.signal_connect( "clicked" ) { build_tree(tree, model)}
   # hbox.pack_start( button, true, true, 0 )
   # vbox.pack_start( hbox, false, false, 0 )





  # def append_children(model, source, parent = nil)
  #   source.each do |title, rate, genre, descr, children|
  #     iter = model.append(parent)

  #     [title, rate, genre, descr].each_with_index do |value, i|
  #       if value
  #         iter.set_value(i, value)
  #       end
  #     end
  #     # iter.set_value(ITALIC_COLUMN, false)

  #     if children
  #       append_children(model, children, iter)
  #     end
  #   end
  # end

  # def generate_index
  #   index =
  #     [
  #       {
  #         'disk a' => [
  #           DiskItem.new('book0','1','2','good'),
  #           DiskItem.new('book1','2','3','good too'),
  #           'qweqwe' => [
  #             DiskItem.new('book2','1','2','awesome'),
  #           ]
  #         ]
  #       },
  #       {
  #         'disk b' => [
  #           DiskItem.new('book3','12','23','bad'),
  #           DiskItem.new('book3','1111','222','not bad')
  #         ]
  #       }
  #     ]
  # end

