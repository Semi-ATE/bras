
# $Revision: 1.44 $, $Date: 2002/03/04 19:13:12 $

## tclPkgUnknown, when running this script, makes sure that
## $dir is set to the directory of this very file

set VERSION 2.3.2
set VERDATE 2002-03-04

set script [subst -nocommands {
  source [file join "$dir" bras.tcl] 
  source [file join "$dir" consider.tcl] 
  source [file join "$dir" evalCmds.tcl] 
  source [file join "$dir" exported.tcl]
  source [file join "$dir" lastMinuteRule.tcl]
  source [file join "$dir" makeRule.tcl] 
  source [file join "$dir" predicates.tcl]
  source [file join "$dir" sourceDeps.tcl]
  package provide bras $VERSION 
  namespace eval bras [list set VERSION $VERSION]
  namespace eval bras [list set VERDATE $VERDATE]
  ## It would suffice to load the following on demand, but since I
  ## want them in namespace ::bras, the files are immediatly read by a
  ## namespace import ::bras::[A-Za-z]* anyway.
  source [file join "$dir" cvsknown.tcl]
  source [file join "$dir" install.tcl]
  source [file join "$dir" makedeps2bras.tcl]
  source [file join "$dir" packjar.tcl]
  source [file join "$dir" updateCacheC.tcl]
}]

#puts $script
package ifneeded bras $VERSION $script
