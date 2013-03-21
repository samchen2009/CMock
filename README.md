CMock
=====

Enhance the original CMock to support the following cases. 

```
   int* foo()
   {
      int *p = malloc(16);
      
      x = init_hw(p); //p is initilized here but invisible to the caller of foo.
      ...

      return p;
   }
        
   // Mock of init_hw()
   init_hw_ExpectAndReturn(int *p, int *p_val, int ret_val);

   // Test with mock.
   TEST(CMOCK_TEST, test_foo)
   {
      int x[4] = {10,20,30,40};
      ...
      init_hw_ExpectAndReturn(__IGNORE__, &x, 0); //__IGNORE__ to tell CMOCK to ignore it, but return the expect array x.
      ...  
      int *y = foo();
      EXPECT_EQ(y[0], 10);
   }
`
