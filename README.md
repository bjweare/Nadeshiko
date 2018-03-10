# Nadeshiko
A Linux tool to cut short videos with ffmpeg.

![](https://raw.githubusercontent.com/wiki/deterenkelt/Nadeshiko/img/short2.jpg)

### Features

* Optimises bitrate and resolution for size.
* Three sizes, five resolutions with predefined bitrate settings.
* Supports H264 and VP9:
  * **libx264** + **libfdk_aac**/**aac** in mp4;
  * or **libvpx-vp9** + **libopus**/**libvorbis** in webm.
* Almost everything is customiseable!

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
	            (no)sub – enable/disable hardsubs. Default is to do hardsub.
	          (no)audio – use/throw away audio track. Default is to add sound.
	         si, k=1000 – Only for maximum file size – when converting
	                      [kMG] suffixes, use 1000 instead of 1024.
	          <format>p – force encoding to the specified resolution,
	                      <format> is one of: 1080, 720, 576, 480, 360.
	       small | tiny – override the default maximum file size (20M).
	        | unlimited   Values must be set in nadeshiko.rc.sh beforehand.
	                      Default presets are: small=10M, tiny=2M.
	    vb<number>[kMG] – force video bitrate to specified <number>.
	                      A suffix may be applied: vb300000, vb1200k, vb2M.
	      ab<number>[k] – force audio bitrate the same way.
	                      Example: ab128000, ab192k, ab88k.
	       crop=W:H:X:Y – crop video. Cannot be used with scale.
	           <folder> – place encoded file in the <folder>.

	The order of options is unimportant. Throw them in,
	Nadeshiko will do her best.

 

## Examples

Cut first 1 minute 20 seconds

	./nadeshiko.sh 'file.mkv' 0 1:20

Cut with milliseconds

	./nadeshiko.sh 'file.mkv' 17:21.01 18:00.652

> .1 = 100 ms, .01 = 10 ms, .001 = 1 ms

Fit the cut to 10 MiB instead of 20 MiB

	./nadeshiko.sh 'file.mkv' 17:21.01 18:00.652 small

Use Nadeshiko to archive something from home videos:
* force 1080p resolution;
* force video bitrate 4000 kbit/s;
* force audio bitrate 192 kbit/s;
* lift restriction on file size.

	./nadeshiko.sh 'birthday.mp4' 0:10 47:22  1080p vb4000k ab192k unlimited

> This example illustrates overriding everything at once, however any combination of overrides may be applied. It may be only the video bitrate or file size with resolution.

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

![Don’t let Nadeshiko die!](https://raw.githubusercontent.com/wiki/deterenkelt/Nadeshiko/img/Nadeshiko.jpg)

***

Nadeshiko uses ffmpeg (which in its turn includes libx264, libvpx, libopus, libvorbis, libfdk_aac, aac, libass), mediainfo, mkvtoolnix, GNU grep, GNU sed, GNU time.

> This program’s name is a reference to Kagamihara Nadeshiko, a character from [Yurucamp](https://en.wikipedia.org/wiki/Laid-Back_Camp). The original manga was drawn by あfろ for Houbunsha, and the anime television series is made by studio C-Station.

> The ghosts on the picture above were taken from [Katanagatari](https://en.wikipedia.org/wiki/Katanagatari). It was originally written as a light novel by Nisio Isin for Kodansha and illustrated by Take. The light novel was animated by studio White Fox.