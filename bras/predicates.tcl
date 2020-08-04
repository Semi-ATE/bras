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
# $Revision: 1.14 $, $Date: 2002/02/24 10:18:56 $
########################################################################

########################################################################
#
# Define the predicates to be used as dependencies in Make-rules.
#
# They all go into the namespace ::bras::p
#
########################################################################
namespace eval ::bras::p {
  namespace export older pairedolder updated missing true \
      dcold oldcache \
      varchanged or notinitialized md5older
}
########################################################################
#
# Every predicate should run this proc right at the start. It is a
# shortcut declaration of several namespace variables and it expands
# dependencies along searchpath.
#
# PARAMETER
# -- names
# a list of variable names to be installed in namespace
# $::bras::nspace. The name `reason' is always installed and need not
# be mentioned. 
# -- depvars
# a list of variable NAMES (not values) in the calling predicate each
# of which contains dependencies which must be expanded along the
# searchpath.
#
proc ::bras::p::installPredicate { names {depvars {}} } {
  upvar \#0 ::bras::Opts Opts 

  if {$Opts(-d)} {::bras::dmsg "testing \[[info level -1]\]"}

  ## Within the calling predicate, we install all variables listed in
  ## $names as local variables linked to variables of the same name in 
  ## the namespace $::bras::nspace. One additional variable called
  ## `reason' is always installed that way.
  foreach n $names {
    uplevel 1 [list upvar \#0  [set ::bras::Pstack]::$n $n]
    uplevel 1 "if {!\[info exist $n\]} {set $n {}}"
  }
  uplevel 1 [list upvar \#0 [set ::bras::Pstack]::reason reason]

  ## Expand dependencies stored in any of the varialbles noted in
  ## depvars along the searchpath. The result is put into these
  ## variables again.
  foreach v $depvars {
    upvar $v deps
    set res {}
    foreach d $deps {
      set s [::bras::searchDependency $d]
      if {""=="$s"} {set s $d}
      lappend res $s
    }
    set deps $res
    if {$Opts(-d)} {::bras::dmsg "expanded deps: `$deps'"}
  }
}
########################################################################
#
# tests if any of the targets
# -- does not exist
# -- is older than any of the dependencies listed in $inDeps
# This predicate is also true, if any of the dependencies in $inDeps
# is considered out-of-date.
#
proc ::bras::p::older {targets inDeps} {
  installPredicate {trigger deps} inDeps

  #puts "older:: $targets < $inDeps"

  ## Consider all dependencies in turn
  set results [::bras::consider $inDeps]

  ## potential @ in deps no longer needed after consider
  set inDeps [stripAt $inDeps]

  ## cache all mtimes of inDeps
  foreach  d $inDeps   x $results  {
    if {![file exist $d]} {
      ## Ooops. Obviously $d is not really a file but some other
      ## strange stuff. We cannot test its mtime to compare with the
      ## targets but we have $x indicating if $d was just made or
      ## not. If it was made ($x==1) we set the mtime to -1 meaning
      ## that it is very new.
      set mtime($d) [expr {$x?-1:0}]
    } else {
      set mtime($d) [file mtime $d]
    }
  }
  
  set res 0
  foreach t $targets {
    ## check if target exists, get its mtime
    if {[file exist $t]} {
      set ttime [file mtime $t]
    } else {
      set ttime 0
      append reason \
	  "\n`$t' is considered very old because it does not exist"
      set res 1
    }
    ## Now check if $t is older than any of inDeps
    set older {}
    set fresh {}
    foreach d $inDeps {
      if {$mtime($d)<0} {
	## Yes, $d was just made (yet does not exist)
	set res 1
	lappend fresh $d
	::bras::lappendUnique trigger $d
      } elseif {$ttime<$mtime($d)} {
	## NOTE: The test above *must* feature '<' not '<=' because on
	## a fast computer, dependencies and the target can easily be
	## made all within one second. This would cause this rule to
	## trigger over and over again.
	set res 1
	lappend older $d
	::bras::lappendUnique trigger $d
      }
    }
    if {[llength $fresh]} {
      append reason \
	  "\n`$t' is considered older than just created `$fresh'"
    }
    if {[llength $older]} {
      append reason "\n`$t' is older than `$older'"
    }
  }

  ::bras::concatUnique deps $inDeps

  return $res
}
########################################################################
#
# tests if i'th element of $targets does not exist or is older than
# i'th element of $inDeps. Compare this with [older] where every
# element of $targets is tested against every element of $inDeps.
# 
proc ::bras::p::pairedolder {targets inDeps} {
  if {[llength $targets]!=[llength $inDeps]} {
    return -code error "input lists must have equal length"
  }

  installPredicate {trigger deps} inDeps
  ## Consider all dependencies in turn
  set results [::bras::consider $inDeps]

  ## potential @ in deps no longer needed after consider
  set inDeps [stripAt $inDeps]

  set res 0
  foreach t $targets   d $inDeps   x $results {
    if {![file exist $t]} {
      set res 1
      append reason "\n`$t' does not exist"
      ::bras::lappendUnique trigger $d
      continue
    }
    if {![file exist $d]} {
      if {$x} {
	set res 1
	append reason "\n`$d' was just made"
	::bras::lappendUnique trigger $d
      }
      continue
    }
    set ttime [file mtime $t]
    set dtime [file mtime $d]
    if {$ttime<$dtime} {
      set res 1
      append reason "\n`$t' is older than `$d'"
      ::bras::lappendUnique trigger $d
    }
  }
  ::bras::concatUnique deps $inDeps
  return $res
}
########################################################################
#
# returns true, if any of its arguments is made when
# considered.
#
proc ::bras::p::updated {inDeps} {
  installPredicate {trigger deps} inDeps

  ## Consider all dependencies in turn
  set results [::bras::consider $inDeps]

  ## potential @ in deps no longer needed after consider
  set inDeps [stripAt $inDeps]

  set res 0
  ::bras::concatUnique deps $inDeps
  foreach d $inDeps   x $results {
    if {$x} {
      set res 1
      ::bras::lappendUnique trigger $d
      append reason "\n`$d' was made"
    }
  }

  return $res
}
########################################################################
#
# tests if the given target is not an existing file (or directory)
#
proc ::bras::p::missing {file} {
  installPredicate trigger

  if {![file exist $file]} {
    append reason "\n`$file' does not exist"
    ::bras::lappendUnique trigger $file
    return 1
  }
  return 0
}
########################################################################
#
# always returns 1. The use of [true] is preferred over the use of `1' 
# because of the log-information.
#
proc ::bras::p::true {{inDeps {}}} {
  installPredicate deps inDeps

  ::bras::consider $inDeps

  ## potential @ in deps no longer needed after consider
  set inDeps [stripAt $inDeps]

  append reason "\nmust always be made"
  ::bras::concatUnique deps $inDeps
  return 1
}
########################################################################
#
# Source the given $file and return a list which contains all
# variables and their values set in $file.
#
proc ::bras::fetchvalues-not-supported-dont-use {_ary file} {
  upvar $_ary ary

  ## Want to source in a fresh interpreter
  set ip [interp create]
  
  ## we don't consider predefined variables like tcl_patchLevel.
  foreach x [$ip eval info vars] {
    set predefined($x) 1
  }

  ## source the file
  if {[catch {$ip eval source $file} msg]} {
    return -code error $msg
  }

  ## copy all vars, except thte predefined ones, from $ip into ary
  foreach x [$ip eval info vars] {
    if {[info exist predefined($x)]} continue

    if {[$ip eval array exist $x]} {
      foreach elem [$ip eval array names $x] {
	set ary($x\($elem\)) [$ip eval set $x\($elem\)]
      }
    } else {
      set ary($x) [$ip eval set $x]
    }
  }
  interp delete $ip
}
########################################################################
#
# tests if target $doto is older than any of the files listed in
# dependency cache $dc. As a side-effect, the dependency
# cache is considered and brought up-to-date.
#
proc ::bras::p::dcold {doto dc} {  
  installPredicate {} dc

  ## First of all, the dependency cache $dc must be up-to-date
  ::bras::consider $dc

  if {[string match @* $dc]} {
    set dc [string range $dc 1 end]
  }

  ## The rest is trivial
  set in [open $dc r]; set dlist [join [split [read $in]]]; close $in
  return [older $doto $dlist]
}    
########################################################################
#
# tests if a dependency-cache (dc) file is out of date. This is the
# case, if
# -- it does not exist
# -- it is [older] than the given dotc-file
# -- it is [older] than any of the files listed in it
#
proc ::bras::p::oldcache {dc dotc} {
  installPredicate {trigger deps} dotc

  if {[file exist $dc]} {
    set in [open $dc r]; set dlist [join [split [read $in]]]; close $in
    set dlist [concat $dotc $dlist]
  } else {
    set dlist $dotc
  }

  return [older $dc $dlist]
}
########################################################################
##
## Tests, if the given variable is different from a copy stored in the
## file $oldResults. Except if you really know what you are doing, all 
## variable names given in $varnames must be fully
## namespace-qualified, i.e. the name starts with `::'. Arrays as well 
## as references to array elements are also allowed. The test returns
## true, if any of the following conditions holds:
## 1) The file $oldResults does not exist,
## 2) A variable reference (scalar var, array, or array element) in
##    $varnames is not set while reading $oldResults,
## 3) The current value referenced by a variable reference in
##    $varnames differs from the value found in $oldResults.
##
proc ::bras::p::varchanged {varnames oldResults} {
  variable varChanged

  installPredicate [list trigger deps] {}

  ::bras::consider $varnames

  ## potential @ in some of the var name no longer needed after consider
  set varnames [stripAt $varnames]

  ## create a new interpreter and source $oldResults into it. If the
  ## file does not even exist, this means that all given vars are
  ## changed.
  if {![file exist $oldResults]} {
    if {![llength $varnames]} {return 0}
    append reason "\ncache file `$oldResults' does not exist"
    return 1
  }

  set ip [interp create]
  $ip eval source $oldResults

  ## Now compare the current values of all listed variables with the
  ## copies found in $ip.
  set res 0
  foreach v $varnames {
    ## If $v, which can also reference an array element, does not
    ## exist, it was obviously changed.
    if {![$ip eval info exist [list $v]]} {
      append reason "\nvariable `$v' was unknown before"
      ::bras::lappendUnique trigger $v
      set res 1
      continue
    }

    if {[array exist $v]} {
      # Arrays are a pain, because we have to check every index.
      foreach x [array names $v] {
	if {![$ip eval info exist [list $v\($x\)]]} {
	  append reason "\nat least element `$x' of `$v' is new"
	  ::bras::lappendUnique trigger $v
	  set res 1
	  break
	}
	  
	set currentvalue [set $v\($x\)]
	set storedvalue [$ip eval set [list $v\($x\)]]
	if {"$currentvalue"=="$storedvalue"} continue
	append reason "\nat least element `$x' of `$v' changed"
	::bras::lappendUnique trigger $v
	set res 1
	break
      }
      continue
    }

    set currentvalue [set $v]
    set storedvalue [$ip eval set [list $v]]
    if {"$currentvalue"!="$storedvalue"} {
      append reason "\n`$v' was changed"
      ::bras::lappendUnique trigger $v
      set res 1
    }
  }

  interp delete $ip
  return $res
}
########################################################################
proc ::bras::p::or {args} {
  set e [join $args ||]
  return [expr $e]
}
########################################################################
proc ::bras::p::notinitialized {names} {
  variable notInitialized

  installPredicate [list trigger deps] {}

  set res 0
  foreach name $names {
    ::bras::lappendUnique deps $name
    if {[info exist notInitialized($name)]} continue
    set notInitialized($name) 1
    ::bras::lappendUnique trigger $name
    append reason "\n`$name' not yet initialized"
    set res 1
  }
  return $res
}
########################################################################
#
# Test if any of the listed dependencies has a different md5sum than
# the one stored in the cache file $target.md5. If that file does not
# exist or if a md5sum is not listed in there, the target is also
# out-of-date.
#
proc ::bras::p::md5older {target inDeps} {
  installPredicate {trigger deps} {}

  ## Consider all dependencies in turn
  set results [::bras::consider $inDeps]

  ## potential @ in deps no longer needed after consider
  set inDeps [stripAt $inDeps]

  ## create array of new md5sums. Care must be taken to interprete the
  ## output of md5sum. It does not escape funny characters in
  ## filenames. In fact it cannot handle itself file names containing
  ## e.g. newlines.
  set text [eval exec md5sum $inDeps]
  foreach line [split $text \n] {
    set s [string range $line 0 31]
    set name [string range $line 34 end]
    set sum($name) $s
  }

  set md5 $target.md5

  if {[file exist $md5]} {
    set in [open $md5]
    array set old [read $in]
    close $in

    set res 0
    foreach d $inDeps {
      ::bras::lappendUnique deps $d
      if {[info exist old($d)] && $old($d)==$sum($d)} continue
      set res 1
      ::bras::lappendUnique trigger $d
      append reason "\nmd5sum of `$d' changed"
    }
  } else {
    set res 1
    append reason "\nmd5 cache `$md5' did not exist"
    foreach x $inDeps {::bras::lappendUnique deps $x}
  }

  if {!$res} {return 0}

  set out [open $md5 w]
  puts $out [array get sum]
  close $out

  return 1
}
