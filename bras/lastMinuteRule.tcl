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
##
## lastMinuteRule
##   tries to create a rule from Prule for targets that don't
##   have any explicit rule.
##
## Since we don't have any dependencies available here, only the
## target can select a rule. 
##
## If a rule matches the target, its GenDep-proc is called to generate
## the dependency. If that dependeny exists as a file, or if there is
## a real rule with that dependency as target, the rule is
## used.
##
## If no dependency file is found, all rule matching the target are
## considered again, this time calling lastMinuteRule recursively on
## the generated dependency.
##
## If a rule is (recursively) found, 1 is returned, otherwise 0.
##
## To prevent recursive looping, Prule($id,cure) is set to 1 for a
## rule which initiates a recursive search.
##
proc ::bras::lastMinuteRule {target} {
  variable Opts
  variable Indent
  variable Tinfo
  variable Rule
  variable Prule

  global brasSearched

  ## If this was called to only generate a command, target has
  ## already a rule
  if {[info exist Tinfo($target,[pwd],rule)]} {
    set reason "trying to find a command to make `$target'"
  } else {
    set reason "trying to derive a rule for target `$target'"
  }

  ## In the first step, we check if there is a rule which matches the
  ## target and generates a dependency which exists as a file
  set ruleID -1
  set activeRules {}
  set activeCandidates {}

  foreach id $Prule(all) {
    ## match the target
    if {![regexp "^$Prule($id,trexp)\$" $target]} continue

    ## don't check recursively active rules
    if {$Prule($id,cure)} {
      append reason \
	  "\n+ `$Prule($id,trexp)' <- `$Prule($id,gdep)' " \
	  "already active"
      continue
    }

    set which $Prule($id,gdep)

    ## If the dependency-generator is empty, which is not strictly
    ## disallowed, this is a way to make this target.
    if {"$which"==""} {
      set ruleID $id
      set dep {}
      append reason " ... success"
      break
    }

    ## generate the dependency with the pattern rule
    set dep [::bras::gendep::$which $target]

    append reason \
	"\n+ with `$dep' " \
	"derived from `$Prule($id,trexp)' <- `$Prule($id,gdep)'"
 
    ## Expand the dependency along the search path
    if {"[set t [searchDependency $dep]]"!=""} {
      ## good one, use it
      set ruleID $id
      set dep $t
      append reason "\n+ success, `$dep' exists or has explicit rule"
      break
    }

    lappend activeRules $id $dep
  }

  if {$Opts(-d) && ""!="$reason"} {dmsg $reason}

  ## If we did not find a rule-id yet, go recursive
  if {$ruleID==-1} {
    if {$Opts(-d) && [llength $activeRules]} {
      dmsg "+ no success, going recursive ($activeRules)"
    }
    foreach {id dep} $activeRules {
      set Prule($id,cure) 1
      append Indent "  "
      set ok [lastMinuteRule $dep]
      set Indent [string range $Indent 2 end]
      set Prule($id,cure) 0
      if {$ok} {
	set ruleID $id
	break
      }
    }
  }

  if {$ruleID==-1} {
    if {$Opts(-d)} {dmsg "nothing found"}
    return 0
  }

  ## If we arrive here, ruleID>=0 denotes the rule to use.  
  if {$Opts(-d)} {
    if {[info exist Tinfo($target,[pwd],rule)]} {
      set oldt $Rule($Tinfo($target,[pwd],rule),targ)
      foreach {t d b} $Rule($Tinfo($target,[pwd],rule),bexp) {
	lappend oldb $b
      }
      set msg {}; append msg \
	  "adding command to rule `$oldt'<-`$oldb'\n" \
	  "+ as well as expression `$Prule($id,bexp)'"
    } else {
      set msg "creating rule `$target' <- `$Prule($id,bexp)' "
    }
	
    dmsg $msg
  }

  ## Enter the rule into the database
  ::bras::enterRule $target $dep $Prule($id,bexp) $Prule($id,cmd)

  return 1
}
########################################################################
