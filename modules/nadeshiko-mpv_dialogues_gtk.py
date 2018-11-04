#! /usr/bin/env python3

#  nadeshiko-mpv_dialogues_gtk.py
#  Dialogues implemented in Python, aiming for a better UX.
#  deterenkelt © 2018
#
#  For licence see nadeshiko.sh


 # .py and .glade files are copied to TMPDIR
#  and prepared by nadeshiko-mpv_dialogues_gtk.sh
#
#  $1 – "startpage=STACK1_CHILD_OBJECT"
#  stack1 has these children:
#    - gtkbox_choose_socket
#    - gtkbox_crop_and_predictor
#    - gtkbox_cropping
#    - gtkbox_pick_size


 # Such lines like “###  PLACEHOLDER FOR …  ###”  are to be replaced
#  with autogenerated code. This adds code blocks for the elements,
#  the count of which may vary depending on the user’s configuration.


 # Expected exit codes
#  1 – Python code error
#  2 – GTK not available
#  3 – Startpage command line argument was not passed.
#  4 – Cancelled by user
#  127 – env couldn’t find interpreter.
#  137 – killed



try:
	import sys, gi, os
	gi.require_version('Gtk', '3.0')
	gi.require_version('Gdk', '3.0')
	from gi.repository import Gtk, Gdk
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

#  Ex.: TMPDIR = '/tmp/nadeshiko-mpv.XXXXXXXX'
###  PLACEHOLDER FOR TMPDIR CODE  ###


class Nadeshiko_mpv_dialogues:

	def __init__ (self):
		builder = Gtk.Builder()
		builder.add_from_file('nadeshiko-mpv_dialogues_gtk.glade')
		builder.connect_signals(self)
		self.window = builder.get_object('window1')
		self.window.set_resizable(False)
		self.stack = builder.get_object('stack1')
		# self.page_choose_socket = builder.get_object('gtkbox_choose_socket')
		# self.page_pick_size = builder.get_object('gtkbox_pick_size')
		self.startpage = builder.get_object(startpage)
		self.stack.set_visible_child(self.startpage)
		self.put_cancelfile_on_close = False

		if startpage == 'gtkbox_choose_socket':
			self.rb_socket1 = builder.get_object('rb_socket1')
			self.rb_socket2 = builder.get_object('rb_socket2')
			###  PLACEHOLDER FOR EXTRA SELF.RB_SOCKET* CODE  ###

		if startpage == 'gtkbox_crop_and_predictor':
			self.cb_crop = builder.get_object('cb_crop')
			self.box_cropsettings = builder.get_object('box_cropsettings')
			self.input_cropw = builder.get_object('input_cropw')
			self.input_croph = builder.get_object('input_croph')
			self.input_cropx = builder.get_object('input_cropx')
			self.input_cropy = builder.get_object('input_cropy')
			self.but_pick_cropdims = builder.get_object('but_pick_cropdims')
			#  Ex.: self.has_installer = True
			###  PLACEHOLDER FOR HAS_INSTALLER CODE  ###
			self.butbox_croptool_installer = builder.get_object('butbox_croptool_installer')
			#  Somehow this buttonbox ends up with homogeneous enabled and this
			#  adds a lot of space between cb_crop and box_cropsettings.
			self.bugged_butbox_crop = builder.get_object('bugged_butbox_crop')
			self.bugged_butbox_crop.set_homogeneous(False)
			self.switch_predictor = builder.get_object('switch_predictor')
			#  Forcing proper visibility, because autogenerating it in XML
			#  would be too complex (see bug № 12 in Developer notes in .glade).
			if self.cb_crop.get_active():
				self.box_cropsettings.set_visible(True)
				self.box_cropsettings.set_no_show_all(False)
				self.cb_crop.set_margin_bottom(0)
			else:
				self.box_cropsettings.set_visible(False)
				self.box_cropsettings.set_no_show_all(True)
				self.cb_crop.set_margin_bottom(21)

			if self.but_pick_cropdims.get_sensitive() == True:
				self.butbox_croptool_installer.set_visible(False)
				self.butbox_croptool_installer.set_no_show_all(True)
			elif self.but_pick_cropdims.get_sensitive() == False \
			     and  self.has_installer == True:
				self.butbox_croptool_installer.set_visible(True)
				self.butbox_croptool_installer.set_no_show_all(False)
			self.but_accept_crop_and_predictor = builder.get_object('but_accept_crop_and_predictor')

		if startpage == 'gtkbox_pick_size':
			self.preset_tabs = builder.get_object('preset_tabs')

			#  Ex.: self.rb_size1 = builder.get_object('rb_size1')
			###  PLACEHOLDER FOR SELF.RB_SIZE* CODE  ###

			 # Setting “active” property in XML doesn’t work,
			#  so each rb is checked at runtime.
			#
			#  Ex.:  if self.rb_size1.get_label()[-7:] == 'default':
			#        	self.rb_size1.set_active(True)
			###  PLACEHOLDER FOR RB_SIZE* ACTIVATION CODE  ###

			#  Custom filename prefix
			self.cb_set_fname_pfx = builder.get_object('cb_set_fname_pfx')
			self.input_fname_pfx = builder.get_object('input_fname_pfx')
			#  Somehow this buttonbox ends up with homogeneous enabled and this
			#  adds a lot of space between cb_crop and box_cropsettings.
			self.bugged_butbox_fname_pfx = builder.get_object('bugged_butbox_fname_pfx')
			self.bugged_butbox_fname_pfx.set_homogeneous(False)

			self.but_encode = builder.get_object('but_encode')
			self.cb_postpone = builder.get_object('cb_postpone')

		#  Must be done last!
		#  Runtime overrides change No show all property of some elements.
		self.window.show_all()

		#  Setting proper focus, window positioning.
		if startpage == 'gtkbox_choose_socket':
			#  There’s no way to show the focus frame over the first element
			#  (no, .grab_focus grabs it invisibly), but this will at least
			#  put the frame on the element on the first Tab press.
			self.window.set_focus_child(self.rb_socket1)
		elif startpage == 'gtkbox_crop_and_predictor':
			self.window.set_focus_child(self.cb_crop)
		elif startpage == 'gtkbox_cropping':
			self.put_cancelfile_on_close = True
			width, height = self.window.get_size()
			display = Gdk.Display.get_default()
			screen = display.get_default_screen()
			#  Can’t use already defined self.window, because of a type error:
			#    “Expected Gdk.Window, but got gi.overrides.Gtk.Window”
			#  This relies upon “Focus on map” window property, which is set
			#    to True by default.
			window = screen.get_active_window()
			monitor = screen.get_monitor_at_window(window)
			monitor_geom = screen.get_monitor_geometry(monitor)
			self.window.move( monitor_geom.width - width,
			                  monitor_geom.height - height )
			self.window.set_keep_above(True)
		#  Automated in .sh file
		# elif startpage == 'gtkbox_pick_size':
		# 	self.window.set_focus_child(self.rb_size1)


	def on_window_destroy(self, object, data=None):
		if self.put_cancelfile_on_close:
			f = open( os.path.join(TMPDIR, 'croptool_cancelled'), 'w' )
			f.write('Created file for Nadeshiko-mpv to stop waiting.')
			f.close()
		Gtk.main_quit()
		sys.exit(4)

	#
	 # Sockets page
	#
	def on_choose_socket_but_click(self, widget, *args):
		if self.rb_socket1.get_active():
			print ( self.rb_socket1.get_name() )
		if self.rb_socket2.get_active():
			print ( self.rb_socket2.get_name() )
		###  PLACEHOLDER FOR EXTRA RB_SOCKET* SELECTION CODE  ###
		Gtk.main_quit()
		sys.exit(0)

	#
	 # Crop and predictor page
	 #
	 # Returns 2 lines:
	 # crop=<nocrop|W:H:X:Y|pick|install_croptool>
	 # predictor=<on|off>
	#
	def on_accept_crop_and_predictor_but_click(self, *args):
		if self.cb_crop.get_active():
			print ( 'crop=' + ':'.join([  self.input_cropw.get_text(),
			                              self.input_croph.get_text(),
			                              self.input_cropx.get_text(),
			                              self.input_cropy.get_text()  ])  )
		else:
			print ( 'crop=nocrop' )

		if self.switch_predictor.get_active():
			print ( 'predictor=on' )
		else:
			print ( 'predictor=off' )

		Gtk.main_quit()
		sys.exit(0)


	def on_pick_cropdims_but_click(self, *args):
		print ( 'crop=pick' )
		if self.switch_predictor.get_active():
			print ( 'predictor=on' )
		else:
			print ( 'predictor=off' )
		Gtk.main_quit()
		sys.exit(0)


	def on_install_croptool_but_click(self, *args):
		print ( 'crop=install_croptool' )
		if self.switch_predictor.get_active():
			print ( 'predictor=on' )
		else:
			print ( 'predictor=off' )
		Gtk.main_quit()
		sys.exit(0)


	def on_crop_cb_toggle(self, *args):
		if self.box_cropsettings.get_visible() == False:
			self.cb_crop.set_margin_bottom(0)
			self.box_cropsettings.set_visible(True)
			# self.box_cropsettings.grab_focus()
		else:
			self.box_cropsettings.set_visible(False)
			self.cb_crop.set_margin_bottom(21)

	#
	 # Pick size page
	#
	def on_set_fname_pfx_cb_toggle(self, *args):
		if self.input_fname_pfx.get_visible() == False:
			self.cb_set_fname_pfx.set_margin_bottom(0)
			self.input_fname_pfx.set_visible(True)
			self.input_fname_pfx.grab_focus()
		else:
			self.input_fname_pfx.set_visible(False)
			self.cb_set_fname_pfx.set_margin_bottom(18)


	def on_encode_but_click(self, *args):
		preset_tabs = self.preset_tabs
		active_tab_label =  \
			preset_tabs.get_tab_label(
				preset_tabs.get_nth_page(
					preset_tabs.get_current_page()
				)
			)
		chosen_preset = active_tab_label.get_name()
		print ( chosen_preset )

		#  Ex.: if self.rb_size1.get_active():
		#       	print ( self.rb_size1.get_name() )
		###  PLACEHOLDER FOR EXTRA RB_SIZE* SELECTION CODE  ###

		if self.input_fname_pfx.get_text() == '':
			#  This space is to form a line to maintain order,
			#  when the stdout will be read.
			self.input_fname_pfx.set_text(' ')
		print ( self.input_fname_pfx.get_text() )
		if self.cb_postpone.get_active():
			print ('postpone')
		else:
			print ('run_now')
		Gtk.main_quit()
		sys.exit(0)


	# def on_switch_activated(self, switch, gparam):
	# 	if switch.get_active():
	# 		state = "on"
	# 	else:
	# 		state = "off"




def main():
    app = Nadeshiko_mpv_dialogues()
    Gtk.main()


if __name__ == "__main__":
    sys.exit(main())