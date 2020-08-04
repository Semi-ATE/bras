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
# $Revision: 1.12 $, $Date: 2002/01/20 21:44:38 $
########################################################################

namespace eval ::bras {
  namespace export Make PatternMake
  namespace export Newer PatternNewer
  namespace export Always PatternAlways
  namespace export Exist PatternExist
}
########################################################################

proc ::bras::Make {targets bexp {cmd {}}} {
  ::bras::enterRule $targets {} $bexp $cmd
}
########################################################################
proc ::bras::PatternMake {trexp gendep bexp cmd} {
  ::bras::enterPatternRule $trexp $gendep $bexp $cmd
}
########################################################################
proc ::bras::checkMake {rid theTarget} {
  set currentDir [pwd]
  set dirns [dirns .]

  ## This namespace is soleley set up to run the boolean
  ## expressions. This helps people to remember not to run predicates
  ## by hand. Doing so messes up the variable scopes I try to
  ## maintain. 
  set bns ::bras::ns[nextID]
  namespace eval $bns {namespace import ::bras::p::*}
  foreach x [info vars [set dirns]::*] {
    namespace eval $bns [list upvar $x [namespace tail $x]]
  }

  set res 0
  foreach {targets d b} $::bras::Rule($rid,bexp) {
    ## transfer values into $bns
    set [set bns]::target $theTarget
    set [set bns]::targets $targets
    if {""=="$d"} {
      catch {unset [set bns]::d}
    } else {
      set [set bns]::d $d    
    }

    ## we want to run $b by expr in namespace $bns
    #set cmd [list namespace eval $bns [list expr $b]]

    ## $b contains user's code, so care must be taken when
    ## running the command.
    if {[catch {runscript $bns [list expr $b]} r]} {
      set emsg "checking test `$b' for target `$theTarget' in [pwd]"
      cd $currentDir
      return -code error -errorinfo [fixErrorInfo 2 $emsg]
    }
    cd $currentDir
    set res [expr {$res || $r}]
  }
  namespace delete $bns

  return $res
}
########################################################################
#
# Some compatibility rules for rules files which used bras up to and
# including version 0.8.0 .
#
proc ::bras::Newer {targets deps {cmd {}}} {
  Make \
      $targets \
      [concat "\[" older [list $targets] [list $deps] "\]"] \
      $cmd
  #puts "Newer $targets $deps"
}
proc ::bras::PatternNewer {rexp dep cmd} {
  PatternMake $rexp $dep {[older $target $d]} $cmd
}

proc ::bras::Always {targets deps {cmd {}}} {
  Make $targets [concat "\[" true [list $deps] "\]"] $cmd
}

proc ::bras::PatternAlways {rexp dep cmd} {
  PatternMake $rexp $dep {[true $d]} $cmd
}

proc ::bras::Exist {targets {cmd {}}} {
  Make $targets [concat "\[" missing [list $targets] "\]"] $cmd
}

