# Nadeshiko
A shell script to cut short videos with ffmpeg.

### Features

* Optimises bitrate and resolution for size.
* Three sizes, five resolutions with predefined bitrate settings.
* Supported codec combinations: **libx264** + **libopus**/**aac** and **libvpx-vp9** + **libopus**/**libvorbis**.
*  video codec’s profile level.

## How to run it

	Usage
	./nadeshiko.sh  <start_time> <stop_time> [OPTIONS] <source video>

	Required options
	         start_time – Time from the beginning of <source video>.
	          stop_time   Any formats are possible:
	                      01:23:45:670   = 1 h 23 min 45 s 670 ms
	                         23:45.1     = 23 min 45 s 100 ms
	                             5       = 5 s
	                      Padding zeroes aren’t required.
	       source video – Path to the source videofile.

	Other options
	      nosub, nosubs – make a clean video, without hardsubs.
	            noaudio – make a mute video.
	                 si – when converting kMG suffixes of the maximum
	                      file size, use powers 1000 instead of 1024.
	          <format>p – force encoding to the specified resolution,
	                      <format> is one of: 1080, 720, 576, 480, 360.
	       small | tiny – override the default maximum file size (20M).
	        | unlimited   Values must be set in nadeshiko.rc.sh beforehand.
	                      Default presets are: small=10M, tiny=2M.
	    vb<number>[kMG] – force video bitrate to specified <number>.
	                      A suffix may be applied: vb300000, vb1200k, vb2M.
	      ab<number>[k] – force audio bitrate the same way.
	                      Example: ab128000, ab192k, ab88k.
	       crop=W:H:X:Y – apply crop filter. Cancels scale.
	           <folder> – place encoded file in the <folder>.

	The order of options is unimportant. Throw them in,
	Nadeshiko will do her best.

 

## Examples

Cut first 1 minute 20 seconds
	./nadeshiko.sh 'file.mkv' 0 1:20

Cut with milliseconds
	./nadeshiko.sh 'file.mkv' 17:21.01 18:00.652
(.1 = 100 ms, .01 = 10 ms, .001 = 1 ms)

Fit the cut to 10 MiB instead of 20 MiB
	./nadeshiko.sh 'file.mkv' 17:21.01 18:00.652 small

Sacrifice audio and resolution to fit more minutes
	./nadeshiko.sh 'file.mkv' 20:00 25:14 ab80k 480p

The order of options is not important. More options listed above.

 

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

#### Static audio bitrates

> *Unlike video bitrate, that changes many times during calculations, audio bitrates are constant values. Audio bitrate may change only when Nadeshiko switches to another resolution profile. Sound is often given second priority (if it isn’t cut out at all), but there are situations, when initially low audio bitrate may be raised. Say you set the default audio bitrate to 98k, but the space in the container allows for up to 200k. Why not raise the audio bitrate to 192k? This feature is viewed in the near perspective.*

#### Invalid(?) seeking in chaptered MKV

> *Some MKV fails are assembled in such a __peculiar__ way, – Hello, Coalgirls – that not even `mediainfo` can determine the bitrate of the video stream. Seeking in these files gives different positions in ffmpeg and mpv.*

#### No integration with mpv (sadly)

> *What has driven the creation of Nadeshiko is `convert_script.lua` for mpv, that started to garble video. It was an mpv script, which once could encode, crop and catenate. Thanks be to it and RIP.*
> *There are plans to somehow couple mpv with Nadeshiko, so that the latter would be a video cutting backend, but so far Lua repels too much to touch it.*

 

## It isn’t working!

### Nadeshiko doesn’t encode

There should be a folder called `nadeshiko_logs` alongside the file. It keeps last five logs of `nadeshiko.sh` and `ffmpeg` logs for the first and the second passes. Try to solve the mystery – it probably lies within lacking ffmpeg modules and solves with your package manager. If it isn’t something that’s handled, i.e. `nadeshiko.sh` stops with exit code 2, then [file a bug](https://github.com/deterenkelt/Nadeshiko/issues/new).

### The video doesn’t play

Various devices: computers, smartphones, TVs and fridges have different support for H264 playback. Compatibility options for H264 are *profiles* and *levels* (see below). Nadeshiko uses *high* profile and level *4.2*, that offers playback in the most browser as of February 2018. Thus, the first thing to do is to check, that the RC file doesn’t set profile and level to anything higher.

	<- lower                  Profiles                  -> higher

	     baseline - main - high - high10 - high422 - high444
	                       ^^^^

	<- lower                   Levels                   -> higher

	… - 3.0 - 3.1 - 4.0 - 4.1 - 4.2 - 5.0 - 5.1 - 5.2 - 6.0 - 6.2
	                            ^^^

Then, if everything seems as it should, there are two options:
* one is to lower encoding *level*, **then** encoding *profile*. Certain profiles support multiple levels, for example “main” and “high” both support level 4.0.
> *Firefox 52 built on Gentoo plays high-6.2, while Waterfox 53 on Windows can only play high-4.2.*
* the other option is to check, if what’s responsible for video playback on your device is updated and supports the encoding features. That’s for the time, when you feel like you are behind times.

 

## What to read about encoding

If you’re a complete newbie, [start here](https://wiki.installgentoo.com/index.php/WebM).

“[Understanding rate control modes (x264, x265, vpx)](http://slhck.info/video/2017/03/01/rate-control.html)” – nicely explains how encoders are applied.

[MSU video codecs comparison](http://www.compression.ru/video/codec_comparison/codec_comparison_en.html) – may help in a choose of a favourite video codec.
http://www.compression.ru/video/codec_comparison/hevc_2017/

### H264

ffmpeg -h encoder=libx264

Basics of encoding with x264 in [FFmpeg wiki](https://trac.ffmpeg.org/wiki/Encode/H.264) – **Start here.**

Tables of [profiles](https://en.wikipedia.org/wiki/H.264/MPEG-4_AVC#Profiles) and [levels](https://en.wikipedia.org/wiki/H.264/MPEG-4_AVC#Levels) on Wikipedia.

“[Optimal bitrate for different resolutions](http://www.lighterra.com/papers/videoencodingh264/)”.

“[Comparison of x264 presets](http://blogs.motokado.com/yoshi/2011/06/25/comparison-of-x264-presets/)”

### VP9

ffmpeg -h encoder=libvpx-vp9

Basics of encoding with libvpx-vp9 in [FFmpeg wiki](https://trac.ffmpeg.org/wiki/Encode/VP9).

[Google’s paper](https://developers.google.com/media/vp9/bitrate-modes/) about VP9 encoding capabilities and modes.

### AAC and friends

HQ audio in general and a nice codecs comparison in [FFmpeg wiki](https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio).

AAC on [FFmpeg wiki](https://trac.ffmpeg.org/wiki/Encode/AAC).

### Filters, subtitles

Page about filters on [FFmpeg wiki](https://ffmpeg.org/ffmpeg-filters.html#subtitles-1).

Ibid, “[How to burn subtitles into video](https://trac.ffmpeg.org/wiki/HowToBurnSubtitlesIntoVideo)”.

“[Why subtitles aren’t honouring -ss](https://trac.ffmpeg.org/ticket/2067)”.


### “Past duration 0.904747 too large”

These errors coming from ffmpeg most often should be mere warnings. This happens when the source file has a fixed framerate in its header, but in the stream data framerate varies (drops). `ffmpeg` doesn’t like it, as there’s nowhere to get the “missing” frames from. It doesn’t mean, that the new file will have artifacts or jitter, VLC encoder simply ignores this. The discrepancy in stated and actual framerate is common in the sources that are streams. That is, if your source was a live stream or a TV rip, seeing “Past duration N.NNNNNNN too large” is quite normal.

This error message is discussed in FFmpeg tickets №№ [4401](https://trac.ffmpeg.org/ticket/4401), [4643](https://trac.ffmpeg.org/ticket/4643) and [4700](https://trac.ffmpeg.org/ticket/4700).

#  “medium” and more fast presets encode rough and leave visible artifacts.
#  “ultrafast” was spotted changing profile from high to baseline
#  on long files.


### VP9 has bad bitrate handling

[MSU Codec Comparison 2017 Part V: High Quality Encoders](http://compression.ru/video/codec_comparison/hevc_2017/MSU_HEVC_comparison_2017_P5_HQ_encoders.pdf) in the chapter № 6 “Bitrate handling” shows VP9 as overshooting target bitrate for over 1.5 times. But if you look at the options they use at the end of the paper, you may notice, that they intentionally allow overshooting for up to 2 times with `--overshoot-pct 100`.
<screenshot>

So if you opt to use it, expect Nadeshiko to reencode the file several times, when the resulting file size exceeds the requested *maximum file size*.


The libvpx version in these tests is 1.6.1.

### Subs get copied in mkv

Not sure if they need to be cut. HTML5 players in web browsers do not enable
subtitles by default, and if one can enable them forcefully, 95% of users
won’t find how to enable them.