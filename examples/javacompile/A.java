package javacompile;

class A {
  // This class uses B which itself uses A again, thereby creating a
  // dependency loop.

  B b;

  public A() {
    System.out.println("making object "+this);
    b = new B();
  }

  public static void main(String argv[]) 
  {
    A a = new A();
  }
}
