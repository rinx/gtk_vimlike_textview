#-*- coding: utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__), "vimlike_textview"))

class Gtk::PostBox
  def gen_widget_post
    Gtk::VimLikeTextView.new
  end
end
