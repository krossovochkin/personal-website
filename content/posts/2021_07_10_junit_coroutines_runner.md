+++
title = "JUnit Coroutines Runner"
date = "2021-07-10"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin", "coroutines", "test"]
keywords = ["kotlin", "coroutines", "test", "junit"]
description = ""
showFullContent = false
+++

### Introduction

Recently while writing tests for kotlin code with coroutines I found one annoying thing: almost all the tests start with `runBlockingTest`. Typing the same stuff repeatedly is something we can't accept! So, I decided to think about how to improve this.

> Disclaimer. Yes, this is an example of how to spend few hours to optimize some task that requires you 2 seconds to complete each time. Even on a scale of hundreds of usages such optimization most likely won't pay your time back. But it is always fun to do some weird things even if you understand that they are stupid.

### Basic test

Let's get to the very beginning: we have some function that does some important work and that is suspendable. For simplicity, the function will return some constant value after some delay.

```kotlin
suspend fun calculate(): Int {
    delay(100L)
    return 1
}
```

The next step is to cover this function with tests. We'll have two tests: one for positive and one for negative cases. This can be considered simple mutation testing. In general, we don't need `testFail`, but for this specific case, it might be useful to verify that we get green tests only if everything is fine, and if something is wrong that we get red tests as expected.

```kotlin
class MainTest {

    @Test
    fun testSuccess() {
        runBlockingTest {
            check(calculate() == 1)
        }
    }

    @Test(expected = IllegalStateException::class)
    fun testFail() {
        runBlockingTest {
            check(calculate() == 2)
        }
    }
}
```

This looks a bit wordy and has one level of nesting - not cool. We can work around that by using the body as an expression. Now it will be much better.
```kotlin
class MainTest {

    @Test
    fun testSuccess() = runBlockingTest {
        check(calculate() == 1)
    }

    @Test(expected = IllegalStateException::class)
    fun testFail() = runBlockingTest {
        check(calculate() == 2)
    }
}
```

### Custom JUnit Rule

Our first attempt will be to create custom JUnit rule that will apply `runBlockingTest` automatically for each of our test methods. This will be our rule:

```kotlin
class CoroutinesTestRule : TestRule {
    override fun apply(base: Statement, description: Description): Statement {
        return object : Statement() {
            override fun evaluate() {
                runBlockingTest { base.evaluate() }
            }
        }
    }
}
```

Now we can drop `runBlockingTest` from the test method. But if we do - we face an error:

```kotlin
@Test
fun testSuccess() {
    check(calculate() == 1) // Suspend function 'calculate' should be called only from a coroutine or another suspend function
}
```

Yes, to call our function under test we need coroutine scope. Previously it was created by `runBlockingTest` and now it is missing. What can we do? Look at the second part of the error message: "or another suspend function". Let's make our test methods `suspend` and apply our custom rule:

```kotlin
class MainTest {

    @get:Rule
    val rule = CoroutinesTestRule()

    @Test
    suspend fun testSuccess() {
        check(calculate() == 1)
    }
}
```

Nice!  

But after trying to run tests we face an error:

```
Method testSuccess() should be void
java.lang.Exception: Method testSuccess() should be void
  at org.junit.runners.model.FrameworkMethod.validatePublicVoid(FrameworkMethod.java:99)
  at org.junit.runners.model.FrameworkMethod.validatePublicVoidNoArg(FrameworkMethod.java:74)
  at org.junit.runners.ParentRunner.validatePublicVoidNoArgMethods(ParentRunner.java:155)
  at org.junit.runners.BlockJUnit4ClassRunner.validateTestMethods(BlockJUnit4ClassRunner.java:208)
```

But it looks like our test method doesn't have return type declared, so it should be `Unit` and it is the same as `Void`?  
Actually, no. By the way `Unit` != `Void`, but in this case, it doesn't matter much. What happens is that after compiling to Java bytecode test method signature will look like:

```kotlin
public Object calculate(Continuation<Int> continuation)
```

Because of marking method `suspend` kotlin compiler adds continuation param and `Object` return type. That `Object` is used by an internal implementation to e.g. keep track of the internal state.

### Diving looking for root cause

Something went wrong: we tried to run tests, but we can't because of some internal validation, and we need to find a way to suppress some validation checks.  
Looking at the stack trace we find the place where validation checks happen - `FrameworkMethod`:
```java
/**
 * Adds to {@code errors} if this method:
 * <ul>
 * <li>is not public, or
 * <li>returns something other than void, or
 * <li>is static (given {@code isStatic is false}), or
 * <li>is not static (given {@code isStatic is true}).
 * </ul>
 */
public void validatePublicVoid(boolean isStatic, List<Throwable> errors) {
    if (isStatic() != isStatic) {
        String state = isStatic ? "should" : "should not";
        errors.add(new Exception("Method " + method.getName() + "() " + state + " be static"));
    }
    if (!isPublic()) {
        errors.add(new Exception("Method " + method.getName() + "() should be public"));
    }
    if (method.getReturnType() != Void.TYPE) {
        errors.add(new Exception("Method " + method.getName() + "() should be void"));
    }
}
```

What we need is to be able to override the behavior of that method. Looking more at that class we can find the `validatePublicVoidNoArg` method. We immediately notice that we should also suppress the validation check that verifies that the method has no arguments. Yes, in general, the test method doesn't have arguments, but after adding `suspend` kotlin compiler will add the `continuation` argument automatically. So, we need to suppress that check as well.

The easiest way to do that is to wrap `FrameworkMethod` into our class, which we'll call `SuspendFrameworkMethod`, and override the method with a new implementation:

```kotlin
internal class SuspendFrameworkMethod(val frameworkMethod: FrameworkMethod) : FrameworkMethod(frameworkMethod.method) {

    override fun validatePublicVoidNoArg(isStatic: Boolean, errors: MutableList<Throwable>) {
        if (isStatic() != isStatic) {
            val state = if (isStatic) "should" else "should not"
            errors.add(Exception("Method " + method.name + "() " + state + " be static"))
        }
        if (!isPublic) {
            errors.add(Exception("Method " + method.name + "() should be public"))
        }
        // skip check for void
        // skip check for no arg
    }
}
```

We still keep checks that method is public and not static though, as we want to keep these checks.

After creating a wrapper around `FrameworkMethod` we should hook it somehow.

### Custom JUnit Runner

It turns out that the place where we should add a wrapper is a test runner. Test runner runs tests. Simple as that.  
We write our custom runner called `CoroutinesTestRunner` overriding some methods, so that wrapper `SuspendFrameworkMethod` will be used calling our overridden checks:

```kotlin
class CoroutinesTestRunner(klass: Class<*>) : BlockJUnit4ClassRunner(klass) {

    override fun getChildren(): MutableList<FrameworkMethod> {
        return super.getChildren().map(::SuspendFrameworkMethod).toMutableList()
    }

    override fun validatePublicVoidNoArgMethods(
        annotation: Class<out Annotation>,
        isStatic: Boolean,
        errors: MutableList<Throwable>
    ) {
        // skip check no arg
        testClass.getAnnotatedMethods(annotation)
            .forEach { SuspendFrameworkMethod(it).validatePublicVoidNoArg(isStatic, errors) }
    }
}
```

Now we need to instruct JUnit to use our custom test runner to run our tests:

```kotlin
@RunWith(CoroutinesTestRunner::class)
class MainTest {

    @Test
    suspend fun testSuccess() {
        check(calculate() == 1)
    }

    @Test(expected = IllegalStateException::class)
    suspend fun testFail() {
        check(calculate() == 2)
    }
}
```

We run tests and again see the issue:

```
wrong number of arguments
java.lang.IllegalArgumentException: wrong number of arguments
  at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
  at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
  at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
  at java.base/java.lang.reflect.Method.invoke(Method.java:566)
  at org.junit.runners.model.FrameworkMethod$1.runReflectiveCall(FrameworkMethod.java:50)
  at org.junit.internal.runners.model.ReflectiveCallable.run(ReflectiveCallable.java:12)
  at org.junit.runners.model.FrameworkMethod.invokeExplosively(FrameworkMethod.java:47)
```

Meh, we need to do something with that as well.

### Reflection

JUnit uses reflection under the hood to run tests. Using reflection JUnit collects all the methods marked with `@Test` annotation and invokes them proving target and params.
We can see how it is done by looking at the `FrameworkMethod#invokeExplosively` method:

```java
/**
 * Returns the result of invoking this method on {@code target} with
 * parameters {@code params}. {@link InvocationTargetException}s thrown are
 * unwrapped, and their causes rethrown.
 */
public Object invokeExplosively(final Object target, final Object... params)
        throws Throwable {
    return new ReflectiveCallable() {
        @Override
        protected Object runReflectiveCall() throws Throwable {
            return method.invoke(target, params);
        }
    }.run();
}
```

We have the wrong number of arguments because we need to provide `continuation` as a parameter. An attentive reader could spot that we haven't added `runBlockingTest` yet.  
Let's do that in our `SuspendFrameworkMethod`:


```kotlin
@Throws(Throwable::class)
override fun invokeExplosively(target: Any?, vararg params: Any?): Any? {
    return object : ReflectiveCallable() {
        @Throws(Throwable::class)
        override fun runReflectiveCall(): Any {
            return runBlockingTest {
                suspendCoroutine<Unit> { continuation ->
                    frameworkMethod.invokeExplosively(target, continuation, *params)
                }
            }
        }
    }.run()
}
```

We wrap the `invokeExplosively` method with `runBlockingTest` and create a separate `suspendCoroutine` to access continuation.

We then run our tests and they are green!  
Awesome!

### Result

Now, with `CoroutineTestRunner` we can write our tests like this:

```kotlin
@RunWith(CoroutinesTestRunner::class)
class MainTest {

    @Test
    suspend fun testSuccess() {
        check(calculate() == 1)
    }

    @Test(expected = IllegalStateException::class)
    suspend fun testFail() {
        check(calculate() == 2)
    }
}
```

No more explicit `runBlockingTest`!

Is it good to use this approach though?  

NO.

Please, don't try to do anything like this in a real project. The current implementation has many disadvantages:
* We got rid of `runBlockingTest` but now we should add to each test `suspend`. That is a very little gain in characters to be saved
* `runBlockingTest` not only provides the scope - it provides a test scope that has additional test methods like `advanceTimeBy`. And we don't have that test scope anymore. Trying to pass it to the method requires additional changes in our `SuspendFrameworkMethod` and the resulting test methods will look like this:

```kotlin
@Test
suspend fun test(scope: TestCorotinesScope) {
    // ...
}
```

This is even more verbose than using `runBlockingTest`.  

So, after all, have to admit that this "optimization" actually doesn't make the test methods look better. Still, the preferred way to write tests is:
```kotlin
@Test
fun test() = runBlockingTest {
    // ...
}
```

But at least we had some fun and probably understand better the internals of the JUnit framework.

Happy coding!