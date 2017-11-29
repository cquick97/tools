# Copyright (c) 2015-2017 Franco Fichtner <franco@opnsense.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

STEPS=		arm base boot chroot clean core distfiles dvd info \
		kernel nano plugins ports prefetch print rebase \
		release rename serial sign skim test update verify \
		vga vm xtools
SCRIPTS=	batch nightly refresh pkg_fingerprint pkg_sign
.PHONY:		${STEPS}

PAGER?=		less

all:
	@cat ${.CURDIR}/README.md | ${PAGER}

lint-steps:
.for STEP in common ${STEPS}
	@sh -n ${.CURDIR}/build/${STEP}.sh
.endfor

lint-scripts:
.for SCRIPT in ${SCRIPTS}
	@sh -n ${.CURDIR}/scripts/${SCRIPT}.sh
.endfor

lint: lint-steps lint-scripts

# Special vars to load early build.conf settings:

TOOLSDIR?=	/usr/tools
TOOLSBRANCH?=	master
SETTINGS?=	17.7

CONFIG?=	${TOOLSDIR}/config/${SETTINGS}/build.conf

.-include "${CONFIG}"

# Bootstrap the build options if not set:

NAME?=		WITwall
TYPE?=		${NAME:tl}
SUFFIX?=	#-devel
FLAVOUR?=	OpenSSL
PHP?=		70
_ARCH!=		uname -p
ARCH?=		${_ARCH}
KERNEL?=	SMP
QUICK?=		#yes
ADDITIONS?=	os-dyndns
DEVICE?=	a10
SPEED?=		115200
UEFI?=		yes
GITBASE?=	https://github.com/cquick97
MIRRORS?=	https://opnsense.c0urier.net \
		http://mirrors.nycbug.org/pub/opnsense \
		http://mirror.wdc1.us.leaseweb.net/opnsense \
		http://mirror.sfo12.us.leaseweb.net/opnsense \
		http://mirror.fra10.de.leaseweb.net/opnsense \
		http://mirror.ams1.nl.leaseweb.net/opnsense
_VERSION!=	date '+%Y%m%d%H%M'
VERSION?=	${_VERSION}
STAGEDIRPREFIX?=/usr/obj
PORTSREFDIR?=	/usr/hardenedbsd-ports
PORTSREFBRANCH?=master
PLUGINSDIR?=	/usr/plugins
PLUGINSBRANCH?=	master
PORTSDIR?=	/usr/ports
PORTSBRANCH?=	master
COREDIR?=	/usr/core
COREBRANCH?=	master
COREENV?=	CORE_PHP=${PHP}
SRCDIR?=	/usr/src
SRCBRANCH?=	master

# A couple of meta-targets for easy use and ordering:

ports distfiles: base
plugins: ports
core: plugins
packages test: core
dvd nano serial vga vm: packages kernel
sets: distfiles packages kernel
images: dvd nano serial vga vm # arm
release: dvd nano serial vga

# Expand target arguments for the script append:

.for TARGET in ${.TARGETS}
_TARGET=	${TARGET:C/\-.*//}
.if ${_TARGET} != ${TARGET}
${_TARGET}_ARGS+=	${TARGET:C/^[^\-]*(\-|\$)//:S/,/ /g}
${TARGET}: ${_TARGET}
.endif
.endfor

.if "${VERBOSE}" != ""
VERBOSE_FLAGS=	-x
.else
VERBOSE_HIDDEN=	@
.endif

# Expand build steps to launch into the selected
# script with the proper build options set:

.for STEP in ${STEPS}
${STEP}: lint-steps
	${VERBOSE_HIDDEN} cd ${.CURDIR}/build && \
	    sh ${VERBOSE_FLAGS} ./${.TARGET}.sh -a ${ARCH} -F ${KERNEL} \
	    -f ${FLAVOUR} -n ${NAME} -v ${VERSION} -s ${SETTINGS} \
	    -S ${SRCDIR} -P ${PORTSDIR} -p ${PLUGINSDIR} -T ${TOOLSDIR} \
	    -C ${COREDIR} -R ${PORTSREFDIR} -t ${TYPE} -k "${PRIVKEY}" \
	    -K "${PUBKEY}" -l "${SIGNCHK}" -L "${SIGNCMD}" -d ${DEVICE} \
	    -m ${MIRRORS:Ox:[1]} -o "${STAGEDIRPREFIX}" -c ${SPEED} \
	    -b ${SRCBRANCH} -B ${PORTSBRANCH} -e ${PLUGINSBRANCH} \
	    -g ${TOOLSBRANCH} -E ${COREBRANCH} -G ${PORTSREFBRANCH} \
	    -H "${COREENV}" -Q "${QUICK}" -u "${UEFI:tl}" -U "${SUFFIX}" \
	    -V "${ADDITIONS}" -O "${GITBASE}" -q "${PHP}" \
	    ${${STEP}_ARGS}
.endfor

.for SCRIPT in ${SCRIPTS}
${SCRIPT}: lint-scripts
	${VERBOSE_HIDDEN} cd ${.CURDIR} && sh ${VERBOSE_FLAGS} \
	    ./scripts/${SCRIPT}.sh ${${SCRIPT}_ARGS}
.endfor
