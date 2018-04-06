# Sources for nfs-client

module_DATA = \
  modules/NfsOptions.rb \
  modules/Nfs.rb

client_DATA = \
  clients/nfs.rb \
  clients/nfs_auto.rb \
  clients/nfs-client4part.rb \
  clients/nfs-client.rb

yncludedir = @yncludedir@/nfs
ynclude_DATA = \
  include/nfs/wizards.rb \
  include/nfs/ui.rb \
  include/nfs/routines.rb

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/nfs.rnc

desktop_DATA = \
  desktop/nfs.desktop

ylibdir = @ylibdir@/fstab
ylib_DATA = \
  lib/fstab/tsort.rb

y2nfslibdir = @ylibdir@/y2nfs_client
y2nfslib_DATA = \
  lib/y2nfs_client/nfs_version.rb

EXTRA_DIST = \
	$(module_DATA) $(client_DATA) $(ynclude_DATA) $(schemafiles_DATA) $(desktop_DATA) $(ylib_DATA) $(y2nfslib_DATA)

include $(top_srcdir)/Makefile.am.common
