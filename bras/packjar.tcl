########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996--2002 Harald Kirsch
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
# $Revision: 1.1 $, $Date: 2002/02/24 10:21:08 $
########################################################################

########################################################################
#
# packjar
#
# supports creation of a java archive (.jar).
#
# PARAMETERS:
# jar -- name of the archive file to create
# pkgroot -- directory which contains java-packages, i.e. for a
#   package text.regexp there must be a subdirectory text/regexp in
#   $pkgroot 
# pkgdirs -- name of package subdirectories to pack. For a package
#   text.regexp this would be text/regexp
# glob -- list of glob patterns specifying which files to pack in
#   every package directory. By default, all .class files are packed.
#
namespace eval ::bras {}
proc ::bras::packjar {jar pkgroot pkgdirs {glob *.class}} {
  set here [pwd]

  cd $pkgroot
  set files {}
  foreach dir $pkgdirs {
    foreach g $glob {
      set files [concat $files [glob -nocomplain [file join $dir $g]]]
    }
  }
  jar cf [file join $here $jar] $files
}
########################################################################
