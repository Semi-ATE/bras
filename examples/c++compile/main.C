
#include "other.h"
#include "main.h"


A::A(double d) {
  value = d;
  root = B(d);
}

ostream & operator<<(ostream &out, A& a)
{
  return out << a.getValue();
}
int
main(void)
{
  A a(2.0);
  cout << "root of " << a << " is approximately " 
       << a.getRoot() << "." << endl;
}


