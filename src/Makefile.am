#
# Makefile.am for y2c_nfs/src
#
# $Id$
#

myincludedir = @yncludedir@/nfs

client_DATA =		\
	nfs_write.ycp   \
	nfs_auto.ycp	\
	nfs-client.ycp  \
	nfs.ycp

myinclude_DATA =		\
	routines.ycp	\
	ui.ycp

module_DATA = \
	Nfs.ycp

config_DATA = nfs.y2cc

EXTRA_DIST = $(client_DATA) $(myinclude_DATA) $(module_DATA) $(config_DATA) 
