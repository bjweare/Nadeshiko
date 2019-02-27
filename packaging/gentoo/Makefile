#  Nadeshiko Makefile
#  © deterenkelt 2019

PREFIX   := /usr
BINDIR   := ${DESTDIR}${PREFIX}/bin/
LIBDIR   := ${DESTDIR}${PREFIX}/lib/nadeshiko/
SHAREDIR := ${DESTDIR}${PREFIX}/share/nadeshiko/
# DOCDIR   := ${DESTDIR}${PREFIX}/share/doc/nadeshiko


.PHONY: build
build:
# nothing to build


.PHONY: install
install:
	install -m 0755 -d ${BINDIR} \
	                   ${LIBDIR} \
	                   ${SHAREDIR} \
	                   ${DOCDIR}
	install -m 0755 nadeshiko.sh  \
	                nadeshiko-mpv.sh  \
	                nadeshiko-do-postponed.sh  \
	        -t ${BINDIR}
	cd ${BINDIR} \
		&& ln -s nadeshiko.sh  nadeshiko \
		&& ln -s nadeshiko-mpv.sh  nadeshiko-mpv \
		&& ln -s nadeshiko-do-postponed.sh  nadeshiko-do-postponed
	cp -r --preserve=mode  lib/*  \
	                       modules/*  -t ${LIBDIR}
	cp -r --preserve=mode  exampleconf  \
	                                  -t ${SHAREDIR}
	install -m 0644 RELEASE_NOTES  LICENCE  \
	        -t ${SHAREDIR}


.PHONY: uninstall
uninstall:
	rm  ${BINDIR}/nadeshiko     \
	    ${BINDIR}/nadeshiko.sh  \
	    ${BINDIR}/nadeshiko-mpv     \
	    ${BINDIR}/nadeshiko-mpv.sh  \
	    ${BINDIR}/nadeshiko-do-postponed    \
	    ${BINDIR}/nadeshiko-do-postponed.sh
	rm -rf ${LIBDIR}  \
	       ${SHAREDIR}
