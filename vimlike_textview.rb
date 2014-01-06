#!/usr/bin/env ruby
#-*- coding: utf-8 -*-

require 'gtk2'
require 'gtksourceview2'

module Gtk
  class VimLikeTextView < Gtk::SourceView

    attr_accessor :current_mode, :default_bgcolor, :insert_bgcolor, :visual_bgcolor, :select

    @@hook_keys_normal = ['a', 'A', 'i', 'I', 'o', 'O', 'v', 'd', 'h', 'j', 'k', 'l', '0', 'dollar', 'u', 'p', 'P', 'x', 'X', 'BackSpace']
    @@editable_command_normal = ['o', 'O', 'd', 'u', 'p', 'P', 'x', 'X']

    @@hook_keys_insert = ['Escape']

    @@hook_keys_visual = ['Escape', 'h', 'j', 'k', 'l', 'y', 'x']
    @@editable_command_visual = ['y', 'x']

    @@hist_limit = 8000
    @@post_history = []
    @@post_history_ptr = 0


    module Mode
      NORMAL = 0
      INSERT = 1
      VISUAL = 2
    end

    def change_mode(mode)
      case mode
      when Mode::NORMAL
        self.current_mode = mode
        modify_base(Gtk::STATE_NORMAL, default_bgcolor)
        self.select_all(false)
        self.select = false
        self.editable = false
      when Mode::INSERT
        self.current_mode = mode
        modify_base(Gtk::STATE_NORMAL, insert_bgcolor)
        self.select_all(false)
        self.select = false
        self.editable = true
      when Mode::VISUAL
        self.current_mode = mode
        modify_base(Gtk::STATE_NORMAL, visual_bgcolor)
        self.select_all(false)
        self.select = true
        self.editable = false
      else
        raise "invalid mode: #{mode}"
      end
    end

    def initialize
      super
      self.show_line_numbers = true

      @select = false
      @last_key = 'Escape'
      change_mode(Mode::NORMAL)

      @default_bgcolor = Gdk::Color.new(0xffff, 0xffff, 0xffff)
      @insert_bgcolor  = Gdk::Color.new(0xffff, 0xffff, 0xaaaa)
      @visual_bgcolor  = Gdk::Color.new(0xffff, 0xaaaa, 0xffff)

      @history_stack = []
      @history_stack.push([self.buffer.text, self.buffer.cursor_position])
      @stack_ptr = 0
      @isundo = false

      add_signal(self.buffer)

      signal_connect('key_press_event') { |w, e|
        key = Gdk::Keyval.to_name(e.keyval)
        @isundo = (current_mode == Mode::NORMAL) and (key == 'u')

        # map "^[" to "Escape"
        if key == 'bracketleft' and
            ( e.state & Gdk::Window::CONTROL_MASK == 
              Gdk::Window::ModifierType::CONTROL_MASK )
          key = 'Escape'
        end
        
        case current_mode
        when Mode::NORMAL
          self.editable = true if @@editable_command_normal.include?(key)
          case key
          when 'a' # INSERTモードに変更してカーソルを1つ右へ移動
            change_mode(Mode::INSERT)
            self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, 1, @select)
          when 'A' # INSERTモードに変更してカーソルを行末へ移動
            change_mode(Mode::INSERT)
            self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, 1, @select)
          when 'i' # INSERTモードに変更する
            change_mode(Mode::INSERT)
          when 'I' # INSERTモードに変更してカーソル行頭へ移動
            change_mode(Mode::INSERT)
            self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, -1, @select)
          when 'o' # INSERTモードに変更して1つ下に行を追加
            change_mode(Mode::INSERT)
            self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, 1, @select)
            self.insert_at_cursor("\n")
          when 'O' # INSERTモードに変更して1つ上に行を追加
            change_mode(Mode::INSERT)
            self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, -1, @select)
            self.insert_at_cursor("\n")
            self.move_cursor(Gtk::MOVEMENT_DISPLAY_LINES, -1, @select)
          when 'v' # VISUALモードに変更する
            change_mode(Mode::VISUAL)
          when 'd' # 直前のkeyが'd'なら1行削除
            if @last_key == 'd'
              self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, -1, false)
              self.move_cursor(Gtk::MOVEMENT_DISPLAY_LINES, 1, true)
              self.cut_clipboard
              @last_key = nil
            end
          when 'h' # カーソルを1つ左へ移動
            self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, -1, @select)
          when 'j' # カーソルを1つ下へ移動
            self.move_cursor(Gtk::MOVEMENT_DISPLAY_LINES, 1, @select)
          when 'k' # カーソルを1つ上へ移動
            self.move_cursor(Gtk::MOVEMENT_DISPLAY_LINES, -1, @select)
          when 'l' # カーソルを1つ右へ移動
            self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, 1, @select)
          when '0' # カーソルを行頭に移動
            self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, -1, @select)
          when 'dollar' # カーソルを行末に移動
            self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, 1, @select)
          when 'u' # 1つ戻る
            self.undo
          when 'p' # カーソルを1つ右に移動して貼り付け
            self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, 1, @select)
            self.paste_clipboard
          when 'P' # この位置に貼り付け
            self.paste_clipboard
          when 'x' # カーソルの右の文字を削除
            self.delete_from_cursor(Gtk::DELETE_CHARS, 1)
          when 'X' # カーソルの左の文字を削除
            self.delete_from_cursor(Gtk::DELETE_CHARS, -1)
          when 'BackSpace' # カーソルを1つ左へ移動
            self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, -1, @select)
          end
          self.editable = false if current_mode == Mode::NORMAL
          @last_key = key unless @last_key == nil
          true

        when Mode::INSERT
          case key
          when 'Escape'
            change_mode(Mode::NORMAL)
          end
          @last_key = key
          @@hook_keys_insert.include? key

        when Mode::VISUAL
          self.editable = true if @@editable_command_visual.include?(key)
          case key
          when 'Escape'
            change_mode(Mode::NORMAL)
          when 'h'
            self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, -1, @select)
          when 'j'
            self.move_cursor(Gtk::MOVEMENT_DISPLAY_LINES, 1, @select)
          when 'k'
            self.move_cursor(Gtk::MOVEMENT_DISPLAY_LINES, -1, @select)
          when 'l'
            self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, 1, @select)
          when 'y'
            self.copy_clipboard
            self.select = false
            self.select_all(false)
            change_mode(Mode::NORMAL)
          when 'x'
            self.delete_from_cursor(Gtk::DELETE_CHARS, 1)
          end
          self.editable = false if current_mode == Mode::VISUAL
          @last_key = key
          true

        end

      }

    end


    def self.pushGlobalStack(text)
      @@post_history_ptr = @@post_history.length
      @@post_history.push(text) end


    def add_signal(buffer)
      buffer.signal_connect('changed') {
        if not @isundo then
          @history_stack += @history_stack[@stack_ptr..-2].reverse
          self.push_buffer
          @stack_ptr = @history_stack.length - 1
        end
      }
      buffer
    end

    # 現在のバッファと最新の履歴が異なっていればスタックに現在の状態を追加
    def push_buffer
      if @history_stack == nil then
        @history_stack = [['', 0]]
      end
      if self.buffer.text != '' then
        if @history_stack[-1][0] != self.buffer.text then
          @history_stack.push([self.buffer.text, self.buffer.cursor_position])
        end
        if @history_stack.length > @@hist_limit then
          @history_stack = @history_stack[(@history_stack.length - @@hist_limit)..-1]
        end
      end
    end

    # undoの実装．バッファの内容を変更すると自動的に履歴スタックに追加されるので，
    # 履歴スタックに追加したら最新の履歴を捨てる
    def undo
      top = @history_stack[@stack_ptr]
      if top != nil then
        if top[0] == self.buffer.text then
          # 最新履歴が現在の状態と同じなら，2番目の履歴を参照
          decStackPtr
          second = @history_stack[@stack_ptr]
          if second != nil then
            self.buffer.set_text(second[0])
            self.buffer.place_cursor(self.buffer.get_iter_at_offset(second[1]))
          else # 上から2番目が空
            self.buffer.set_text('')
          end
        else
          self.buffer.set_text(top[0])
          self.buffer.place_cursor(self.buffer.get_iter_at_offset(top[1]))
        end
      else # 履歴スタックが空
        self.buffer.set_text('')
      end
    end

    def incStackPtr
      if @history_stack.length > @stack_ptr + 1 then
        @stack_ptr += 1
      end
    end

    def decStackPtr
      if @stack_ptr > 0 then
        @stack_ptr -= 1
      end
    end

    def undoGlobalStack
      if @@post_history != []
        if not defined? @is_global_undo
          @is_global_undo = true
        end
        if @is_global_undo == false
          @@post_history_ptr = (@@post_history_ptr - 1) % @@post_history.length
          @@post_history_ptr = (@@post_history_ptr - 1) % @@post_history.length
        end
        self.buffer.set_text(@@post_history[@@post_history_ptr])
        @@post_history_ptr = (@@post_history_ptr - 1) % @@post_history.length
        @is_global_undo = true
      end
    end

    def redoGlobalStack
      if @@post_history != []
        if not defined? @is_global_undo
          @is_global_undo = false
        end
        if @is_global_undo == true
          @@post_history_ptr = (@@post_history_ptr + 1) % @@post_history.length
          @@post_history_ptr = (@@post_history_ptr + 1) % @@post_history.length
        end
        self.buffer.set_text(@@post_history[@@post_history_ptr])
        @@post_history_ptr = (@@post_history_ptr + 1) % @@post_history.length
        @is_global_undo = false
      end
    end

  end
end

if $0 == __FILE__
  vtv = Gtk::VimLikeTextView.new
  w = Gtk::Window.new
  w.add(vtv)
  w.set_size_request(300,200)
  w.signal_connect('key_press_event') { |w, e|
    if Gdk::Keyval.to_name(e.keyval) == 'q' then
      Gtk.main_quit
    end
  }
  w.signal_connect('destroy') {
    Gtk.main_quit
  }
  w.show_all

  Gtk.main
end
