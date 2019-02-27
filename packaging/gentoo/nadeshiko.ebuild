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


IUSE="+hardsub +mpv +x264 +fdk-aac +vp9 +opus vorbis +update-check time-stat"

RDEPEND="
	sys-apps/coreutils
	sys-apps/util-linux
	>=sys-apps/grep-3.0
	>=sys-apps/sed-4.3
	sys-process/procps
	>=media-video/ffmpeg-4.0[encode,threads,bluray]
	media-video/mediainfo
	dev-perl/File-MimeInfo
	sys-devel/bc

	hardsub? (
		>=media-video/ffmpeg-4.0[iconv,libass,truetype]
		media-video/mkvtoolnix
	)

	mpv? (
		>=media-video/mpv-0.28
		||(
			x11-libs/libnotify
			x11-libs/libtinynotify
		)
		>=dev-lang/python-3.0
		>=dev-python/pygobject-3.20
		>=x11-libs/gtk+-3.20
		app-text/xmlstarlet
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

	vp9=(
		>=media-video/ffmpeg-4.0[vpx]
		>=media-libs/libvpx-1.7.0
	)

	opus=(
		>=media-video/ffmpeg-4.0[opus]
	)

	vorbis=(
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


src_prepare() {
	epatch_user
}


src_install() {
	emake DESTDIR="${D}" -f packaging/gentoo/Makefile install \
		|| die "make install failed"
	dodoc RELEASE_NOTES  LICENCE
}
