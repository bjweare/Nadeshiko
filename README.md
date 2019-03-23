<h1 align="center">
    Nadeshiko
</h1>
<p align="center">
    <i>A Linux tool to cut short videos with ffmpeg</i>
</p>

## nadeshiko.sh

Command line tool. Smart. Configurable. Extensible.

![GIF: Using Nadeshiko in terminal](https://raw.githubusercontent.com/wiki/deterenkelt/Nadeshiko/img/nadeshiko_in_a_terminal.gif)

[Why it is best](https://github.com/deterenkelt/Nadeshiko/wiki/Why-Nadeshiko-is-best)  ⋅  [How to use](https://github.com/deterenkelt/Nadeshiko/wiki/Nadeshiko)  ⋅  [Tips](https://github.com/deterenkelt/Nadeshiko/wiki/Tips-for-Nadeshiko)

 

## nadeshiko-mpv.sh

Wrapper to be used with mpv player.

![GIF: Nadeshiko-mpv in action](https://raw.githubusercontent.com/wiki/deterenkelt/Nadeshiko/img/nadeshiko-mpv.gif)

[Predictor](https://github.com/deterenkelt/Nadeshiko/wiki/Nadeshiko%E2%80%91mpv.-Predictor)  ⋅  [How to use](https://github.com/deterenkelt/Nadeshiko/wiki/Nadeshiko%E2%80%91mpv)  ⋅  [Tips](https://github.com/deterenkelt/Nadeshiko/wiki/Tips-for-Nadeshiko%E2%80%91mpv)

 

## Main features

* <ins>Guarantees</ins> to fit clip in a specified size.
  * One run – one clip. No more encoding by trial and error.
* Keeps the quality good or refuses to encode.
  * Optimal bitrate ranges are determined by the codec type, resolution and scene complexity.
  * No need to learn FFmpeg!
  * Resolution may be lowered as necessary to save quality.
  * Built-in predictor <br><a href="https://github.com/deterenkelt/Nadeshiko/wiki/Nadeshiko%E2%80%91mpv.-Predictor">
<img alt="Predictor" src="https://raw.githubusercontent.com/wiki/deterenkelt/Nadeshiko/img/nadeshiko-mpv-predictor/predictor.gif"/>
</a>

* Customiseable
  * Every setting is configurable through a simple config file.
  * Preconfigured options for VP9 (+2 audio codecs) and H.264 (+3 audio codecs).
  * Turn subtitles and audio `on` or `off` by default.
  * Fine-tune the encoding mechanism (but be careful!)
  * If you feel like adding a key or two to the default FFmpeg command – you can add them as input or output options (1 pass and 2 pass separately).
  * Clone configs to create custom presets!
* Simple installation
  * Download and run. No compilation is needed.
* Hardsubbing
  * SubRip (.srt), ASS (.ass, .ssa), WebVTT (.vtt), built-in or external – **yes**.
  * DVD and Bluray subtitlies – built-in only – **yes**
  * with fonts, as you see them in the player – Nadeshiko will extract them, if necessary, and turn on OpenType for FFmpeg.
* Cropping
  * Set coordinates by hand…
  * Or pick them interactively (built-in [mpv_crop_script](https://github.com/TheAMM/mpv_crop_script)).

 

## Don’t look down

Read about [which codec is best at what](https://github.com/deterenkelt/Nadeshiko/wiki/Tips#----differences-between-codec-sets) or even better – go through the [**Crash course**](https://github.com/deterenkelt/Nadeshiko/wiki/Crash-course), you d-don’t need to know the scary truth… Don’t look down.


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
<i>Nadeshiko uses ffmpeg (which in its turn includes libx264, libvpx, libopus, libvorbis, libfdk_aac, aac, libass…), mediainfo, mkvtoolnix, mpv_crop_script by TheAMM, GNU grep, GNU sed and GNU time.<br><br>Let’s be grateful to them for their hard work.</i>
</p>
