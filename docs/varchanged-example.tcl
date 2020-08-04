##############################################################
# $Revision: 1.2 $, $Date: 2000/06/22 11:33:00 $
##############################################################
Always all {resultA resultB} {
}

Make resultB {
  [or [older $target inputB] [varchanged ::paramB $target.cache]]
} {
  echo $paramB >$target;		# a fake computation
  echo "set paramB $paramB" >$target.cache
}

Exist inputB {
  touch $target
}


Make resultA {
  [or [older $target inputA] [varchanged ::paramA $target.cache]]
} {
  echo $paramA >resultA;		# a fake computation
  echo "set paramA $paramA" >$target.cache
}

Exist inputA {
  touch $target
}

Make {::paramA ::paramB} {[notinitialized $targets]} {
  include params
}
##############################################################
