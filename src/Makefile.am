#
# Makefile.am for y2c_nfs/src
#
# $Id$
#

clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/nfs
modulesdir = $(YAST2DIR)/modules
menudir = $(YAST2DIR)/menuentries

clients_DATA =		\
	nfs_write.ycp   \
	nfs.ycp

include_DATA =		\
	routines.ycp	\
	ui.ycp

modules_DATA = \
	Nfs.ycp

menu_DATA = menuentry_nfs.y2cc

EXTRA_DIST = $(clients_DATA) $(include_DATA) $(modules_DATA) $(menu_DATA)
