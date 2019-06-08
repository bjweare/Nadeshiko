#  nadeshiko.90_webm.rc.sh
#
#  Predicting the muxing overhead for WebM container.
#  More details are on the wiki, in the article “Under the hood. Overhead
#  prediction” https://git.io/fjENw



 # Space to be reserved for muxing overhead, in ESP
#  Format: [frame count]=ESP
#  1 ESP is an equivalent of a space requried to hold 1 second of video
#    (and audio, if present), playback.
#  The number of frames in the clip is compared sequentially to each frame
#    count in the array, starting with the lowermost one, and if the clip
#    would have more frames, than in said item, the corresponding ESP amount
#    will be assigned as an expected muxing overhead for that clip.
#
webm_space_reserved_frames_to_esp=(
	[0]=2

	 # These values are obsolete.
	#  https://git.io/fju72
	#
	# [228]=2
	# [644]=3
	# [1417]=4
	# [1884]=5
	# [2354]=9
	# [2738]=12
)
