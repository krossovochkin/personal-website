+++
title = "Mocking Matchers API"
date = "2021-09-11"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["test"]
keywords = ["test", "junit", "mock", "mockito", "mockk"]
description = "Diving into Matchers API of various mocking libraries such as Mockito, mockito-kotlin, mockk"
showFullContent = false
+++

[![](https://img.shields.io/badge/androidweekly-483-blue#badge)](https://androidweekly.net/issues/issue-483) [![](https://img.shields.io/badge/kotlinweekly-268-purple#badge)](https://mailchi.mp/kotlinweekly/kotlin-weekly-268)

### Introduction

Recently, I faced an issue that in the first place I found weird. I even considered that the behavior is generally incorrect. Diving deeper I got few insights on the problem - and this is what I'd like to share with you.  
This is a story about the interesting behavior of mocking library and the difficulties of defining API surface for a library.  

> **Disclaimer**  
In general, I favor fakes over mocks. In other words, instead of trying to implement emulation of the behavior as a mock - it is generally easier and safer to implement a simple fake object with all the logic (that can be covered with tests if needed).  
Though that doesn't mean that one should not use mocks at all. In my opinion, it depends on the use case. If you would like to stub some values - then going with a fake object sounds like a wise choice, but for verifying behavior (e.g. whether there were interactions with a particular object or not) using mocking libraries might provide a fast solution.  
Needed to say that even when trying to verify interactions one can use fake objects wrapped with spies.  
Regardless, this article is not about what approach is better, it is more about the behavior of mocking libraries and how their API is designed.

Let's imagine that we're writing some tests and we'd like to define the behavior of some `Product` object to return the correct price depending on `discountId`. Also, let's assume on a project we're using [mockito-kotlin](https://github.com/mockito/mockito-kotlin) as a mocking library.  
When doing checkout user can provide some `discountId` that will apply some price reduction, or there might be no discount - in this case, we'll pass `null`.  
The mocking might look like this:

```kotlin
val product = mock<Product> {
    on { calculatePrice(null) } doReturn Price(10)
    on { calculatePrice(discountId1) } doReturn Price(5)
    on { calculatePrice(discountId2) } doReturn Price(4)
}
```
Everything is fine with this code, but there is quite a lot of duplication. In case we'd like to register more discount IDs we might tend to copy-paste previous lines and incorrectly change some values. Let's rewrite it a bit to make it more generic:

```kotlin
val product = mock<Product> {
    on { calculatePrice(any())} doAnswer  { i ->
        when (val discountId = i.getArgument<String>(0)) {
            null -> Price(10)
            discountId1 -> Price(5)
            discountId2 -> Price(4)
            else -> throw UnsupportedOperationException("$discountId is not mocked")
        }
    }
}
```
This uses more lines, but we've made the code more flexible and removed duplication.

> As a side note, doing something like this should already be as a signal that instead of writing complex mock we'd better stick to some fake product object to contain all that logic.

We've set up the mock, but if we run something like:
```kotlin
@Test
fun test() {
    assertEquals(Price(10), product.calculatePrice(null))
}
```
We'll get an exception:
```
expected:<Price(value=10)> but was:<null>
Expected :Price(value=10)
Actual   :null
```
But why so? We've mocked the product to return some value for any input argument, but when passing `null` we got `null` as if we've not mocked such a case.  
The reason behind that is that mockito-kotlin has separate methods for checking non-nullable and nullable inputs. So, in this case, the correct version would be to use `anyOrNull` instead of `any`. In that case, everything will work as expected.  
And this is the exact thing that makes me feel weird: doesn't `any()` mean any input? Why `null` is not considered as any?

And even more weird: if instead of `org.mockito.kotlin.any` we'll use `org.mockito.ArgumentMatchers.any` (from original Mockito library) - test will pass! Feels like mockito-kotlin (which is a kotlin wrapper over Mockito) doesn't behave the same way as Mockito. I've been using Mockito for quite a while, so I didn't expect such changes.  

From here let's dive into argument matchers of various mocking libraries: Mockito, mockito-kotlin, and mockk.

### Mockito

Mockito has a bunch of matchers that check for type and handle nullability: `any()`, `any(Class<T> type)`, `isA(Class<T> type)`, `isNull()`, `notNull()`, `isNotNull()`, `nullable(Class<T> type)`. Wow, there are a lot. Let's find out the differences.

- `any()` - it basically has no check. Any input is considered a match.
- `any(Class<T> type)` - checks that input is instance of type `T`. It supports both children of type `T` and varargs.
- `isA(Class<T> type)` - same as `any(Class<T> type)` but it doesn't support varargs.
- `isNull()` - checks whether input equals to `null` or not, simple as that.
- `notNull()` - opposite to `isNull()` - it checks whether value is not equal to `null`
- `isNotNull()` - this is an alias to `notNull()`
- `nullable(Class<T> type)` - this is an alias to having `isNull()` or `isA(Class<T> type)`

This looks pretty straightforward as for any case we need we can choose the corresponding matcher.  
One can look at the implementation of each method in more detail [here](https://github.com/mockito/mockito/blob/main/src/main/java/org/mockito/ArgumentMatchers.java).

### Mockito-Kotlin

Mockito-kotlin is a wrapper around Mockito, so we can expect it to match the same methods in Mockito. Among available matchers we can find: `any()`, `anyOrNull()`, `anyVararg()`, `isA()`, `isNull()`, `notNull()`, `isNotNull()`.

- `any()` - immediately we face a difference: this method uses under the hood `any(Class<T> type)` from Mockito. Interesting.
- `anyOrNull()` - this instead uses `any()`
- `anyVararg()` - this also uses `any()` internally
- `isA()`, `isNull()`, `notNull()`, `isNotNull()` - under the hood wrap same methods from Mockito.

This sounds quite interesting because here we faced an inconsistency between mockito-kotlin and Mockito in terms of using the `any()` method.  
The only reason I can speculate on why it happens so is that term `any` becomes overloaded when we're writing kotlin code. In kotlin `Any` is a class that any object extends (unlike java where all objects extend `Object`). At the same time in kotlin, we have `Any?` type that is broader than `Any`. So, when we try to match against `any()` - do we mean that we match any possible input or that we'd like to match all the inputs that extend `Any` and not `Any?`?  
If we look from that side everything becomes quite logical - if you expect to match against `Any` - you use `any()` and if you match against `Any?` you use `anyOrNull()`.  
But as there is no compiler/lint support for that - for anyone who comes from a java background and usage of Mockito library such change might become surprising.  

The exact implementation of each matcher one can find [here](https://github.com/mockito/mockito-kotlin/blob/main/mockito-kotlin/src/main/kotlin/org/mockito/kotlin/Matchers.kt)

### Mockk

Let's rewrite our mock using Mockk:
```kotlin
val product = mockk<Product> {
    every { calculatePrice(any()) } answers {
        when (val discountId = it.invocation.args[0] as String?) {
            null -> Price(10)
            discountId1 -> Price(5)
            discountId2 -> Price(4)
            else -> throw UnsupportedOperationException("$discountId is not mocked")
        }
    }
}
```
It will look similar to what we can have with mockito-kotlin.  
We run our test and it passes! So, the behavior is similar to what we have in Mockito and not mockito-kotlin.

Let's check what we have in the Mockk: `any()`, `isNull(inverse: Boolean = false)`, `ofType(cls: KClass<R>)`, `ofType<T>()`

- `any()` - is a constant matcher that always matches. Similar to `any()` in Mockito or `anyOrNull()` in mockito-kotlin
- `isNull(inverse = false)` - matches if input is `null`
- `isNull(inverse = true)` - matches if input is not `null`
- `ofType<T>(cls: KClass<R>)` - matches if input R is instance of T
- `ofType<T>()` - simpler version of previous one - matches if input is instance of T

For anyone who is interested more info about implementation is [here](https://github.com/mockk/mockk/blob/master/dsl/common/src/main/kotlin/io/mockk/API.kt)

### Conclusion

From this we can learn a few things:
- when using some library read the documentation and better dive into how it is implemented to not get surprised later on
- if possible prefer using fakes over mocks. In this case, you'll get the same behavior no matter what mocking library you use to verify interactions, therefore you'll get more control of your test doubles

Happy coding!
