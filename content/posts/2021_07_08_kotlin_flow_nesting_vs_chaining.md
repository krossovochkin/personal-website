+++
title = "Kotlin flow: Nesting vs Chaining"
date = "2021-07-08"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin", "kotlin flow"]
keywords = ["kotlin", "kotlin flow", "rx", "stream", "nest", "chain"]
description = "When it comes to reactive streams it is likely everyone heard about huge 'rx-chains'. In this article we'll see that reactive streams are not only about chaining, but also about nesting and will find out important differences."
showFullContent = false
+++

[![](https://img.shields.io/badge/androidweekly-474-blue#badge)](https://androidweekly.net/issues/issue-474) [![](https://img.shields.io/badge/kotlinweekly-258-purple#badge)](https://mailchi.mp/kotlinweekly/kotlin-weekly-258)

### Introduction

When it comes to reactive streams it is likely everyone heard about huge 'Rx-chains'. But reactive streams are not only about chaining but also about nesting. Let's find out what are they, what are the differences, and why it matters.  
We'll use Kotlin Flow throughout the article, but everything can be applied to RxJava as well.

First of all, we need to come up with definitions. For that, we'll take a look at some simple streams.  

This is an example of chaining. We connect streams together making them look like they are aligned in a single line - like a chain:
```kotlin
stream1
    .flatMap { stream2 }
    .flatMap { stream3 }
    .flatMap { stream4 }
    .collect()
```

And here example of nesting. Each stream is nested in the previous one. This looks like a nested if-conditions - therefore "nesting":
```kotlin
stream1
    .flatMap {
        stream2.flatMap {
            stream3.flatMap {
                stream4
            }
        }
    }
    .collect()
```

If each stream in the above examples just emits some value and completes, and inside collect we'll print the resulting value - there will be no difference between nesting and chaining. And chain code looks more structured and nesting is smaller - this is better for readability.  
So, let's just use chaining always! Not so fast, there are still cases where nesting is a go-to approach.

### Passing data between streams

Suppose we have a task: we need to query one server endpoint, grab the data from it and send to another server endpoint. And one important thing: both endpoints require `userId` to be provided. The code would look sth like:
```kotlin
observeUser()
    .flatMap { user ->
        api.load(user.id)
            .flatMap { data -> api.send(user.id, data) }
    }
    .collect()
```
Here we used nesting and it is the only option. If we tried to move the second `flatMap` into the chain - it won't work as `user` won't be accessible anymore.

```kotlin
observeUser()
    .flatMap { user ->
        api.load(user.id)
    }
    .flatMap { data -> api.send(user.id, data) } // ! user is not accessible
    .collect()
```

An important observation is that nesting unlike chaining creates scope. And one of the simplest things one can do with the scope is to share some data inside it.

### Manage scope lifecycle

Managing variables is the simplest thing, but there is another one - more powerful: scope lifecycle.
Let's imagine that we have a task of displaying a user's location on a screen - for that we need to observe location data. But we should do that only in some certain cases - these cases will be responded to us by the server.  
The implementation will look like the following:

```kotlin
observeUser()
    .flatMapLatest { user -> 
        api.load(user.id)
            .flatMapLatest { observeLocation() }
    }
    .collect()
```

Here we again used nesting, while we don't need to pass any data to the `observeLocation` stream. Additionally, instead of `flatMap` we've used `flatMapLatest` (in RxJava it is called `switchMap`) - if the new value will be sent by upstream the downstream will be canceled and a new one created. This ensures that if the user was changed (e.g. account switched) we'll trigger the server once again to determine whether we need to observe location.

So, why do we use nesting here? Why not use chaining like this:
```kotlin
observeUser()
    .flatMapLatest { user -> 
        api.load(user.id)
    }
    .flatMapLatest { observeLocation() }
    .collect()
```

The answer is: because we have requirements on a stream lifecycle. To better show this let's write some test.
We'll have two versions of implementations (for simplicity we'll remove all the details and create abstract test):
```kotlin
fun testFlowChain(
   triggerFlow: Flow<Unit>,
   observeData: Flow<Int>,
   observeChanges: Flow<Int>
): Flow<Int> {
   return triggerFlow
       .flatMapLatest { observeData }
       .flatMapLatest { observeChanges }
}

fun testFlowNest(
   triggerFlow: Flow<Unit>,
   observeData: Flow<Int>,
   observeChanges: Flow<Int>
): Flow<Int> {
   return triggerFlow
       .flatMapLatest {
           observeData
               .flatMapLatest { observeChanges }
       }
}
```

And in the test, we'll check whether the behavior of these two approaches is the same.

First, we set up `SharedFlow`s, so that we can emulate streams emission over time.  
Then start collecting our stream under test, emit data to each of the streams and verify the result.
```kotlin
fun test(
   tag: String,
   testFlow: (Flow<Unit>, Flow<Int>, Flow<Int>) -> Flow<Int>
) {
   // GIVEN
   val triggerFlow = MutableSharedFlow<Unit>()
   val observeData = MutableSharedFlow<Int>()
   val observeFlow = MutableSharedFlow<Int>()

   runCatching {
       runBlockingTest {
           val items = mutableListOf<Int>()

           val job = launch {
               testFlow(
                   triggerFlow,
                   observeData,
                   observeFlow
               ).collect { items += it }
           }

           // WHEN
           val data = 200
           val changedCount1 = 500

           triggerFlow.emit(Unit)
           observeData.emit(data)
           observeFlow.emit(changedCount1)

           // THEN
           check(items == listOf(changedCount1)) {
               """Check failed:
                   |Expected: ${listOf(changedCount1)}
                   |Actual: $items
               """.trimMargin()
           }
//...
```

If we run this test for each of the approaches we'll see that everything works correctly: all flows are triggered and the result is the same.
But let's extend the test with some custom emission:
```kotlin
   // WHEN
   val changedCount2 = 200

   triggerFlow.emit(Unit)
   observeFlow.emit(changedCount2)

   // THEN
   check(items == listOf(changedCount1)) {
       """Check failed:
           |Expected: ${listOf(changedCount1)}
           |Actual: $items
       """.trimMargin()
   }

   job.cancel()
}
```
We emit data in each stream except the middle one.  
And when we run tests - the results are different. The nesting approach won't emit value while chaining will.  
If we get back to our example with observing location that means that in the chaining case we might face an issue that the user was changed, but we still collect location data for the previous user. This is a major issue!

It happened because in the case with nesting we've defined the scope that has lifecycle attached to the `observeUser` stream: when the user is changed - everything inside `flatMapLatest` will be canceled. And in the case of chaining, we have `observeLocation` outside of user scope - so when the user changed, the location stream is not canceled.

### Conclusion

Understanding such simple concepts such as nesting and chaining becomes crucial for work with reactive streams because on the first look everything might look good, but in reality, there might be some hard-to-catch issues.  
Think thoroughly what approach to choose based on requirements. And write tests - they can help you catch unwanted behavior faster and make your code more reliable.

Happy coding!
