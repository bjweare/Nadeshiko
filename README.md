# Nadeshiko
A Linux tool to cut short videos with ffmpeg.

![Nadeshiko in terminal](https://raw.githubusercontent.com/wiki/deterenkelt/Nadeshiko/img/promo_cleaned.gif)

<p>
Samples made on the gif above (allow raw.githubusercontent.com, if there’s no gif):<br>
4 seconds, H264+AAC, 1.8 MiB: &lt;<a href="https://gs.smuglo.li/file/51b2af3f3eeafe259ab9a8e7cd03c36cac9eb7b79b287f65eacca67dd708d0dc.mp4">link</a>&gt;.<br>
4 minutes, VP9+Opus, 8.9 MiB: &lt;<a href="https://gs.smuglo.li/file/6cd25df4cdff5f0d6fc84b4959a481883b31aa58e09ad05cb515029d917810ea.webm">link</a>&gt;.<br>
</p>

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

	$ ./nadeshiko.sh 'file.mkv' 0 1:20

Cut with milliseconds

	$ ./nadeshiko.sh 'file.mkv' 17:21.01 18:00.652

> .1 = 100 ms, .01 = 10 ms, .001 = 1 ms

Fit the cut to 10 MiB instead of 20 MiB

	$ ./nadeshiko.sh 'file.mkv' 17:21.01 18:00.652 small

Use Nadeshiko to archive something from home videos. For example:
* to force 1080p resolution, pass `1080p`;
* to force video bitrate 4000 kbit/s, pass `vb4000k` or `vb4M`;
* to force audio bitrate 192 kbit/s, pass `ab192k`;
* to lift restriction on file size, pass `unlimited`.

<pre>
$ ./nadeshiko.sh 'birthday.mp4' 0:10 47:22  1080p vb4000k ab192k unlimited
</pre>

> This example illustrates overriding everything at once, however any combination of overrides may be applied. It may be only the video bitrate or file size with resolution.*

The order of options is not important. More options are listed above.

 

## How does it work

First, Nadeshiko reads maximum allowed file sizes from nadeshiko.rc.sh, the config file:

```bash
 # Maximum size for encoded file
#
#  [kMG] suffixes use powers of 2, unless kilo is set to 1000.
max_size_default=20M
#
#  Pass “small” to the command line to use this maximum size.
max_size_small=10M
#
#  Pass “tiny” to the command line to use this maximum size.
max_size_tiny=2M
```

The sizes can be changed there. Until `small`, `tiny` or `unlimited` passed via command line, Nadeshiko will use whatever is set to `max_size_default`. By default it’s set to 20 MiB.

Then Nadeshiko looks at the original file resolution, let’s take *1080p*, and looks for the corresponding bitrates in the RC file

```bash
libx264_1080p_desired_bitrate=3500k
libvpx_1080p_desired_bitrate=1800k
audio_1080p_desired_bitrate=128k
```

There are several blocks like this for each of the resolutions, that Nadeshiko can scale to: 1080p, 720p, 576p, 480p and 360p.

― A-ha! — Says Nadeshiko as she picks the audio bitrate and takes it to a calc.

Now she multiplies all seconds, that need to be encoded, to the audio bitrate. Total space needed for the audio is summed with the space for the file container itself – and what remains is what’s left for the video. Nadeshiko is lost in thoughts about mount Fuji for a minute, then divides the remains of the free space to the seconds, which need to be encoded. Hooray, we now know what maximum video bitrate fits this size!

If the found bitrate falls between the desired and minimal (which is 45% of the desired) video bitrate, this resolution suits Nadeshiko and she calls FFmpeg ojii-san to encode our stuff. If what fits happens to be lower than the minimal bitrate, Nadeshiko will try a lower reolution, *720p* in this case, and repeat calculations until either found bitrate will fall to some resolution or until Nadeshiko would strike out all resolutions and refuse to encode.

Ah, one important moment is choosing a video codec. They are defined in the RC file again

```bash
 # A/V codecs and containers
#  Supported combinations:
#  1) libx264 + libfdk_aac/aac in mp4 (Nadeshiko’s default)
#  2) libvpx-vp9 + libopus/libvorbis in webm (Experimental!)
#
#  Video codec
#  “libx264” – good quality, fast, options are well-known
#  “libvpx-vp9” – better quality, but slower, options are weird and quirky.
ffmpeg_vcodec='libx264'
#
#  Audio codec
#  If you don’t have libfdk_aac, use either “libvorbis” or “aac″.
#  “libopus” – best, but only for libvpx-vp9.
#  “libvorbis” – good, but only for webm, hence libvpx-vp9.
#  “libfdk_aac” – equally good, for mp4, hence libx264.
#  “aac” – still good, but worse than libvorbis and libfdk_aac.
#  “libmp3lame”, “ac3”… – it’s 2018, don’t use them.
ffmpeg_acodec='aac'
```

Nadeshiko can pick an appropriate container – mp4 or webm – herself, but the codecs must be correctly set in the RC file. You do not have to worry about configuring it, as Nadeshiko will create a standard RC file with a good configuration for you on the first run.

### Subtitles, audio, default scale

By default Nadeshiko renders subtitles on the clip. It’s sometimes called a “hardsub”. Command line options `sub` and `nosub` override what’s specified in the RC file.

Same goes for audio, it can be enabled and disabled by default in the RC file and then overriden in command line – with `audio` and `noaudio`.

Default scale, if defined in the RC file, will remove any higher resolution – including the native one – from the list of resolutions, that Nadeshiko can scale to. This doesn’t force, i.e. fixate the resolution like a `720p` or `480p` option, passed via command line, would do. It only sets an “upper bound” – Nadeshiko may still use lower resolutions, if needed.

### Don’t look down

Eeeh…;; Check the list of [known issues](https://github.com/deterenkelt/Nadeshiko/wiki/Known-issues) or [which codec should you use](https://github.com/deterenkelt/Nadeshiko/wiki/Tips#which-codec-set-to-use), d-don’t look down.


<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>


![Don’t let Nadeshiko die!](https://raw.githubusercontent.com/wiki/deterenkelt/Nadeshiko/img/Nadeshiko.jpg)

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
.
</p>

<p align="center">
<i>This program’s name is a reference to Nadeshiko Kagamihara, a character from <a href="https://en.wikipedia.org/wiki/Laid-Back_Camp">Yurucamp</a>. The original manga was drawn by あfろ for Houbunsha, and the anime television series is made by studio C-Station.</i>
</p>

<p align="center">
<i>The ghosts on the picture above were taken from <a href="https://en.wikipedia.org/wiki/Katanagatari">Katanagatari</a>. It was originally written as a light novel by Nisio Isin for Kodansha and illustrated by Take. The light novel was animated by studio White Fox.</i>
</p>

<p align="center">
<i>Nadeshiko uses ffmpeg (which in its turn includes libx264, libvpx, libopus, libvorbis, libfdk_aac, aac, libass…), mediainfo, mkvtoolnix, GNU grep, GNU sed and GNU time.<br><br>Let’s be grateful to them for their hard work.</i>
</p>
