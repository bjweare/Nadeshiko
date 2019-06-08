#  nadeshiko.10_ffmpeg_muxers_meta.rc.sh
#
#  ffmpeg -h muxer=<muxername> recognises “mp4” as “mp4” and “webm” as “webm”,
#  but “mkv” must be queried as “matroska”. God dammit.
#
#  If you would need to add another container, you can expand this array.
#  Developers that plan to commit to the Nadeshiko repository, can extend it
#    right here.
#  Regular users may expand it in their config – just add something like
#      ffmpeg_muxers+=( [ogv]='ogv' )
#  The list of muxers, that ffmpeg recognises, can be retrieved with
#      $ ffmpeg -muxers



 # Correspondences between container extensions/short names and the names
#  by which ffmpeg tool knows them. This is used to check, that the $container,
#  specified in the user config, is supported in FFmpeg.
#  Type: associative array.
#  Item format: [common name]='ffmpeg name'
#               The “common name” is the extension: mp4, webm, mkv, ogv –
#                 this is what $container option uses.
#               The “ffmpeg name” is what you see in the second column,
#                 when you run “ffmpeg -muxers”.
#
ffmpeg_muxers=(
	[mp4]='mp4'
	[webm]='webm'
	[mkv]='matroska'
)