#ifndef _main_h_
#define _main_h_

#include "other.h"
#include <iostream.h>

class A {
  double value;
  B root;

 public:
  A(double);
  double getValue(void) {return value;}
  B&  getRoot(void) {return root;}
};
ostream &operator<<(ostream &, A &);

#endif
