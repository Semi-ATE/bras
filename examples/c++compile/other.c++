

#include "other.h"


B::B(double d) {
  value = sqrt(d);
}
B::B(void) {
  value = 0.0;
}

ostream & operator<<(ostream &out, B& b)
{
  return out << b.getValue();
}
