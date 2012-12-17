# Makefile.am for source/nfs-client/src

myincludedir = @yncludedir@/nfs

YCPC_Y2DIR = .

client_DATA =			\
	clients/nfs_auto.ycp	\
	clients/nfs-client.ycp  \
	clients/nfs-client4part.ycp \
	clients/nfs.ycp

myinclude_DATA =			\
	include/nfs/routines.ycp	\
	include/nfs/ui.ycp		\
	include/nfs/wizards.ycp

module_DATA =		\
	modules/Nfs.ycp

desktop_DATA = nfs.desktop

rncdir = $(schemadir)/autoyast/rnc
rnc_DATA = nfs.rnc

EXTRA_DIST = $(client_DATA) $(myinclude_DATA) $(module_DATA) $(desktop_DATA) $(rnc_DATA)

include $(top_srcdir)/Makefile.am.common
