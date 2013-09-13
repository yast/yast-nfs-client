# Sources for nfs-client

module_DATA = \
  modules/Nfs.rb \
  modules/NfsOptions.rb

client_DATA = \
  clients/nfs_auto.rb \
  clients/nfs-client4part.rb \
  clients/nfs-client.rb \
  clients/nfs.rb

yncludedir = @yncludedir@/nfs
ynclude_DATA = \
  include/nfs/routines.rb \
  include/nfs/ui.rb \
  include/nfs/wizards.rb

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/nfs.rnc

desktop_DATA = \
  desktop/nfs.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(schemafiles_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common