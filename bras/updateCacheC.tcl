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
# $Revision: 1.2 $, $Date: 2002/02/24 11:53:50 $
#
########################################################################
##

## NOTE: This works with "jikes +M" too, except if you have classes
## which mutually depend on each other. In the latter case, bras will
## complain about a dependency loop.
proc ::bras::updateCacheC {target src _cmd _opts _exclude} {
  upvar $_cmd cmd
  upvar $_opts opts
  upvar $_exclude exclude
  set text [eval exec "$cmd $opts $src"]
  if {[info exist exclude]} {
    set l [makedeps2bras $text $exclude]
  } else {
    set l [makedeps2bras $text ""]
  }
  set out [open $target w]
  puts $out $l
  close $out
}
