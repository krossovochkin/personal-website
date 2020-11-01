+++
title = "From RxJava to Kotlin Flow: Stream Types"
date = "2020-02-26"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["rxjava", "kotlin", "kotlin flow"]
keywords = ["rxjava", "rxjava2", "kotlin", "kotlin flow", "flow", "stream", "stream types"]
description = "Comparing Stream Types in RxJava and Kotlin Flow"
showFullContent = false
+++

![[Source](https://unsplash.com/photos/JcimvPDC3as)](https://images.unsplash.com/photo-1516192891955-70642cf1ac88?ixlib=rb-1.2.1&auto=format&fit=crop&w=1357&q=80)*[Source](https://unsplash.com/photos/JcimvPDC3as)*
> This post is part of series of comparing RxJava to Kotlin Flow. Previous articles were about [Threading](https://proandroiddev.com/from-rxjava-2-to-kotlin-flow-threading-8618867e1955), [Backpressure](https://proandroiddev.com/from-rxjava-to-kotlin-flow-backpressure-d1fb91e6dea8), [Error Handling](https://proandroiddev.com/from-rxjava-to-kotlin-flow-error-handling-da1f6a4f2708)

[![](https://img.shields.io/badge/original-proandroiddev-green#badge)](https://proandroiddev.com/from-rxjava-to-kotlin-flow-stream-types-7916be6cabc2) [![](https://img.shields.io/badge/proandroiddevdigest-16-green#badge)](https://proandroiddev.com/proandroiddev-digest-16-e17b7e8ae48b)

## Introduction

In reactive programming we use streams. Therefore in both RxJava and Kotlin Flow we’ll have to use some streams. Though we’ll encounter some differences if we decide to migrate.
In this article we’ll try to get into the stream types which have RxJava and Kotlin Flow and some important differences.

## RxJava Stream Types

In RxJava there are a bunch of different types of streams. Among them there are:

* Observable — general stream of events

* Flowable — same as Observable, but with backpressure support

* Single — stream which can have only single event (either value or error)

* Maybe — same as Single, with distinction that it might complete without providing any value

* Completable — stream which can only complete without emitting values.

There are two reasons why these types were introduced:

* Performance. Knowing that stream will have exactly one item, or no values at all can allow some optimizations

* Expressiveness. By declaring method to return, let's say Single, we give more information to the reader than if we just return Observable.

We can start the chain with any of these streams and we can switch from one stream type to another using methods like Observable.flatMapCompletable() (which will switch from observable to completable, obviously).

## Kotlin Flow Stream Types

In Kotlin Flow there is only one stream type and it is Flow. For other use cases we can use general suspending functions.
If we try to compare RxJava stream types with what we have in Kotlin, we get the following:

* Observable/Flowable are represented via Flow. There is no separate implementations without and with backpressure support in Kotlin Flow. We always use Flow.

* Single can be represented as general function like suspend () -> T (where T : Any to avoid nullability).

* Maybe can be represented similar to Single, but with explicit nullable value: suspend () -> T? (pay attention to ?, T : Any also applies)

* Completable can be represented as suspend () -> Unit

The difference we can spot at the beginning is that in Kotlin Flow if we want to create some reactive stream we have to create Flow. That means that all chains have to start from Flow (and can't be started from let's say Single).
Also to switch between different types we'll have to either wrap them into Flow or directly call functions in some transforming operators.

Let's investigate this in details.

## Comparison

### Simple non-reactive work

First, let's start with comparing non-reactive work. It might sound weird, as RxJava is a reactive framework, but having threading support and types which represent only one value (such as Single) allow you to write async code which doesn't involve any reactiveness.
The example will be the following:

* we'll try to load data from cache (it might be null)

* if data retrieved from cache is null, then we'll query network (which always will return us data)

* then we request to save retrieved data to cache.

As one can see here we'll have three stream types in this example: Maybe will represent cache (as it might have value, but might have not), Single will represent network (as it will always return us single value), Completable will represent storing data into cache (as we don't care about result, we just need to get the callback that work was completed).

We'll start from defining few helper functions which will emulate requests to cache and network.

For RxJava it will be:

```kotlin
private fun readCacheRx(data: String? = null): Maybe<String> {
    return if (data != null) {
        Maybe
            .just(data)
            .delay(100, TimeUnit.MILLISECONDS)
            .doOnSuccess { println("read from cache: $data") }
    } else {
        Maybe
            .empty<String>()
            .delay(100, TimeUnit.MILLISECONDS)
            .doOnComplete { println("read from cache: $data") }
    }
}

private fun readNetworkRx(data: String = "data"): Single<String> {
    return Single
        .just(data)
        .delay(100, TimeUnit.MILLISECONDS)
        .doOnSuccess { println("read from network: $data") }
}

private fun saveCacheRx(data: String): Completable {
    return Completable
        .fromAction {
            println("saved to cache: $data")
        }
        .delay(100, TimeUnit.MILLISECONDS)
}
```

**NOTE:** the code could be shorter if we created everything with #create method, though it doesn't matter in the scope of this article

And for Kotlin Flow:

```kotlin
private suspend fun readCache(data: String? = null): String? {
    delay(100)
    println("read from cache: $data")
    return data
}

private suspend fun readNetwork(data: String = "data"): String {
    delay(100)
    println("read from network: $data")
    return data
}

private suspend fun saveCache(data: String) {
    delay(100)
    println("saved to cache: $data")
}
```

So, we wait for some time emulating latency, then we print some debug information and return result if any.

Now let's look at the RxJava implementation of given example:

```kotlin
val latch = CountDownLatch(1)

readCacheRx(null) // pass "data" to check when cache has data
    .switchIfEmpty(readNetworkRx())
    .flatMapCompletable { saveCacheRx(it) }
    .doOnComplete { latch.countDown() }
    .subscribeOn(io())
    .subscribe()

latch.await()
```

So, what we do here is:

* read data from cache (providing stubbed result)

* then if we have empty Maybe we switch to reading data from network (otherwise skip step)

* then we switch to saving cache using flatMapCompletable

The result printed into console for case when there is no data cached will be:

```
read from cache: null
read from network: data
saved to cache: data
```

And if there was cache:

```
read from cache: cached
saved to cache: cached
```

Now let's take a look at Kotlin example. It won't include any reactiveness therefore it won't use Kotlin Flow:

```kotlin
runBlocking {
    withContext(Dispatchers.IO) {
        val data = readCache() ?: readNetwork()
        saveCache(data)
    }
}
```

It looks more concise, readability is much better.
So here Kotlin coroutines look like a real winner.
> If you don't need reactive streams, use kotlin coroutines for async code. It is concise and has great readability

### General reactive types

In both RxJava and Kotlin Flow there are general reactive types to represent stream which might have from 0 to (almost) infinite number of events (followed by completion with or without error). In RxJava it is Observable/Flowable, and in Kotlin Flow it is Flow.
If we need to switch from one stream to another we can use xMap operators in RxJava (flatMap, concatMap etc.) and flatMapX operators in Kotlin Flow (flatMapMerge, flatMapConcat etc.).

Examples of such can be like this, for RxJava:

```kotlin
Observable.just(1, 2, 3)
    .flatMap { Observable.just ("a", "b", "c") }
    .subscribe()
```

And for Kotlin Flow:

```kotlin
flowOf(1, 2, 3)
    .flatMapMerge { flowOf("a", "b", "c") }
    .collect()
```

### Switch from non-reactive* to reactive stream
> **NOTE:** here I use ***** to emphasize that equivalents of Maybe/Completable/Single in Kotlin are not reactive streams. In RxJava they of course are.

First let's look at RxJava. Here we'll have an example where we'll read data from cache and then switch to some general observable which will emit some value.
In RxJava it would look like this:

```kotlin
val latch = CountDownLatch(1)

readCacheRx()
    .flatMapObservable { Observable.just(it) }
    .doOnComplete {
        println("complete")
        latch.countDown()
    }
    .subscribe { println("next: $it") }

latch.await()
```

As Maybe is reactive type, we can start our chain from it and make switch to any other reactive type.
The output will be the following:

```
read from cache: null
complete
```

We won't have any value emitted because our initial stream was completed without emitting data.

In order to achieve same behavior we'll have to wrap our suspending function into flow:

```kotlin
runBlocking {
    flow { readCache()?.let { emit(it) } }
        .flatMapMerge { flowOf(it) }
        .onCompletion { println("complete") }
        .collect { println("next: $it") }
}
```

Other than that everything is similar, though wrapping suspending function into flow in each usage looks too verbose.
We could wrap it once and provide it as a function, but then we'll loose expressivenes, because now our function will return Flow<T> and from looking at method signature we're no longer can say whether we have actually Maybe under the hood or some general Flow.

### Switching from reactive stream to non-reactive

Now let's look at example where we'd like to switch from reactive stream to non-reactive*.
The example will be the following: we'll have stream of values and on each emit we'll query network. First time we'll do that sequentially and the second concurrently.

For sequential execution in RxJava we'll use concatMapSingle:

```kotlin
val latch2 = CountDownLatch(1)

Observable.just(1, 2, 3)
    .concatMapSingle { readNetworkRx("$$it") }
    .doOnComplete {
        println("complete")
        latch2.countDown()
    }
    .subscribe { println("next: $it") }

latch2.await()
```

The result printed will be:

```
read from network: $1
next: $1
read from network: $2
next: $2
read from network: $3
next: $3
complete
```

Notice that we first process first item till the very end before starting to work with second item.

For concurrent version we'll use flatMapSingle:

```kotlin
val latch1 = CountDownLatch(1)

Observable.just(1, 2, 3)
    .flatMapSingle { readNetworkRx("$$it") }
    .doOnComplete {
        println("complete")
        latch1.countDown()
    }
    .subscribe { println("next: $it") }

latch1.await()
```

And the result will be:

```
read from network: $2
read from network: $1
read from network: $3
next: $2
next: $1
next: $3
complete
```

As we see we first started querying network concurrently and then process items when they retrieved. Also note that order is not defined in such a case and we can get any kind of order here (not just 1 then 2, then 3).

For Kotlin Flow we again need to wrap our suspending functions into Flow. Then for sequential execution we'll use flatMapConcat and for concurrent — flatMapMerge:

```kotlin
runBlocking {
    flowOf(1, 2, 3)
        .flatMapConcat { flow { emit(readNetwork("$$it")) } }
        .onCompletion { println("complete") }
        .collect { println("next: $it") }
}
```

Result for sequential execution:

```
read from network: $1
next: $1
read from network: $2
next: $2
read from network: $3
next: $3
complete
```

And for concurrent:

```kotlin
runBlocking {
    flowOf(1, 2, 3)
        .flatMapMerge { flow { emit(readNetwork("$$it")) } }
        .onCompletion { println("complete") }
        .collect { println("next: $it") }
}
```

Result:

```
read from network: $1
read from network: $2
read from network: $3
next: $1
next: $2
next: $3
complete
```

Again we have some visual overhead in Kotlin Flow, as we have to wrap everything into flow. But we can try to make implementation without that. Instead we'll use map method where we'll make our background work:

```kotlin
runBlocking {
    flowOf(1, 2, 3)
        .map { readNetwork("$$it") }
        .onCompletion { println("complete") }
        .collect { println("next: $it") }
}
```

The result will be:

```
read from network: $1
next: $1
read from network: $2
next: $2
read from network: $3
next: $3
complete
```

As you see the code seems shorter now, but implementation will behave as sequential code (because map will suspend on each item and not allow concurrency).
Additional note is that usually functions like map, filter etc. are considered as pure functions, that means that they should not contain any kind of side-effects. Having network call inside map I'd call as a smell, but it is totally allowed by the kotlin function (as it accepts suspending functions execution).

### Stream completion issues

One additional thing I'd like to point to is about issues which might happen with completion of the stream. To emphasize that let's take a look at another example.

In that example we'll have some stream of items, for each item we'll trigger saving it to cache. Then after all items were successfully cached, we'll switch to another stream which will provide us some final result (say "done" word).

In RxJava it would look like this:

```kotlin
val latch = CountDownLatch(1)

Observable.just(1, 2, 3)
    .flatMapCompletable { saveCacheRx("$it") }
    .andThen(Observable.just("done"))
    .doOnComplete {
        println("complete")
        latch.countDown()
    }
    .subscribe { println("next: $it") }

latch.await()
```

The result printed would be:

```
saved to cache: 1
saved to cache: 2
saved to cache: 3
next: done
complete
```

Here we see expected result: we save all the values (1, 2 and 3) into cache, and after that we have "done" as value emitted in the stream followed by completion event.

Let's try to implement same functionality with Kotlin.

In our first implementation we can try to not wrap our suspending function to save cache into flow. We can try to use again map function, but seems better would be to use onEach:

```kotlin
runBlocking {
    flowOf(1, 2, 3)
        .onEach { saveCache("$it") }
        .flatMapMerge { flowOf("done") }
        .onCompletion { println("complete") }
        .collect { println("next: $it") }
}
```

But unfortunately the result would be not as expected:

```
saved to cache: 1
next: done
saved to cache: 2
next: done
saved to cache: 3
next: done
complete
```

We have too many "done" events. And usage of map won't fix the issue.
The reason behind that is that we allow values to be passed through. In RxJava when switching from Observable to Completable we can't get any events except completion (including with error). Doing work in onEach or trying to use map won't work because this way we transform the stream and not changing the stream.

Then we can try to wrap our saving to cache into flow which will do some work but not emit any value and use flatMapMerge to switch to it:

```
runBlocking {
    flowOf(1, 2, 3)
        .flatMapMerge { flow<String> { saveCache("$it") } }
        .flatMapMerge { flowOf("done") }
        .onCompletion { println("complete") }
        .collect { println("next: $it") }
```

But it won't work as expected either:

```
saved to cache: 1
saved to cache: 2
saved to cache: 3
complete
```

We don't have our "done", even considering that we switched to new stream with one value of "done". This happens because our stream after saving to cache has no items, because of that everything below can't be triggered.
Instead we should make switch to new flow via onCompletion operator. And implementation might be as following:

```kotlin
runBlocking {
    flowOf(1, 2, 3)
        .flatMapMerge { flow<String> { saveCache("$it") } }
        .onCompletion { emitAll(flowOf("done")) }
        .onCompletion { println("complete") }
        .collect { println("next: $it") }
```

And result is as expected:

```
saved to cache: 1
saved to cache: 2
saved to cache: 3
next: done
complete
```

Please pay attention that in our flatMapMerge we have to explicitly define type of event which will be sent in downstream, otherwise it won't compile.

## Conclusion

I'd say that the main conclusion is the following: if you don't need reactiveness — use Kotlin coroutines. It will greatly simplify your code and allow you to write it concise and readable.
Though if you need reactiveness then having only Flow in your arsenal (without Maybe, Completable, Single) might lead to some weird verbosity if you are using switching between reactive and non-reactive* types often.
Anyway try to stick to coroutines everywhere where you don't need reactiveness and wrap into Flow only in the places where it is needed.
Also pay additional attention to events which come through the stream and stream completion events.
And always test your assumptions. It is better to find tricky things fast than allow them to slip away.

Happy coding!