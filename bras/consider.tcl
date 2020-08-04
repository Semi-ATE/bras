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
# $Revision: 1.22 $, $Date: 2002/02/24 10:15:07 $
########################################################################

########################################################################
##
## ::bras::dmsg
##
## prints a multiline message on stdout with current indentation
##
proc ::bras::dmsg {msg} {
  variable Indent
  regsub -all "\n" $msg "\n\#$Indent" msg
  report -d "\#$Indent$msg"
}
########################################################################
#
# If a non-empty string is returned, it is an expanded dependency
# about which something is known, i.e. it either already exists as a
# file or there is an explicit rule which describes how to make it. 
#
proc ::bras::searchDependency {dep} {
  variable Searchpath
  variable Searched
  variable Tinfo

  ## Don't expand @-names
  if {[string match @* $dep]} {
    return $dep
  }

  ## Don't search for targets which are the result of a search already.
  if {[info exist Searched([pwd],$dep)]} {
    return $dep
  }

  ## Don't expand non-relative paths
  set ptype [file pathtype $dep]
  if {"$ptype"!="relative"} {
    if {[file exist $dep] || [info exist Tinfo($dep,[pwd],rule)]} {
      set Searched([pwd],$dep) 1
      return $dep
    } else {
      return {}
    }
  }

  ## If there is no searchpath, assume .
  if {[info exist Searchpath([pwd])]} { 
    set path $Searchpath([pwd])
  } else {
    set path [list {}]
  }

  ## Try to find the dep as a file along the searchpath
  foreach x $path {
    if {"$x"=="."} {set x {}}
    set t [file join $x $dep]
    ## Now it may be an @-target. We must test if the name without
    ## leading @ exists, but then we return the name with @.
    if {[string match @* $t]} {
      set y [string range $t 1 end]
    } else {
      set y $t
    }
    if {[file exist $y]} {
      set Searched([pwd],$t) 1
      return $t
    }
  }

  ## Try to find an explicit rule for the dependency along the
  ## searchpath 
  foreach x $path {
    if {"$x"=="."} {set x {}}
    set t [file join $x $dep]
    ## Now it may be an @-target
    if {[string match @* $t]} {
      set keepPWD [followTarget $t]
      set tail [file tail $t]
      set found [info exist Tinfo($tail,[pwd],rule)]
      cd $keepPWD
    } else {
      set found [info exist Tinfo($t,[pwd],rule)]
    }
    if {$found} {
      set Searched([pwd],$t) 1
      return $t
    }
  }

  return {}
}
########################################################################
proc ::bras::leaveDir {newDir} {
  variable Opts

  if {"$newDir"=="."} return

  if {!$Opts(-s) && !$Opts(-d)} {
    report norm "cd $newDir"
  }
  cd $newDir
}
########################################################################
proc ::bras::touchOtherTargets {rid target res} {
  variable Rule
  variable Tinfo
  set also ""
  foreach t $Rule($rid,targ) {
    if {"$target"!="$t"} {
      lappend also "'$t'"
      set Tinfo($t,[pwd],done) $res
    }
  }
  return $also
}
########################################################################
##
## Cleanup stuff necessary before considerOne can return.
##
proc ::bras::cleanupForConsider {target keepPWD res} {
  variable Tinfo 
  variable Considering

  catch {unset Considering($target,[pwd])}  
  set Tinfo($target,[pwd],done) $res
  leaveDir $keepPWD
}
########################################################################
##
## Check whether the target needs to be rebuilt.
##
## RETURN
##  0: no need to make target
##  1: target was just made
## -1: don't know how to make that target
## 
## How a target is considered:
## Suppose target t in directory d is considered. The the following
## steps are performed:
## o Run the target's rule mentioned in Tinfo($t,$d,rule)
## Three cases are possible:
##   1) The rule returns -1, i.e. the target should be made, but
##      some of its dependencies are not available or cannot be
##      made. In this case, -1 is returned.
##   2) The rule returns 0, i.e. the target is up-to-date.
##      Then 0 is returned.
##   3) The rule returns 1, i.e. the target must be made. Then the
##      steps described below are executed.
proc ::bras::considerOne {target} {
  variable Opts
  variable Tinfo
  variable Rule
  variable Considering
  variable Indent
  variable Pstack

  ## change dir, if target starts with `@'. Save current dir in
  ## keepPWD.
  set keepPWD .
  if {[string match @* $target]} {
    set keepPWD [followTarget $target]
    set target [file tail [string range $target 1 end]]
    if {"$keepPWD"=="[pwd]"} {
      set keepPWD .
    } else {
      if {!$Opts(-s) && !$Opts(-d)} {
	report norm "cd [pwd]"
      }
    }
  }

  ## check, if this target was handled already along another line of
  ## reasoning 
  if {[info exist Tinfo($target,[pwd],done)]} {
    if {$Opts(-d)} {
      dmsg "have seen `$target' in `[pwd]' already"
    }
    set pwd [pwd]
    leaveDir $keepPWD
    return $Tinfo($target,$pwd,done)
  }

  ## check for dependeny loops
  if {[info exist Considering($target,[pwd])]} {
    set msg "dependency loop detected for `$target' in `[pwd]'" 
    leaveDir $keepPWD
    return -code error -errorinfo $msg
  }

  ## Mark the target as being under consideration to prevent
  ## dependency loops.
  set Considering($target,[pwd]) 1

  ## describe line of reasoning
  if {$Opts(-d)} {dmsg "considering `$target' in `[pwd]'" }

  ## Prepare for further messages
  append Indent "  "

  ## handle targets without rule
  if {![info exist Tinfo($target,[pwd],rule)]} {
    lastMinuteRule $target

    ## Check if there is still no rule available
    if {![info exist Tinfo($target,[pwd],rule)]} {
      set Indent [string range $Indent 2 end]
      if {[file exist $target]} {
	## The target exists as a file, this is ok.
	if {$Opts(-d)} {
	  dmsg "`$target' is ok, file exists and has no rule"
	}
	cleanupForConsider $target $keepPWD 0
	return 0
      } else {
	## The file does not exist, so we decide it must be remade, but
	## we don't know how.
	if {$Opts(-d)} {
	  dmsg "don't know how to make, no rule and file does not exist"
	}
	cleanupForConsider $target $keepPWD -1
	return -1
      }
    }
  } else {
    ## Try to find a command, if there is none. Again, lastMinuteRule
    ## is called. This might even add a depenency to the front of the
    ## dependency list, which is quite right if the command found uses
    ## [lindex $deps 0].
    set rid $Tinfo($target,[pwd],rule)
    if {![string length $Rule($rid,cmd)]} {
      lastMinuteRule $target
    }
  }

  ##
  ## Find the target's rule.
  ##
  set rid $Tinfo($target,[pwd],rule) 


  ## Set up a namespace in which predicates, by means of
  ## installPredicate, will leave values (like trigger, deps) later
  ## made available to the command to be run. 
  set keptPstack $Pstack
  set Pstack ::bras::ns[nextID]
  namespace eval $Pstack {}

  ##
  ## Call the target's rule. [catch] is used because it is assumed
  ## that a rule calls ::bras::listConsider for the dependency list,
  ## which may return an error. 
  ##
  if {[catch [list ::bras::checkMake $rid $target] res]} {
    set Indent [string range $Indent 2 end]
    cleanupForConsider $target $keepPWD 0
    return -code error [fixErrorInfo 4 ""]
  }
  set Indent [string range $Indent 2 end]
  
  ## If target was up-to-date already, return (almost) immediately
  if {$res==0} {
    set also [touchOtherTargets $rid $target 0]
    if {$Opts(-d)} {
      dmsg "`$target' in `[pwd]' is up-to-date"
      if {[llength $also]} {
	dmsg "same holds for: [join $also {, }]"
      }
    }
    namespace delete $Pstack; set Pstack $keptPstack
    cleanupForConsider $target $keepPWD 0
    return 0
  }
  if {$res!=1} {return -code error "this should not happen"}

  ## if someone wants to call consider explicitly for the same target
  ## in the command of the rule, let him/her do so
  unset Considering($target,[pwd])
  
  ## announce running command
  if {$Opts(-d)} {
    if {![info exist [set Pstack]::reason]} {
      set reason "\n    (no reason given by condition)"
    } else {
      regsub -all "\n" [set [set Pstack]::reason] "\n    " reason
    }
    dmsg "making `$target' in `[pwd]' because$reason"
  }
  catch {unset [set Pstack]::reason}

  ## now run the stuff
  if {[catch {invokeCmd $rid $target $Pstack}]} {
    namespace delete $Pstack; set Pstack $keptPstack
    return -code error -errorinfo [fixErrorInfo 2 ""]
  }

  ## clean up a bit
  namespace delete $Pstack; set Pstack $keptPstack

  
  ## All other targets of this rule are assumed to be made now. Mark
  ## them accordingly and filter them out for a message
  set also [touchOtherTargets $rid $target 1]
  if {"$also"!="" && $Opts(-d)} {
    dmsg "same command makes: [join $also {, }]"
  }

  ## finish up and return
  #returnFromConsider $target $keepPWD 1
  cleanupForConsider $target $keepPWD 1
  return 1
}
