########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996-2000 Harald Kirsch
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
##
## This files contains 
## -- the declarations of all namespace-variables
## -- the procs which built up the database,
## -- other misc. procs
##
namespace eval ::bras {

  namespace eval gendep {
    ## This namespace will contain procs which map a target matching a 
    ## pattern rule into a useful dependency. See enterPatternRule for 
    ## more information.
  }

  ##### namespace variables

  ## base
  ##   Directory holding files sourced in by this script, as well as
  ##   files someone might find useful sourcing, in particular those
  ##   with suffix .rules. It is set in .version

  ## Opts
  ##   An array of options controlling bras.
  variable Opts
  set Opts(-d) 0;			# debug output
  set Opts(-de) 0;			# don't fix error messages
  set Opts(-k) 0;
  set Opts(-s) 0;			# silent operation
  set Opts(-v) 0;			# verbose operation
  set Opts(-n) 0;			# don't execute any commands
  set Opts(-ve) 0;			# show exec'ed commands

  ## Brasfile
  ##   Name of the rule file used, typically "brasfile" or "Brasfile" 
  variable Brasfile brasfile

  ## Targets
  ##   List of default targets to consider. It is set by the very
  ##   first rule entered into the database

  ## Indent
  ##   Current indent string used by debug messages
  variable Indent ""

  ## Tinfo
  ##   array holding information about targets. With <t> a target,
  ##   <d> its directory, the indices used are:
  ##   <t>,<d>,rule -- index into Rule denoting the rule for <t>,<d>
  ##   <t>,<d>,done -- set, if target was already considered.
  ##                   0: no need to make target
  ##                   1: target will be made
  ##                  -1: target needs to be made, but don't know how

  ## Rule
  ##   database of rules. With integer <i>, the indices are as follows
  ##   <i>,targ -- targets
  ##   <i>,deps -- dependencies
  ##   <i>,cmd  -- command
  ##   all      -- a list of all valid <i>s.
  variable Rule
  set Rule(all) {}

  ## Prule
  ##   database of pattern-rules. Pattern rules are stored and accessed in
  ##   the same order as they are introduced. Therefore each one gets a
  ##   number. The indices are used as follows (<i> denotes an integer):
  ##   all        -- list of all known pattern-rule IDs.
  ##   <i>,trexp  -- regular expression to match target 
  ##   <i>,gendep -- name of dependency generating funciton in
  ##                 ::bras::gendep 
  ##   <i>,cmd    -- command for target/dependency pair
  ##   <i>,cure   -- used by lastMinuteRule, set to 1 if CUrrently
  ##                 REcursively considered.
  variable Prule
  set Prule(all) {}

  ## nextID
  ##   a counter returning unique indices
  variable nextID 0

  ## Known
  ##   array with an element for all files sourced either by following
  ##   an @-target or by an explicit `include'. The directory-part of
  ##   the filename is always normalized by means of [pwd].
  ##

  ## Considering
  ##   is an array with targets as indices. The array element is set
  ##   while ::bras::Consider is working on a target to prevent
  ##   dependency loops

  ## Searchpath
  ## is an array indexed by [pwd] and contains for each directory the
  ## dependency search path. Elements are set by command `searchpath'.

  ## Searched
  ## is an array indexed by [pwd],<name> . If a certain index exists,
  ## <name> is the result of an expansion along brasSearchPath and it
  ## will not be expanded again.
  
  ## Namespace
  ## is an array indexed by [pwd] holding a unique namespace name like 
  ## ::ns123 used as an execution environment for the Brasfile from
  ## [pwd]. 
  
  ## Pstack
  ##   internal variable holding the name of the namespace used for
  ##   predicates to leave values like deps and trigger for the next
  ##   command to run (see installPredicate). The initial value is
  ##   never used except if someone feels like calling a predicate by
  ##   hand instead of via consider.
  variable Pstack ::
}

########################################################################
#
# generate a unique number
#
proc ::bras::nextID {} {
  variable nextID
  incr nextID
  return $nextID
}
########################################################################
#
# lappendUnique -- append an element to a list if it is not already in
# there. 
#
proc ::bras::lappendUnique {_list elem} {
  upvar $_list list
  
  if {-1==[lsearch -exact $list $elem]} {
    lappend list $elem
  }
}
########################################################################
#
# stores a backup copy of the variables listed in vars. The
# backup is stored in the array with the name $_store in the calling
# frame. The listed variables can be unset, scalar or array. Their
# state and content can be restored later with vrestore.
#
# The prefix $p is prefixed on every variable name in vars before
# it is used. A typical prefix can be a namespace, like ::X::. Note
# the trailing `::' necessary for correctly putting plain names into
# the namespace.
#
proc ::bras::vbackup {_store vars {p {}}} {
  upvar $_store store

  foreach varname $vars {
    if {[info exist store(T${p}$varname)]} {
      return -code error \
	  "a variable with name ${prefix}$varname is already stored"
    }
  }
  foreach varname $vars {
    upvar ${p}$varname var
    if {[array exist var]} {
      set store(T${p}$varname) a
      set store(V${p}$varname) [array get var]
    } elseif {[info exist var]} {
      set store(T${p}$varname) s
      set store(V${p}$varname) $var
    } else {
      set store(T${p}$varname) u
    }
  }
}
proc ::bras::vrestore {_store} {
  upvar $_store store

  foreach ele [array names store T*] {
    set varname [string range $ele 1 end]
    #if {![info exist store(T$varname)]} continue
    upvar $varname var
    catch {unset var}
    switch $store(T$varname) {
      a {
	array set var $store(V$varname)
      }
      s {
	set var $store(V$varname)
      }
      u {
	# just leave unset
      }
      * {
	error "this cannot happen"
      }
    }
  }
}
########################################################################
#
# concatUnique
#
proc ::bras::concatUnique {_list newElems} {
  upvar $_list list
  
  foreach elem $newElems {
    if {-1!=[lsearch -exact $list $elem]} continue
    lappend list $elem
  }
}
########################################################################
#
# strip optional @ from start of list elements
#
proc stripAt {l} {
  set result {}
  foreach x $l {
    if {[string match @* $x]} {
      lappend result [string range $x 1 end]
    } else {
      lappend result $x
    }
  }
  return $result
}
########################################################################
## 
## At several places we want to run a script on level #0 and in a
## certain namespace while cleanly messing with exceptions. This is an
## attempt to encapsulate the stuff
##
## This function either returns the result or an error exception. All
## other exceptions (break, return, continue) are caught. In fact,
## break is allowed.
##
proc ::bras::runscript {ns script} {
  set code [catch {uplevel \#0 [list namespace eval $ns $script]} res]

  ## Reminder from tcl.h
  # define TCL_OK          0
  # define TCL_ERROR       1
  # define TCL_RETURN      2
  # define TCL_BREAK       3
  # define TCL_CONTINUE    4       
  switch -- $code {
    0 {return $res}
    1 {#error
      return -code error -errorinfo [fixErrorInfo 8 ""]
    }
    2 {#return
      set msg "invocation of `return' not within a proc"
      return -code error -errorinfo $msg
    }
    3 {#break
      return $res
    }
    4 {#continue
      return -code error \
	  -errorinfo "invocation of `continue' not in loop context"
    }
    default {
      return -code error \
	  -errorinfo "unknown exception `$code' caught"
    }
  }
  error "This cannot happen"
}
########################################################################
##
## deletes $n lines from the bottom of $::errorInfo. This allows to
## remove stack entries generated by uplevel/namespace/catch
## etc. which where wrapped around the actually interesting command.
## Then, if $emsg is not the empty string,  "\n    while $emsg" is
## added to the result and returned.
##
## Typical use looks like:
##   return -code error -errorInfo [fixErrorInfo 5 "wurx went wrong"]
##
## Note: The deletion can effectively be switched of by option -de. 
#
proc ::bras::fixErrorInfo {n emsg} {
  global errorInfo
  variable Opts

  if {$Opts(-de)} {set n 0}
  set ei [split $errorInfo \n]
  set ei [join [lrange $ei 0 [expr {[llength $ei]-$n-1}]] \n]
  if {""!=$emsg} {append ei "\n    ($emsg)"}
  return $ei
}
########################################################################
#
# tcl (as of 8.0b1 and previous) does execute a `cd .' thereby
# spoiling its cache for pwd. Since bras happens to execute quite some
# `cd .', calling pwd afterwards, I trick it myself.
#
rename cd _cd
proc cd {dir} {
  if {"$dir"=="."} return
  _cd $dir
}
########################################################################
#
# Depending on command line options, this replaces the normal
# exec-command. Don't be fooled into thinking that this proc is called 
# within namespace ::bras. Option -ve renames it to ::exec.
#
proc ::bras::verboseExec args {
  ::bras::report -ve $args
  return [eval ::bras::exec_orig $args]
}
########################################################################
##
## prints "$text" to either stdout or stderr, depending on
## type. Feel free to redefine this proc, if you want the output to go
## somewhere else.
## The following types are used:
## "warn"  -- reminders for the user about dubious idioms
## "-d", "-v", "-ve" -- output requested by the respective options
## "norm" -- output produces without any option set
##
proc ::bras::report {type text {newline 1} } {
  switch -exact -- $type {
    warn {
      set out stderr
    }
    norm -
    -d -
    -v -
    -ve {
      set out stdout
    }
    default {
      return -code error -errorinfo "wrong type `$type'"
    }
  }
  if {$newline} {
    puts $out $text
  } else {
    puts -nonewline $out $text
  }
}    
########################################################################
##
## followTarget
##  
## Handle all what is necessary to follow an @-target to its
## home. In particular:
## - change directory
## - read brasfile
## And do all this with the necessary error handling.  
##
## The given target *must* start with `@'!
## RETURN
##   The current directory (before cd) is returned.
##
proc ::bras::followTarget {target} {
  #puts "followTarget $target"

  set oldpwd [pwd]
  
  ## The `@' in front shall not confuse [file dir]
  set dir "@[file dir [string range $target 1 end]]"

  include $dir
  cd [string range $dir 1 end]
  return $oldpwd
}
########################################################################
##
## called by default gendep-functions. It replaces the suffix of a
## file's name with `gendepName', which is a suffix starting with a
## dot in most common cases.
##
proc ::bras::defaultGendep {target gendepName} {
  set rootname [file rootname $target]
  return "${rootname}$gendepName"
}
########################################################################
##
## enterPatternRule
##   Declare a pattern-rule.
##
## PARAMETER
## trexp --
##   regular expression to match a target
## gendep --
##   name of a proc in ::bras::gendep which can map a target which
##   matches trexp into a useful dependency. It must have exactly one
##   paramter which will be the matching target, when it is called.
## bexp --
##   boolean expression to use in a rule derived from this pattern
##   rule 
## cmd --
#    command to attach to a rule derived from this pattern rule
proc ::bras::enterPatternRule {trexp gendep bexp cmd} {
  variable Prule

  ## Emtpy commands are rather useless here
  if {0==[string length $cmd]} {
    return -code error \
	"empty commands are not allowed in pattern rules"
  }

  ## enter the rule
  set id [nextID]
  set Prule(all) [concat $id $Prule(all)]
  set Prule($id,trexp) $trexp
  set Prule($id,gdep)  $gendep
  set Prule($id,bexp)  $bexp
  set Prule($id,cmd)   $cmd
  set Prule($id,cure)  0

  #puts ">>$gendep"
  ## create pattern replacement commands for the dependency
  if { 0==[llength [info commands ::bras::gendep::$gendep]] } {
#     set body [format {
#       set rootname [file rootname $target]
#       return [join [list $rootname "%s"] {}]
#     } $gendep]
    proc ::bras::gendep::$gendep {target} \
	"return \[::bras::defaultGendep \$target $gendep\]"
  }
}
########################################################################
##
## ::bras::enterRule
##    declare a rule
## 
## targets -- list of targets
##    gdep -- a dependency generated in a pattern rule
##    bexp -- a boolean expression 
##     cmd -- a script to generate the target(s)
##
proc ::bras::enterRule {targets gdep bexp {cmd {}} } {
  variable Targets
  variable Rule
  variable Tinfo

  if {[llength $targets]==0} {
    return -code error "The target list may not be empty"
  }

  #puts "enterRule: {$type} {$targets} {$deps} {$cmd} {$bexp}"

  ## if this is the very first explicit rule seen, and if no target was
  ## specified on the command line, this is the default target-list.
  ## It suffices to put just the first element into Targets,
  ## because all of them are made by the command of this rule.
  ## We also record the current directory, because the brasfile may
  ## contain cd-commands.
  if {![info exist Targets]} {
    set Targets [list [pwd] [lindex $targets 0]]
  }

  ## Although more than one `Make'-command for a target is allowed in
  ## a brasfile, all of those are pooled into one rule
  ## internally. Consequently, if a `Make'-command specifies more than
  ## one target which has already a rule associated, they must all
  ## have that same rule.
  set rid {}
  set tmp {}
  set err 0
  foreach t $targets {
    if {[info exist Tinfo($t,[pwd],rule)]} {
      if {"$rid"==""} {
	set rid $Tinfo($t,[pwd],rule)
      } elseif {$rid!=$Tinfo($t,[pwd],rule)} {
	set err 1
      }
      lappend tmp $t
    }
  }
  if {$err} {
    append msg "The targets `$tmp' all have already a rule, but "\
	"these rules are not all same."
    return -code error -errorinfo $msg
  }

  ## If rid is not set now, initialize a rule 
  if {[llength $rid]==0} {
    set rid [nextID]
    lappend Rule(all) $rid
    set Rule($rid,targ) {}
    set Rule($rid,bexp) {}
    set Rule($rid,cmd) {}
  }

  ## We are sure now, all targets either don't have a rule yet or they 
  ## all have the same.
  foreach t $targets {
    set Tinfo($t,[pwd],rule) $rid
  }

  ## Add the new information into Rule($rid,...)
  concatUnique Rule($rid,targ) $targets
  if {"$cmd"!=""} {
    ## It is no good to have more than one command for a target.
    if {""!="$Rule($rid,cmd)" && "$Rule($rid,cmd)"!="$cmd"} {
      set msg {}; append msg \
	  "bras(warning) in `[pwd]': overriding command " \
	  "`$Rule($rid,cmd)' for target `$targets'" \
	  " with `$cmd'"
      report warn $msg
    }
    set Rule($rid,cmd) $cmd

    ## If this rule has a command, we want its boolean expression to
    ## be the first in the list so that it enters its dependencies it
    ## has in front of the dependency list so that [lindex $deps 0] is
    ## equivalent to make's $< .
    set Rule($rid,bexp) \
	[concat [list $targets $gdep $bexp] $Rule($rid,bexp)]
  } else {
    lappend Rule($rid,bexp) $targets $gdep $bexp
  }
  set Rule($rid,run) 0
}
########################################################################
