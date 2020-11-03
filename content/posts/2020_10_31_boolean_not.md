+++
title = "Boolean not"
date = "2020-10-31"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin"]
keywords = ["kotlin"]
description = ""
showFullContent = false
+++

[![](https://img.shields.io/badge/kotlinweekly-222-purple#badge)](https://mailchi.mp/kotlinweekly/gjz7gia1eq)

### Introduction

Boolean is one of the essential types in programming and probably one of the simplest because it has only two values: true and false. Boolean are usually used as flags for control flow, specifically, conditions. 
```kotlin
if (string.isEmpty()) {
	println("String is empty")
}
```

It is not much interesting in Boolean, but in Kotlin there is one thing which might be confusing if used - it is method `not()`.  

### Negate Boolean

If we look at declaration of Boolean class in Kotlin we'll see five methods, four of which are pretty obvious: `and`, `or`, `xor` and `compareTo`. And the fifth is `not`:
```kotlin
public class Boolean private constructor() : Comparable<Boolean> {
    /**
     * Returns the inverse of this boolean.
     */
    public operator fun not(): Boolean
```

So, each Boolean has function `not`, it looks like a normal function, so it is so tempting to call it?
```kotlin
if (string.isEmpty().not()) {
	println("String is not empty")
}
```
This is a valid code, it works correctly, it uses function declared in the `Boolean` class. Good enough? Not really. The readability of such a construction is weird because it is not fluent. We don't say "do something when string is empty not" (might be tempting to say that it is some German-style, though it is not entirely correct as well).

What other options do we have:
```kotlin
!string.isEmpty()
```
A pretty common way to negate boolean in programming languages. It doesn't feel that fluent as well. After all, we don't say "do something when not string is empty", though it feels anyway better because we at the beginning have information of negation and don't have to look through the whole line to see inversion.

```kotlin
string.isNotEmpty()
```
The best option - it says what it should: "do something when string is not empty". Cool. Though such extensions are not available for every case, and most likely you should not try to create such for all the cases.

Such methods are good for some low-level simple cases like `email.isNotValid()` when a negative form is primary business logic and used this way most of the time. But in general, it is better to name functions positively, so there is less confusion with negation. If you wish you can add a negative function, but it should be additional and not primary.  
Say, you have class `Connection` and you'd like to check whether the connection is established or not. You can create `Connection.isNotEstablished()` function, but if you do, you have to add `Connection.isEstablished()` as well, otherwise, it might be the situation, when you'd want to do something like: `!connection.isNotEstablished()`, which is for sure confusing.

### Why `not`?

As seen before the best option is to have information about negation in the middle of the name, then in the beginning, and only then at the end (this might be my personal preference, but I guess it is a common thing). Then why method `not()` was added to `Boolean` if one not meant to use it?

The main reason is that `not()` is not just a function - it is an [operator](https://kotlinlang.org/docs/reference/operator-overloading.html).  
```kotlin
public operator fun not(): Boolean
```

Operator functions are special functions that allow operator overloading. That means that adding `not` operator function to any class (even via extension function) allows you to use `!` syntax. Therefore `not` function allows you to put `!` before boolean value for negation.  

We can (though there is no need to) create our boolean implementation with implemented `not` operator function:
```kotlin
enum class MyBoolean {
    True,
    False
    ;
    operator fun not(): MyBoolean {
        return when (this) {
            True -> False
            False -> True
        }
    }
}
```
That will allow us to write:
```kotlin
val result = !MyBoolean.True
```

> Operator function `not` allows you to write `!` before expression. Function `not` is not something that is expected to be used directly, as it doesn't improve readability and has no other advantages.

### Where `not`?

There is one additional point where `not` can be used. The operator function is a function. And in Kotlin functions are first-class citizens. With higher-order functions, it is possible to pass a function to another function as an argument. It might be lambda or function reference. There is no difference in a bytecode, but upon agreement in a team, it might be possible to use one or another.

Say, we have a list of boolean values and we'd like to invert them. Doing it in a functional style we might do it with a lambda:
```kotlin
listOf(true, false, true)
	.map { !it }
```
Or with function reference:
```kotlin
listOf(true, false, true)
	.map(Boolean::not)
```

The result will be the same and I wouldn't say that one option is for sure better than the other. What I wanted to point out is that here we might use a reference to our `Boolean.not` method. This might be a useful option for that method usage.

> Writing code in a functional style it might be possible to use `Boolean.not` function as a reference to other methods.  

### Conclusion

I hope now we have a better understanding of why `not` function is declared in `Boolean` class, what "syntax sugar" it enables, and how it might be somewhat useful in functional programming.  
Besides this, I highly discourage direct usage of the `not` function in a normal control flow. Don't write `shouldApplyFilter.not()`. It doesn't provide you any readability gains and doesn't make your code better.

Happy coding.