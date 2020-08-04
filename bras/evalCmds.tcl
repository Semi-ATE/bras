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
########################################################################

########################################################################
#
# REMEMBER: This proc looks like it will work insides namespace
# ::bras. However when it is actually called, it will have been
# renamed to ::unknown. See invokeCmd for the details.
#
proc ::bras::unknown args {
  
  #puts "unknown: `$args'"

  set args [eval concat $args]
  #puts "would exec $args"

  ## Finally I decided to not rely on the original unknown, mainly
  ## because it does not cleanly report if it could executed the
  ## command or not. There is no difference in error return codes
  ## between `command not found' and `command found but returned
  ## error'. 
  set cmd [lindex $args 0]
  #puts "unknown for `$cmd'"
  if {![info exists ::auto_noload]} {
    global ::bras::unknown_pending
    if {[info exists ::bras::unknown_pending($cmd)]} {
      return -code error -errorinfo \
	  "self-referential `unknown' for `$cmd'"
    }
    set ::bras::unknown_pending($cmd) 1
    set code [catch {auto_load $cmd [uplevel 1 {namespace current}]} ok]
    unset ::bras::unknown_pending($cmd)
    if {$code} {
      return -code error -errorcode $::errorCode \
	   -errorinfo $::errorInfo
    }
    if {$ok} {
      ## We found and loaded the command
      set code [catch {uplevel 1 $args} msg]
      if {$code==1} {
	## a true error, strip the uplevel
	return -code error -errorcode $errorCode \
	    -errorinfo [fixErrorInfo 0 ""] $msg
      } else {
	return -code $code $msg
      }
    }
  }
  
  ## Arrive here if either auto_noload is set or the command could not
  ## be found by autoload. Note, we don't take care for auto_noexec.
  if {[catch {uplevel 1 exec <@stdin >@stdout $args} res]} {
    return -code error -errorinfo [::bras::fixErrorInfo 5 ""]
  }
  #eval exec <@stdin 2>@stderr >@stdout $args
}
########################################################################
proc ::bras::invokeCmd {rid Target pstack} {
  variable Rule
  variable Opts

  ## find the command to execute
  set cmd $Rule($rid,cmd)
  if {""=="$cmd"} {
    foreach {x y bexp} $Rule($rid,bexp) {
      lappend l $bexp
    }
    set l [join $l "|"]
    append msg \
	"bras(warning) in `[pwd]': no command found to " \
	"make `$Target' for `$l' (hope that's ok)"
    report warn $msg
    return
  }
  
  ## silently ignore commands which contain nothing but .relax.,
  ## possibly surrouned by whitespace.
  if {".relax."=="[string trim $cmd]"} return

  set Rule($rid,run) 1

  if {"[info command ::bras::unknown.orig]"=="::bras::unknown.orig"} {
    ## Someone called `consider' within a rule's command
    set haveUnknown 1
  } else {
    set haveUnknown 0
    rename ::unknown ::bras::unknown.orig
    rename ::bras::unknown ::unknown
  }

  
  ## Set up a namespace within which the command will be executed. The 
  ## main reason for this is that we want to have the variables
  ## targets, target, and those from $values to be unique for this
  ## command. They cannot be global because the command may call
  ## `consider', thereby invoking another command which also wants to
  ## have these variables.

  # The namespace in which the command is run is bound to the current
  # directory. We now set up some additional variables in that
  # namespace, namely target, targets and whatever was communicated by
  # the predicates in the namespace given by $pstack. Because a
  # command may call [consider] recursively, we have to backup and
  # later restore the variables we are going to overwrite.
  set currentDir [pwd]
  set dirns [dirns .]

  set ptails {}
  foreach x [info vars [set pstack]::*] {
    lappend ptails [namespace tail $x]
  }
  vbackup store [concat $ptails {target targets}] [set dirns]::

  namespace eval $dirns [list variable target $Target]
  namespace eval $dirns [list variable targets $Rule($rid,targ)]
  foreach ptail $ptails {
    catch {unset [set dirns]::$ptail}
    ## Sorry, currently only scalars are supported, mainly because
    ## $pstack should normally only contain scalars (see
    ## initialization of vars in installPredicate)
    set [set dirns]::$ptail [set [set pstack]::$ptail]
  }

  if {$Opts(-v)} {
    report -v "\# -- running command --"
    foreach name [info vars [set dirns]::*] {
      set tail [namespace tail $name]
      if {[string match reason $tail]} continue
      report -v "\# $tail = `[set $name]'"
    }
    report -v  [string trim $cmd \n]
  }
 
  if {!$Opts(-n)} {

    if {!$Opts(-v) && !$Opts(-d) && !$Opts(-s)} {
      report norm "\# making `$Target'"
    }

    ## 
    ## Run the command
    ##
    set result [catch {runscript $dirns $cmd}]
    cd $currentDir
    if {$result} {
      set emsg  "running command to make `$Target' in [pwd]"      
      return -code error -errorinfo [fixErrorInfo 2 $emsg]
    }
  }

  vrestore store

  if {!$haveUnknown} {
    rename ::unknown ::bras::unknown
    rename ::bras::unknown.orig ::unknown
  }

}
