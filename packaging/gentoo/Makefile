#  Nadeshiko Makefile
#  © deterenkelt 2019


bindir   := /usr/bin
libdir   := /usr/lib/nadeshiko
sharedir := /usr/share/nadeshiko
#docdir   := /usr/share/doc/nadeshiko

build:
# nothing to build

install:
	install -m 0755 nadeshiko.sh  \
	                nadeshiko-mpv.sh  \
	                nadeshiko-do-postponed.sh  \
	        -D -t ${DESTDIR}${bindir}
	install -d  ${DESTDIR}${libdir}
	cp -r --preserve=mode  lib/*  \
	                       modules/*  -t ${DESTDIR}${libdir}
#	install -m 0644 RELEASE_NOTES \
#	        -D -t ${DESTDIR}${docdir}
