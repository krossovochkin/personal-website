+++
title = "Kotlin useful but unfairly not mentioned features"
date = "2020-05-03"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin"]
keywords = []
description = "Exploring some good Kotlin features which are not so widely discussed"
showFullContent = false
+++

![[Source](https://unsplash.com/photos/5EoKAdyStik)](https://images.unsplash.com/photo-1519963759188-0e9264cd7992?ixlib=rb-1.2.1&auto=format&fit=crop&w=1357&q=80)*[Source](https://unsplash.com/photos/5EoKAdyStik)*

[![](https://img.shields.io/badge/original-proandroiddev-green#badge)](https://proandroiddev.com/kotlin-useful-but-unfairly-not-mentioned-features-25ec41ea0a87) [![](https://img.shields.io/badge/proandroiddevdigest-21-green#badge)](https://proandroiddev.com/proandroiddev-digest-21-60de024d6337)

## Introduction

Many of us first learned Kotlin after Java. Learning process was fairly simple because Kotlin has many similarities when at the same time improves development experience by fighting common pain points Java developer (especially on Java 6, which is common in Android world) has to encounter every day.

There are a bunch of articles about cool Kotlin features like immutability, handling nullability, smart-cast, data classes, and so forth. Yes, these features are great. Having to add a bunch of nullability annotations, final keywords, override equals/hashCode methods, create additional local variables after type checks — all of this adds unnecessary work that needs to be done all the time.

But also there are some differences between Kotlin and Java, which are not that significant, though useful. In this article, we’ll go through a few of them.

## Mutability of method parameter’s references

### Java

In Java references of parameters of a method are mutable by default.
That means that one can “replace” object on a given reference. To make it immutable one needs to add final keyword. It is a good practice to not replace such references, because it adds complexity to the code. That means that one should consider to always add final keyword to all parameters, which is definitely not that satisfying.

```kotlin
public class A {

    void foo(String param) {
        param = "hello";
        System.out.println(param);
    }

    void fooFinal(final String param) {
        param = "hello"; // Cannot assign a value to final variable 'param'
    }
}
```

For example, as shown in a snippet, we get compilation error only if we add final keyword.

### Kotlin

Unlike Java, in Kotlin all the params are by default immutable. And there is no way to make them mutable. This follows general Kotlin idiom of restricting all the access unless explicitly declared (so instead of putting final one usually add open where needed). In this particular case, there is no way to make this parameter neither var nor open. And anyway there is no need for that.

```kotlin
class A {

    fun foo(param: String) {
       param = "hello" // Val cannot be reassigned
    }
}
```

## Package private vs protected

Kotlin and Java have different approaches to visibility access. Though they are well documented, there is at least one interesting case, which is worth mentioning. And it is about protected keyword.

### Java

In Java there are four visibility modifiers: public, protected, package-private (default value, has no separate keyword), private.

The rules are straightforward:

* *private* is accessible from within a class

* *package-private* is accessible as private (withing a class) plus within a package

* *protected* is accessible as package-private plus for all child classes

* *public* is accessible from everywhere

Important thing here is to note that protected is accessible from the same package, not only by child classes.

So, if we, for example, we have a class with two methods: one protected and another package-private:

```kotlin
public class B {

    void packagePrivateMethod() {
        System.out.println("package private method called");
    }

    protected void protectedMethod() {
        System.out.println("protected method called");
    }
}
```

And we had class A in the same package, then that class A will be able to access both methods from class B:

```kotlin
public class A {

    void foo() {
        final B b = new B();
        b.packagePrivateMethod();
        b.protectedMethod();
    }
}
```

### Kotlin

In Kotlin there are different visibility modifiers: public (default, can be omitted), protected, internal, private.

* *public* is accessible from everywhere

* *protected* is accessible from child classes only

* *internal* is accessible from all the module (not only package, this is effectively “public in a module”)

* *private* is accessible from within a file/class

So, if we had a class similar to the previous example:

```kotlin
open class B {

    protected open fun protectedMethod() {
        println("protected method called")
    }

    internal open fun internalMethod() {
        println("internal method called")
    }
}
```

Then class A, while being in the same package, would not be able to access protected method:

```kotlin
class A {

    fun foo() {
        val b = B()

        b.internalMethod()
        b.protectedMethod() // Cannot access 'protectedMethod': it is protected in 'B'
    }
}
```

And I personally found that really useful. Package-private thing is clunky and feels somewhat outdated. Having protected to be accessible from the same package feels like encapsulation hole. Glad that Kotlin has a more strict approach for protected keyword.

But what if we would like to have something similar to package-private in Kotlin? In this case, we can consider putting two classes into same file with marking classes we’d like to hide as private. All the methods can remain public as class won’t be accessible from outside anyway:

```kotlin
class C : B() {

    fun fooC() {
        val d = D()
        d.fooD()
    }
}

private class D {

    fun fooD() {
        println("fooD called")
    }
}
```

One can read more on visibility modifiers in Kotlin [here](https://kotlinlang.org/docs/reference/visibility-modifiers.html).

## Final words

And that’s it for now. Hope this was interesting and useful. Kotlin is a great language and has a lot of cool features. But we can also look around and find also something else, not that impressive at first. Maybe there are some other features in Kotlin which are not highlighted that often in articles? Some features which save you time, make solutions clearer? Feel free to add your favorite features in comments.

Happy coding!