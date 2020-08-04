########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 2002 Harald Kirsch
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
# $Revision: 1.1 $, $Date: 2002/02/24 10:10:44 $
#
########################################################################

## NO! this does not translate makefiles to brasfiles. It is only
## intended to filter the dependencies out of a file created e.g. by
## gcc -M or jikes +M
## Dependencies matching the
## given regular expression are not included in the list.
##

#puts "now reading [info script]"

proc ::bras::makedeps2bras {text exclude} {
  ## Join continuation lines, i.e. lines ending with backslash
  ## get the next line attached.
  regsub -all "\[\\\\\]\n" $text " " text

  ## Every line should now look like 
  ##   target : dep1 dep2 dep3
  ## We don't try to be cute about funny characters within file
  ## names, because `make' would probably not work with them too.
  ## And we don't care for the target. It should be always the
  ## same.
  set deps {}
  foreach line [split $text "\n"] {
    regsub {^[^:]+:} $line {} line
    foreach dep [split $line] {
      set dep [string trim $dep]
      if {""=="$dep"} continue
      if {""!="$exclude" && [regexp $exclude $dep]} continue
      lappend deps $dep
    }
  }
  return $deps
}
########################################################################
