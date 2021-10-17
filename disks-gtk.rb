#!/usr/bin/env ruby

require 'gtk2'
require 'yaml'

$descr = {}
$descr_path = nil

def left_is_lower l, r
  return false if l==r
  ar=r.split(':').map{|n| n.to_i}

  l.split(':').map{|n| n.to_i}.each_with_index do |n,i|
     return false if ar[i].nil?
     if n<ar[i]
        return true
     elsif n>ar[i]
        return false
     end
  end
  if r[0,l.length] == l
     true
  else
     false
  end
end

def do_search(tree, model, text)
   low_text=text.downcase
   start=tree.selection.selected
   if start.nil?
      start="0"
   else
      start=start.to_s
   end
   puts "#{start.to_s}"
   ret=start
   model.each{|m,t,i|
      if i[0].downcase.index(low_text)
         puts text
         puts t
         #tree.expand_row(t,true)
         if left_is_lower start, t.to_s
            tree.expand_to_path(t)
            tree.set_cursor(t,nil,false)
            ret=t.to_s
            break
         else
            warn "next!!!"
         end
      end
   }
   ret
end

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

def get_depth( tree, model )
   select = tree.selection
   if iter = select.selected
      @label.set_text( "Iter Depth: " << model.iter_depth( iter ).to_s )
   end
end

def get_data(tree, model)
   select = tree.selection
   data=[nil,nil]
   if iter = select.selected
      data[0] = model.get_value(iter, 0)
      data[1] = model.get_value(iter, 1)
   end

   if data != nil
      @label.set_text( "Data Value: #{data[1]}" )
   else
      @label.set_text( '' )
   end
end

def add_tree(root, model, part, path)
  list=[]
  part.each do |el|
    if el.is_a? String
      list<<el
    elsif el.is_a? Hash
      el.each_key do |kk|
        val=model.append(root)
        val.set_value(0,kk)
        # TODO: replace by description
        val.set_value(1,$descr[kk] || '')
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
    #warn "-- '#{li}' / '#{$descr[li]}' (#{$descr})"
    val.set_value(1,$descr[li] || '--')
    #val.set_value(1,"qwe")
    #val.set_value(2,"#{path}/#{li}")
  end
end

def load_yaml(tree, model)
  descr_dir = '.'
  $descr_path = './descr.yml'
  root = model.append( nil )
  root[0] = "Root" #.set_value( 0, "Root" )
  list = if ARGV[0].nil?
    Dir.glob("*.yml")
  elsif File.file? ARGV[0]
    ARGV
  else
    descr_dir = ARGV[0].capitalize
    $descr_path = "#{descr_dir}/descr.yml"
    Dir.glob("#{descr_dir}/*.yml").reject{|x| x == $descr_path}
  end

  warn "DD=#{descr_dir}"
  $descr = load_descr($descr_path)

  list.each{ |file|
    yaml = begin YAML.safe_load(File.read(file)) rescue {} end
    next if yaml.nil? || yaml.empty?
    #warn ".. #{yaml.class}"
    yaml.each{ |k,v|
      val=model.append(root)
      val.set_value(0,k)
      val.set_value(1,$descr[k] || '+')
      #val.set_value(1,"Root/#{k}")
      #warn "++ #{val}, #{model}, #{k}/#{v}"
      add_tree(val,model,yaml[k],"Root/#{k}")
    }
  }
  root
end

def load_descr(path=nil)
  path = $descr_path if path.nil?
  begin
    YAML.safe_load(File.read(path))
  rescue
    {}
  end
end

def save_descr(path=nil)
  path = $descr_path if path.nil?
  File.open(path,'w'){ |f| f.write $descr.to_yaml }
end

def build_tree( tree, model )
   load_yaml(tree, model)
   @window.show_all
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

# Create the TreeStore with three columns
model = Gtk::TreeStore.new( String, String, String)

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
edit_render = Gtk::CellRendererText.new
edit_render.set_property( "background", "black" )
edit_render.set_property( "foreground", "white" )
edit_render.editable = true
edit_render.signal_connect('edited') do |renderer, val, var|
  # use Treeview#selection#selected to modify the
  # model. var contains the new text.
  #warn "#{renderer.class}/#{val.class}/#{var.class} = #{renderer}/#{val}/#{var} "
  iter = model.get_iter(val)
  iter.set_value(1,var)
  $descr[iter[0]] = var
  save_descr
  get_data(tree, model)
end

# Create the columns
c1 = Gtk::TreeViewColumn.new( "Title", render, {:text => 0} )
c2 = Gtk::TreeViewColumn.new( "Descr", edit_render, {:text => 1} )
c1.resizable = true
c2.resizable = true
# append the columns to treeview
tree.append_column( c1 )
tree.append_column( c2 )

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

#last_search="0"

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
