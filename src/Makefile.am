#
# Makefile.am for y2c_nfs/src
#
# $Id$
#

clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/nfs
menudir = $(YAST2DIR)/menuentries

clients_DATA =		\
	nfs.ycp

include_DATA =		\
	routines.ycp	\
	ui.ycp		\
	nfs_write.ycp

menu_DATA = menuentry_nfs.ycp

EXTRA_DIST = $(clients_DATA) $(include_DATA) $(menu_DATA)
