package javacompile;

class B {
  // Objects of type A contain elements of type B, so we have
  // dependency loop.
  A a;
  public B() {
    System.out.println("making object "+this);
  }

}
