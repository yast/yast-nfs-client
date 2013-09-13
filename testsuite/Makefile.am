#
# Makefile.am for .../testsuite
#

# enable make check in the working copy
export Y2DIR = $(top_srcdir)/src

AUTOMAKE_OPTIONS = dejagnu
EXTRA_DIST = $(wildcard tests/*.out) $(wildcard tests/*.err) $(wildcard tests/*.rb)

testsuite_prepare = @ydatadir@/testsuite/Makefile.testsuite

all-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir)

clean-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) clean

check-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) check

# EOF
