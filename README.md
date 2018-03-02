# Nadeshiko
A shell script to cut short videos with ffmpeg.

### Features

* Optimises bitrate and resolution for size.
* Three sizes, five resolutions with predefined bitrate settings.
* Almost everything is customiseable up to the audio codec and h264 profile level.

## How to run it

	Usage
	./nadeshiko.sh  <start_time> <stop_time> [OPTIONS] <source video>

	Required options
	         start_time – Time from the beginning of <source video>.
	          stop_time   Any formats are possible:
	                      01:23:45.670   = 1 h 23 min 45 s 670 ms
	                         23:45.1     = 23 min 45 s 100 ms
	                             5       = 5 s
	                      Padding zeroes aren’t required.
	       source video – Path to the source videofile.

	Other options
	      nosub, nosubs – make a clean video, without hardsubs.
	            noaudio – make a mute video.
	                 si – when converting kMG suffixes of the maximum
	                      file size, use powers 1000 instead of 1024.
	          <format>p – Force resolution to the specified format.
	                      Format is one of: 1080, 720, 576, 480, 360.
	              small – override the default maximum file size (20 MiB).
	               tiny   Values must be set in RC file beforehand.
	                      Default presets are: small=10M, tiny=2M.
	    vb<number>[kMG] – Force video bitrate to specified number.
	                      A suffix may be applied: vb300000, vb1200k, vb2M.
	      ab<number>[k] – Force audio bitrate the same way.
	                      Example: ab128000, ab192k, ab88k.

	The order of options is unimportant. Throw them in,
	Nadeshiko will do her best.

 

## How does it work

Nadeshiko has three main concepts:
* *maximum size* in which the new file must fit. Default size is 20 MiB;
* *resolution* to which the resulting file would be encoded;
* *bitrates* for video and audio (can be disabled) streams;

### Automatic balance between bitrate and resolution

By default Nadeshiko tries to associate the source file with an internal “profile”. For example, a 1080p profile defines three bitrates:

	video_1080p_desired_bitrate=3500k
	video_1080p_minimal_bitrate=1500k
	audio_1080p_bitrate=128k

Desired video bitrate for 1080p means the one we ideally would like to have. Minimal is the one on which we agree in the last place. Nadeshiko will go from desired to minimal, taking 100k per step, until either the calculated bitrate fits the *maximum size* or the minimal threshold is reached.

> *If desired bitrate happens to be higher than the bitrate of the original file, Nadeshiko will limit the encode to the original. No upscales.*

If a fitting bitrate wasn’t found within the profile limits of the native resolution, Nadeshiko will switch to the next lower resolution. 720p in our example. This will reset *desired* and *minimal* bitrates and enable the *scale* filter in ffmpeg. Nadeshiko will go down by 100k again and switch resolution profiles until either a good match is found or no options left.

Audio bitrate remains constant and changes, only if a profile with a lower resolution is applied. The new profile would probably have a different (usually lower, as we go down) bitrate for the audio track.

Pairs of *desired* and *minimal* bitrate bound to certain *resolutions* are the basis of automatic balance. You may want to shift the borders in `nadeshiko.rc.sh`.

### Forced settings

Nadeshiko can do as she is told, – if command line forces video bitrate, audio bitrate or scale, the result will be exactly what was asked. Forced mode sets *maximum size* to 99999M.

Forced mode allows to use the barebones of encoding, without any attached heuristic for finding an optimal resolution/bitrate combination. It’s “what you ask is what you get”.

### Dumb mode

This mode is not intended for use, it is more like a fallback for when the automatic mode couldn’t gather enough information about the original video.

 

## Known limitations

#### subtitles: only ASS/SSA and only the default subtitle stream

#### fonts extraction: MKV/WEBM contaniers only

> *To render subtitles on video (i.e. hardsub them) subtitles and fonts have to be extracted from the original file. Pulling subtitles out is easy, but with fonts the matter is much more complex. Currently Nadeshiko supports font extraction only for mkv-based containers.*

#### Forced scale works only with the five predefined standards: 1080p, 720p, 576p, 480p and 360p.

> *A key like 160p or 2270 wouldn’t be recognised, so the resolution will be the same as of the original file. The ability to set frivolous numbers as a scale profile would confuse users about the resolution–bitrate profiles in the RC file.*

#### No fragment catenation (yet)

> *You’d have to stich fragments [with ffmpeg](https://trac.ffmpeg.org/wiki/Concatenate#samecodec).*

#### No cropping (yet)

> *[How to crop with ffmpeg](https://ffmpeg.org/ffmpeg-filters.html#crop).*

#### Static audio bitrates

> *Unlike video bitrate, that changes many times during calculations, audio bitrates are constant values. Audio bitrate may change only when Nadeshiko switches to another resolution profile. Sound is often given second priority (if it isn’t cut out at all), but there are situations, when initially low audio bitrate may be raised. Say you set the default audio bitrate to 98k, but the space in the container allows for up to 200k. Why not raise the audio bitrate to 192k? This feature is viewed in the near perspective.*

#### Invalid(?) seeking in chaptered MKV

> *Some MKV fails are assembled in such a __peculiar__ way, – Hello, Coalgirls – that not even `mediainfo` can determine the bitrate of the video stream. Seeking in these files gives different numbers in ffmpeg and mpv.*

#### No integration with mpv (sadly)

> *What has driven the creation of Nadeshiko is `convert_script.lua` for mpv, that started to garble video. It was an mpv script, which once could encode, crop and catenate. Thanks be to it and RIP.*
> *There are plans to somehow couple mpv with Nadeshiko, so that the latter would be a video cutting backend, but so far Lua repels too much to touch it.*

 

## It isn’t working!

There should be a folder called `nadeshiko_logs` alongside the file. It keeps last five logs of `nadeshiko.sh` and `ffmpeg` logs for the first and the second passes. Try to solve the mystery – it probably lies within lacking ffmpeg modules and solves with your package manager. If it isn’t something that’s handled, i.e. `nadeshiko.sh` stops with exit code 2, then [file a bug](https://github.com/deterenkelt/Nadeshiko/issues/new).

 

## What to read about encoding

> *Unfortunately, there’s no newbie guide to ffmpeg, that would be short and straight to the point. For starters remember, that all `ffmpeg` options are divided on __common__, like `-y` or `-hide_banner`, __input__ options, that should go __before__ input file they relate to, and __output__ options, that are always placed after all input files and before output file.*

“[Understanding rate control modes (x264, x265, vpx)](http://slhck.info/video/2017/03/01/rate-control.html)” – nicely explains how encoders are applied.

MSU [video codecs comparison](http://www.compression.ru/video/codec_comparison/codec_comparison_en.html) – may help in a choose of a favourite video codec.

#### H264

Basics of encoding with H264 in [FFmpeg wiki](https://trac.ffmpeg.org/wiki/Encode/H.264) – **Start here.**

Tables of [profiles](https://en.wikipedia.org/wiki/H.264/MPEG-4_AVC#Profiles) and [levels](https://en.wikipedia.org/wiki/H.264/MPEG-4_AVC#Levels) on Wikipedia.

“[Optimal bitrate for a resolution](http://www.lighterra.com/papers/videoencodingh264/)”.

#### VP9

Basics of encoding with libvpx-vp9 in [FFmpeg wiki](https://trac.ffmpeg.org/wiki/Encode/VP9).

[Google’s paper](https://developers.google.com/media/vp9/bitrate-modes/) about VP9 encoding capabilities and modes.

#### AAC and friends

HQ audio in general and a nice codecs comparison in [FFmpeg wiki](https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio).

AAC on [FFmpeg wiki](https://trac.ffmpeg.org/wiki/Encode/AAC).

#### Filters, subtitles

Page about filters on [FFmpeg wiki](https://ffmpeg.org/ffmpeg-filters.html#subtitles-1).

Ibid, “[How to burn subtitles into video](https://trac.ffmpeg.org/wiki/HowToBurnSubtitlesIntoVideo)”.

“[Why subtitles aren’t honouring -ss](https://trac.ffmpeg.org/ticket/2067)”.
