#
# Makefile.am for y2c_nfs/doc
#
# $Id$
#

SUBDIRS = autodocs

docdir = @DOCDIR@
htmldir = $(docdir)

screenshots = \
	nfs1.png \
	nfs2.png \
	save.png \
	abort.png
workflow.png: workflow.dia $(screenshots)
	dia --export=$@ $<
MAINTAINERCLEANFILES = workflow.png

html_DATA = index.html workflow.dia workflow.png $(screenshots)
EXTRA_DIST = $(html_DATA)
