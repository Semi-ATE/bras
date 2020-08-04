#ifndef _other_h_
#define _other_h_

#include <iostream.h>

class B {
  double value;
 public:
  B(double);
  B(void);
  double getValue(void) {return value;}
};

ostream & operator<<(ostream &out, B& b);

#endif
