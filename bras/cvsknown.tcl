########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996--2000 Harald Kirsch
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# $Revision: 1.4 $, $Date: 2002/02/24 10:16:02 $
########################################################################

########################################################################
#
# cvsknown
# returns the name of all files CVS knows about in the current
# directory and in subdirectories.
#
# Since I did not find a really useful command for that in CVS itself, 
# I try to find out myself. This is tested with cvs 1.10.6. It may or
# may not work with other versions, depending on the format of the
# files CVS/Entries.
#
# In fact using only CVS/Entries has the added convenience, that the
# repository does not need to be online.
#
# PARAMETER:
# dir -- this is normally used only internally
namespace eval ::bras {}
proc ::bras::cvsknown { {dir {}} } {
  #puts ">>> `$dir'"
  if {![file readable CVS/Entries]} {
    return {}
  }

  set res {}
  set in [open CVS/Entries r]; set entries [read $in]; close $in
  foreach l [split $entries \n] {
    set l [split $l /]
    if {[llength $l]!=6} continue
    if {[string match D* [lindex $l 0]]} continue
    lappend res [file join $dir [lindex $l 1]]
  }
  
  set pwd [pwd]
  foreach x [glob -nocomplain .* *] {
    if {"$x"==".." || "$x"=="." || "$x"=="CVS"} continue
    if {![file isdir $x]} continue
    cd $x
    set res [concat $res [cvsknown [file join $dir $x]]]
    cd $pwd
  }
  #  puts (($res))
  return $res
}
