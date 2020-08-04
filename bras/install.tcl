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
########################################################################

##
## Install a file, i.e.:
## o) make directory for target, 
## o) copy source to target 
## o) (on UNIX) set permissions of target as requested.
##
proc ::bras::install {target source {perm ""}} {
  file mkdir [file dir $target]
  file delete -force $target
  file copy -force $source $target
  if {"$perm"!="" && "$::tcl_platform(platform)"=="unix"} {
    file attributes $target -permission $perm
  }
}
########################################################################
