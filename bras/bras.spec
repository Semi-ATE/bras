
!!!! This is not currently maintained and is probably incomplete

## The following line is edited by my ship script to contain the true
## version I am shipping from cvs. (kir) $Revision: 1.13 $, $Date: 2001/12/30 09:08:53 $
%define VERSION 2.3.2

Summary: Rule based command execution (ala make), all written in Tcl
Name: bras
Version: %VERSION
Release: 0
Copyright: GPL
Group: Development/Building
Source: somewhere/bras-%{VERSION}.tar.gz
URL: http://bras.berlios.de/
Packager: Harald Kirsch (kirschh@lionbioscience.com)

Requires: tcl


BuildRoot: /tmp/bras-rpmbuild

%description
The program bras performs rule based command execution (similar to
`make'). It is written in Tcl and its rule files are also pure Tcl. It
knows several types of rules (Newer, Always, Exist) and allows to
implement more types easily. Additionally it does not break the chain
of reasoning (like make does) when it works in several directories.

%prep
%setup

%build
tclsh bras all prefix=/usr

%install
## There is an install script which understands a prefix ala configure
tclsh bras install prefix=$RPM_BUILD_ROOT/usr

#%post
## Fix the path to the tclsh
# Actually I would like to do the following, but is does not work due
# to rpms database locking (stupid)
# TCLSH=#\!`rpm -ql tcl|grep /tclsh$`
#TCLSH=#\!`which tclsh`
#p=/usr/bin
#cp $p/bras $p/bras.orig
#sed -e "1s,.*,$TCLSH,"  $p/bras.orig >$p/bras
#rm $p/bras.orig




%files
%attr(-,root,root) %doc doc/bras.ps
%attr(-,root,root) %doc doc/bras.pdf
%attr(-,root,root) %doc ANNOUNCE
%attr(-,root,root) %doc README
%attr(-,root,root) %doc CHANGES
%attr(-,root,root) %doc doc/bras.tex
%attr(-,root,root) %doc doc/varchanged-example.tcl
%attr(-,root,root) %doc examples

%attr(-,root,root) /usr/bin/bras
%attr(-,root,root) /usr/man/man1/bras.1

%attr(-,root,root) /usr/lib/bras-%{VERSION}
#%attr(-,root,root) %dir /usr/lib/bras-%{VERSION}

# %attr(-,root,root) /usr/lib/bras-%{VERSION}/bras
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/alwaysRule.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/brasUtils.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/consider.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/defaultCmd.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/defrule.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/dependsFileRule.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/evalCmds.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/existRule.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/exported.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/lastMinuteRule.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/newerRule.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/sourceDeps.tcl
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/rules.Linux
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/rules.SunOS
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/bras.1
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/ANNOUNCE
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/README
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/bras.ps
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/bras.tex
# %attr(-,root,root) /usr/lib/bras-%{VERSION}/Brasfile

