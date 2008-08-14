# Makefile.am for source/nfs-client/src

myincludedir = @yncludedir@/nfs

client_DATA =		\
	nfs_auto.ycp	\
	nfs-client.ycp  \
	nfs-client4part.ycp \
	nfs.ycp

myinclude_DATA =	\
	routines.ycp	\
	ui.ycp		\
	wizards.ycp

module_DATA =		\
	Nfs.ycp

desktop_DATA = nfs.desktop

rncdir = $(schemadir)/autoyast/rnc
rnc_DATA = nfs.rnc

nfs:
	ln -sf . nfs

ycpchook = nfs

YCPCFLAGS = -I.

EXTRA_DIST = $(client_DATA) $(myinclude_DATA) $(module_DATA) $(desktop_DATA) $(rnc_DATA)

include $(top_srcdir)/Makefile.am.common
