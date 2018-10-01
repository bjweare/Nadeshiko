#! /usr/bin/env python3

#  nadeshiko-mpv_dialogues_gtk.py
#  Dialogues implemented in Python, aiming for a better UX.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


 # .py and .glade files are copied to /tmp and prepared by nadeshiko-mpv.sh
#
#  $1 – "startpage=STACK1_CHILD_OBJECT"
#  stack1 has three children:
#    - gtkbox_choose_socket
#    - gtkbox_choose_config
#    - gtkbox_pick_size


 # Expected exit codes
#  1 – Python code error
#  2 – GTK not available
#  3 – Startpage command line argument was not passed.
#  4 – Cancelled by user
#  127 – env couldn’t find interpreter.
#  137 – killed


try:
	import sys, gi
	gi.require_version('Gtk', '3.0')
	from gi.repository import Gtk
except:
	print('GTK not available')
	sys.exit(2)


if len(sys.argv) == 1:
	print ('Pass startpage! ')
	print ('Example: startpage=STACK1_CHILD_OBJECT')
	sys.exit(3)

startpage = sys.argv[1]
startpage = startpage[10:]
# print (startpage);
# sys.exit (88)

# print(sys.version)

class Nadeshiko_mpv_dialogues:

	def __init__ (self):
		builder = Gtk.Builder()
		builder.add_from_file('nadeshiko-mpv_dialogues_gtk.glade')
		builder.connect_signals(self)
		self.window = builder.get_object('window1')
		self.stack = builder.get_object('stack1')
		self.startpage = builder.get_object(startpage)
		self.page_choose_socket = builder.get_object('gtkbox_choose_socket')
		self.page_choose_config = builder.get_object('gtkbox_choose_config')
		self.page_pick_size = builder.get_object('gtkbox_pick_size')
		self.stack.set_visible_child(self.startpage)
		#  For pane 1
		self.rb_socket1 = builder.get_object('rb_socket1')
		self.rb_socket2 = builder.get_object('rb_socket2')
		#  For pane 2
		self.rb_config1 = builder.get_object('rb_config1')
		self.rb_config2 = builder.get_object('rb_config2')
		#  For pane 3
		self.rb_size1 = builder.get_object('rb_size1')
		self.rb_size2 = builder.get_object('rb_size2')
		self.rb_size3 = builder.get_object('rb_size3')
		self.rb_size4 = builder.get_object('rb_size4')
		#  GtkRadioButton.active property seems to be defunct.
		if self.rb_size1.get_label()[-7:] == 'default':
			self.rb_size1.set_active(True)
		if self.rb_size2.get_label()[-7:] == 'default':
			self.rb_size2.set_active(True)
		if self.rb_size3.get_label()[-7:] == 'default':
			self.rb_size3.set_active(True)
		if self.rb_size4.get_label()[-7:] == 'default':
			self.rb_size4.set_active(True)
		self.cb_set_fname_pfx = builder.get_object('cb_set_fname_pfx')
		self.entry_fname_pfx = builder.get_object('entry_fname_pfx')
		# self.entry_fname_pfx.set_visible(False)
		self.but_encode = builder.get_object('but_encode')
		self.cb_postpone = builder.get_object('cb_postpone')

		self.window.show_all()

	def on_window1_destroy(self, object, data=None):
		Gtk.main_quit()
		sys.exit(4)

	def on_cancel_but_click(self, *args):
		Gtk.main_quit()
		sys.exit(4)

	#  Pane 1
	def on_choose_socket_but_click(self, widget, *args):
		if self.rb_socket1.get_active():
			print ( self.rb_socket1.get_name() )
		if self.rb_socket2.get_active():
			print ( self.rb_socket2.get_name() )
		Gtk.main_quit()
		sys.exit(0)

	#  Pane 2
	def on_choose_config_but_click(self, *args):
		if self.rb_config1.get_active():
			print ( self.rb_config1.get_name() )
		if self.rb_config2.get_active():
			print ( self.rb_config2.get_name() )
		Gtk.main_quit()
		sys.exit(0)

	#  Pane 3
	def on_set_fname_pfx_cb_toggle(self, *args):
		if self.entry_fname_pfx.get_visible() == False:
			self.entry_fname_pfx.set_visible(True)
			self.entry_fname_pfx.grab_focus()
		else:
			self.entry_fname_pfx.set_visible(False)

	def on_encode_but_click(self, *args):
		if self.rb_size1.get_active():
			print ( self.rb_size1.get_name() )
		if self.rb_size2.get_active():
			print ( self.rb_size2.get_name() )
		if self.rb_size3.get_active():
			print ( self.rb_size3.get_name() )
		if self.rb_size4.get_active():
			print ( self.rb_size4.get_name() )
		if self.entry_fname_pfx.get_text() == '':
			#  Placeholder to maintain order, when the stdout will be read.
			self.entry_fname_pfx.set_text(' ')
		print ( self.entry_fname_pfx.get_text() )
		if self.cb_postpone.get_active():
			print ('postpone')
		else:
			print ('run_now')
		Gtk.main_quit()
		sys.exit(0)


def main():
    app = Nadeshiko_mpv_dialogues()
    Gtk.main()


if __name__ == "__main__":
    sys.exit(main())