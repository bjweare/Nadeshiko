#  nadeshiko-${PV}.ebuild
#  © deterenkelt 2019
#  Distributed under the terms of the GNU General Public License v3

EAPI="7"
inherit eutils

SLOT="0"
DESCRIPTION="A Linux tool to cut short videos with ffmpeg"
HOMEPAGE="https://github.com/deterenkelt/Nadeshiko"
SRC_URI="https://github.com/deterenkelt/Nadeshiko/archive/v${PV}.tar.gz -> ${P}.tar.gz"
LICENSE="GPL-3"
MERGE_TYPE="binary"
KEYWORDS="~*"


IUSE="+hardsub +crop +mpv +x264 +fdk-aac +vp9 +opus vorbis +update-check time-stat"

RDEPEND="
	>=app-shells/bash-4.4
	sys-apps/coreutils
	sys-apps/util-linux
	>=sys-apps/grep-3.0
	>=sys-apps/sed-4.3
	sys-process/procps
	>=media-video/ffmpeg-4.0[encode,threads,bluray]
	media-video/mediainfo
	dev-perl/File-MimeInfo
	sys-devel/bc
	app-text/xmlstarlet

	hardsub? (
		>=media-video/ffmpeg-4.0[iconv,libass,truetype]
	)

	crop? (
		sys-fs/inotify-tools
	)

	mpv? (
		>=media-video/mpv-0.28
		x11-libs/libnotify
		>=dev-lang/python-3.0
		>=dev-python/pygobject-3.20
		>=x11-libs/gtk+-3.20
		sys-apps/findutils
		sys-process/lsof
		app-misc/jq
		net-misc/socat
	)

	x264? (
		>=media-video/ffmpeg-4.0[x264]
	)

	fdk-aac? (
		>=media-video/ffmpeg-4.0[fdk]
	)

	vp9? (
		>=media-video/ffmpeg-4.0[vpx]
		>=media-libs/libvpx-1.7.0
	)

	opus? (
		>=media-video/ffmpeg-4.0[opus]
	)

	vorbis? (
		>=media-video/ffmpeg-4.0[vorbis]
	)

	update-check? (
		net-misc/wget
		x11-misc/xdg-utils
	)

	time-stat? (
		sys-process/time
	)
	"

REQUIRED_USE="
	|| ( x264 vp9 )
	fdk-aac? ( x264 )
	opus? ( vp9 )
	vorbis? ( vp9 )
	"


src_unpack() {
	unpack ${A}
	cd "${S}"
	#  Make will expect the directory name in lowercase.
	mv ${PN^}-${PV}  ${PN,}-${PV}
}


src_prepare() {
	default
}


src_install() {
	emake PREFIX="/usr" DESTDIR="${D}" install
}
