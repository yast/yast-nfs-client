#
# Makefile.am for nfs-client/doc
#
# $Id$
#

SUBDIRS = autodocs

htmldir = $(docdir)

screenshots = \
	nfs-client-*.png \
	abort.png
workflow.png: workflow.dia $(screenshots)
	dia --export=$@ $<
MAINTAINERCLEANFILES = workflow.png

html_DATA = index.html workflow.dia workflow.png $(screenshots)
EXTRA_DIST = $(html_DATA)
