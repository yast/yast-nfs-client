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

nfs_client_version_checked = 1.2.7
nfs_client_version_installed := $(shell rpm --queryformat %{Version} -q nfs-client)

version-check:
	@if test "$(nfs_client_version_checked)" \< "$(nfs_client_version_installed)"; then \
		echo -e "\nWARNING: List of nfs-client options might be obsolete."; \
		echo "Checked version: $(nfs_client_version_checked)"; \
		echo -e "Used version: $(nfs_client_version_installed)\n"; \
	fi;

check-local: version-check

EXTRA_DIST = $(client_DATA) $(myinclude_DATA) $(module_DATA) $(desktop_DATA) $(rnc_DATA)

include $(top_srcdir)/Makefile.am.common
