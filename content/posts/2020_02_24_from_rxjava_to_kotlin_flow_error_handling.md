+++
title = "From RxJava to Kotlin Flow: Error Handling"
date = "2020-02-24"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["rxjava", "kotlin", "kotlin flow"]
keywords = ["rxjava", "rxjava2", "kotlin", "kotlin flow", "flow", "error", "error handling"]
description = "Comparing Error Handling in RxJava and Kotlin Flow"
showFullContent = false
+++

![[Source](https://unsplash.com/photos/aYNyC6fIH84)](https://images.unsplash.com/photo-1580357991342-89ec1672c98a?ixlib=rb-1.2.1&auto=format&fit=crop&w=1357&q=80)*[Source](https://unsplash.com/photos/aYNyC6fIH84)*
> This post is part of series of comparing RxJava to Kotlin Flow. Previous articles were about [Threading ](https://proandroiddev.com/from-rxjava-2-to-kotlin-flow-threading-8618867e1955)and [Backpressure](https://proandroiddev.com/from-rxjava-to-kotlin-flow-backpressure-d1fb91e6dea8).

[![](https://img.shields.io/badge/original-proandroiddev-green#badge)](https://proandroiddev.com/from-rxjava-to-kotlin-flow-error-handling-da1f6a4f2708)

## Introduction

Error handling is fundamental in reactive programming. Reactive streams might fail with exception and propagate it as an event downstream notifying consumers on the error that happened.
As in previous articles, we’ll try to compare RxJava and Kotlin Flow error handling mechanisms. This might help us to migrate existing code from RxJava to Kotlin Flow and also understand how to properly use Kotlin Flow.

## RxJava Error Handling

In RxJava general concepts for error handling are pretty simple and straightforward:

* “Error” is an event which might happen in a stream

* That “Error event” is propagated downstream as a terminal event. That means that after error happened stream is basically finished and no more events can come through it.

* Consumers are required to handle errors in the onError callback of Observer

* If Consumer didn’t handle error in Observer callback, then that error is sent to a global error handler (which in case of Android crashes the app by default).
**NOTE**: some errors which happen inside stream can go directly to global error handler e.g. in cases when the stream is already disposed.

* Not a single error can escape chain. All the exceptions will go to the onError callback of Observer (or global error handler).

A basic example of error handling is:

```kotlin
observeChanges()
    .subscribe(
        { value -> println("value: $value") },
        { error -> println("error: $error") }
    )
```

## Kotlin Flow Error Handling

As Kotlin Flow is essentially based on coroutines, the following applies:

* “Error” is a general Exception which can be thrown like any other exception

* That “error” is propagated via general coroutines error handling mechanism (propagating to parent jobs and canceling all the jobs in the coroutine scope)

* Consumers need to wrap Flow with try-catch if they want to handle exceptions

* If the consumer didn’t handle errors with try-catch then that exception will be thrown as usual and be handled by the parent coroutine scope (it might immediately crash your app or be handled by exception handler e.g. in launch)

* As we have to wrap chain in try-catch it looks like exception escaped the chain. It might be partially true, though as we’ll see later this is not the only mechanism to work with exceptions.

## Comparison

### Setup

First of all, for our comparison, we’ll create helper functions of Flow and Observable, which emit a value and then throw an exception.

For Observable:

```kotlin
private fun observable(
    value: Int = 1
): Observable<Int> {
    return Observable.create { emitter ->
        emitter.onNext(value)
        emitter.onError(RuntimeException())
    }
}
```

And for Kotlin Flow (due to clash of names have to name it with “my” prefix):

```kotlin
private fun myFlow(
    value: Int = 1
): Flow<Int> {
    return flow {
        emit(value)
        throw RuntimeException()
    }
}
```

Next, we’ll set up short tests, which will be parametrized by operators. In that test we’ll take our test streams, subscribe to them on the io thread pool, then optionally will apply some operator and then print values and errors which will happen in the chain.

For Observable:

```kotlin
private fun testObservable(
    operator: Observable<Int>.() -> Observable<Int>
) {
    val latch = CountDownLatch(1)
    val result = StringBuffer()

observable()
        .subscribeOn(Schedulers.io())
        .operator()
        .doOnTerminate { latch.countDown() }
        .subscribe(
            { result.append("next $it, ") },
            { result.append("error $it") }
        )

latch.await()
    println(result)
}
```

For Kotlin Flow (note, that here we wrapped all the flow into the try-catch):

```kotlin
private fun testFlow(
    operator: Flow<Int>.() -> Flow<Int>
) {
    val latch = CountDownLatch(1)
    val result = StringBuffer()

    CoroutineScope(Job() + Dispatchers.IO).launch {
        try {
            myFlow()
                .operator()
                .onCompletion { latch.countDown() }
                .collect {
                    result.append("next $it, ")
                }
        } catch (e: Exception) {
            result.append("error $e")
        }
    }

    latch.await()
    println(result)
}
```

### Basic Error Handling

First, our test will be to see what is the default behavior without additional changes. In this case, we’ll provide an identity operator:

```kotlin
testObservable { this }
testFlow { this }
```

In both cases in logs it will be printed:

```
next 1, error java.lang.RuntimeException
```

So, as we already discussed, our test streams emit one value and then terminate with an exception.

### Catching Errors with an emitting default value

What if we don’t want our stream to be terminated (as error event terminates the stream)? One of the options is to emit some default value if we encounter an exception.

In RxJava for that, there is a special operator called onErrorReturn:

```kotlin
testObservable { onErrorReturn { 5 } }
```

If we run this example we’ll see that in logs it will be printed:

```
next 1, next 5,
```

So the first item in the stream (1) was emitted as before, but then instead of an error, we have a default value (5) emitted as well.

In Kotlin Flow for the same use case, there is an operator catch, and the usage is the following:

```kotlin
testFlow { catch { emit(5) } }
```

Operator catch catches all the exceptions from the upstream and can do some work, such as emitting default value. And result in logs will be the same.

### Catching Errors by switching to another stream

Another option with not failing our stream on error is to switch to another stream. In RxJava for that, there is a special operator onErrorResumeNext:

```kotlin
testObservable { onErrorResumeNext(Observable.just(1, 2, 3)) }
```

After running the code the result will be:

```
next 1, next 1, next 2, next 3,
```

First, we have the value of 1 emitted (this is from the initial stream), then after error happened we switch to the new stream and all its values are emitted (and we won’t have an exception thrown).
> **NOTE**: Essentially it is possible to achieve onErrorReturn with onErrorResumeNext by using onErrorResumeNext(Observable.just(5)), though usage of onErrorResumeNext has bigger overhead, so use it only when new stream is really needed.

In Kotlin Flow for such a case we use that same operator catch:

```kotlin
testFlow { catch { emitAll(flowOf(1, 2, 3)) } }
```

Instead of emitting a single value on error, we emitAll values from the stream with the same expected result.

### Intercepting Errors

The next thing which we’ll do is intercepting errors. When we intercept errors we can do some side effects without actually handling that error, for example, logging.

In RxJava for this case, we can use the doOnError operator:

```kotlin
testObservable { doOnError { print("INTERCEPTED $it, ") } }
```

The result will be:

```
INTERCEPTED java.lang.RuntimeException, next 1, error java.lang.RuntimeException
```

So, first, we intercepted our exception, printed some logs, and then as in the case with basic error handling, we got the first item emitted with error followed.

In Kotlin Flow though there is no special operator for that case, but we can write our own:

```kotlin
fun <T> Flow<T>.doOnError(onError: (Throwable) -> Unit): Flow<T> {
    return flow {
        try {
            collect { value ->
                emit(value)
            }
        } catch (e: Exception) {
            onError(e)
            throw e
        }
    }
}
```

Here we just create new Flow, inside it, we start collecting all the values. We wrap everything in try-catch and if an error happens — we’ll execute the callback and re-throw exception.

The usage will be the following:

```kotlin
testFlow { doOnError { print("INTERCEPTED $it, ") } }
```

And as before, results in logs will be the same.

That’s all with the handling errors in the chain, but there is another topic of handling errors in inner streams.

### Inner streams errors handling

As we know we can have inner streams by using flatMap in RxJava or flatMapMerge in Flow (or other xMap operators in RxJava or flatMapX operators in Kotlin Flow).
We can apply directly what we’ve learned to our inner streams, though sometimes there is a need to control error handling from the parent stream perspective.

We’ll modify our test samples a bit to better show that.

For Observable our new example will be:

```kotlin
private fun testInnerObservable(
    operator: Observable<Int>.() -> Observable<Int>
) {
    val latch = CountDownLatch(1)
    val result = StringBuffer()

    Observable.just(10, 11, 12)
        .subscribeOn(Schedulers.io())
        .operator()
        .doOnTerminate { latch.countDown() }
        .subscribe(
            { result.append("next $it, ") },
            { result.append("error $it") }
        )

    latch.await()
    println(result)
}
```

The difference is that now our parent observable won’t throw an exception, instead it will emit three items and complete. Inside operator we’ll be able to add our inner streams.

For Kotlin Flow we’ll have the following sample:

```kotlin
private fun testInnerFlow(
    operator: Flow<Int>.() -> Flow<Int>
) {
    val latch = CountDownLatch(1)
    val result = StringBuffer()

    CoroutineScope(Job() + Dispatchers.IO).launch {
        try {
            flowOf(10, 11, 12)
                .operator()
                .onCompletion { latch.countDown() }
                .collect {
                    result.append("next $it, ")
                }
        } catch (e: Exception) {
            result.append("error $e")
        }
    }

    latch.await()
    println(result)
}
```

There are many different operators in RxJava, but we’ll take a look only at one: concatMapDelayError.
In order to understand how it works, let’s first look at the concatMap and flatMapConcat operators. Both these operators start subscribing to the inner streams one by one. And subscription to the next inner stream happens only when previous was completed.

For RxJava and Kotlin Flow it will look like:

```kotlin
testInnerObservable { concatMap { observable(it) } }
testInnerFlow { flatMapConcat { myFlow(it) } }
```

What happens here:

* Our parent stream has three values

* For each value emitted we switch to the new inner stream (which emits value and then fails)

* Subscription to the next inner stream happens only after the previous inner stream has completed

Result of executing for RxJava and Kotlin Flow will be the same:

```
next 10, error java.lang.RuntimeException
```

We have first item emitted followed by an error and no more values are emitted. This happens because the first item (10) triggered a subscription of the inner stream, which emitted that value (10) and then failed with an exception. Because of that, the whole stream failed and the next item from parent (11) hasn’t been switched to the new inner stream.

What if we want to have all the values emitted and emit error only in the end (if it happened)? For such a case there is concatMapDelayError in RxJava. It will delay all the errors until the stream completes and throw CompositeException with all the exceptions which happened in the stream.

If we run the following code:

```kotlin
testInnerObservable { concatMapDelayError { observable(it) } }
```

We see the result:

```
next 10, next 11, next 12, error io.reactivex.exceptions.CompositeException: 3 exceptions occurred.
```

All three items were emitted followed by a single composite exception (which has three exceptions inside — one per each inner stream).

What about Kotlin Flow? It doesn’t have any operator with delaying errors. But we can try to write our own. We’ll start by copy-pasting sources of flatMapConcat operator and add some error handling there:

```kotlin
fun <T, R> Flow<T>.flatMapConcatDelayError(
    transform: suspend (value: T) -> Flow<R>
): Flow<R> = map(transform).flattenConcatDelayError()
```

We’ll start from defining our operator flatMapConcatDelayError as combination of map and flatten (yep, map + flatten == flatMap).
Then we’ll define our flattenConcatDelayError:

```kotlin
fun <T> Flow<Flow<T>>.flattenConcatDelayError(): Flow<T> {
    val list = CopyOnWriteArrayList<Exception>()
    return flow<T> {
        collect { value ->
            try {
                emitAll(value)
            } catch (e: Exception) {
                list.add(e)
            }
        }
    }.onCompletion {
        if (list.isNotEmpty()) {
            throw CompositeException(list)
        }
    }
}
```

What we do here is wrap our emits into try-catch with saving all the exceptions (note that we need to use thread-safe list). And throw a composite exception at the end if there were some exceptions.

Final call for Kotlin Flow will be:

```kotlin
testInnerFlow { flatMapConcatDelayError { myFlow(it) } }
```

### RxJava-like subscribe for Kotlin Flow

Do I need to always use either catch at the bottom of each chain or wrap everything into try-catch? I’d say yes, but probably it could be useful to have similar API as in RxJava and have single subscribe with three lambdas.

We can try to implement such:

```kotlin
suspend fun <T> Flow<T>.subscribe(
    onNext: (T) -> Unit,
    onError: (Throwable) -> Unit,
    onComplete: () -> Unit
) {
    this
        .onEach { onNext(it) }
        .onCompletion { error: Throwable? ->
            if (error == null) {
                onComplete()
            }
        }
        .catch { onError(it) }
        .collect()
}
```

What we do here is instead of terminal collect method, we’ll use our own subscribe, which takes three lambdas.
In onEach we’ll get all the values emitted. In onCompletion we’ll see that we track our onComplete (note that we need to check that we completed without error). And in catch we catch all the exceptions.
> **NOTE**: we could move onError inside onCompletion if we wish and make catch clause empty. Say it is matter of taste.

**But did anyone spot the issue?**

Let’s run few tests:

```kotlin
runBlocking {
    flowOf(1, 2, 3)
        .subscribe(
            { print("next $it, ") },
            { print("error $it, ") },
            { print("complete ") }
        )
}
```

It prints:

```
next 1, next 2, next 3, complete
```

So far so good. We have all three values emitted following by completion event.

Next test will be with error:

```kotlin
runBlocking {
    flow {
        emit(1)
        throw RuntimeException()
    }
        .subscribe(
            { print("next $it, ") },
            { print("error $it, ") },
            { print("complete ") }
        )
}
```

It prints:

```
next 1, complete error java.lang.RuntimeException,
```

Also good, we have one value followed by error event. And we don’t have a completion event.

Let’s check the final test — we throw exception in a callback:

```kotlin
runBlocking {
    flow {
        emit(1)
    }
        .subscribe(
            { print("next $it, ") },
            { print("error $it, ") },
            { throw RuntimeException() }
        )
}
```

The result will be:

```
next 1, error java.lang.RuntimeException,
```

And this is not what we’ve expected. If we have an exception in a callback, then it should be thrown and should not pass to our error handler. Error handler should catch all the errors in the chain and callback is not essentially part of that chain.

Why it happens so? Because catch is the last operator in the chain and it handles everything which is above. Including what is inside onEach and onCompletion operators.

This is the difference which is needed to keep in mind. If anyone would be able to create an identical implementation of subscribe method, feel free to post it in comments.

## UPD: retry

As was pointed by feedback I missed in this article operators for retry logic. Basically both RxJava and Kotlin Flow has built-in support for retry. For example to retry stream twice (if there was error) one need to use “retry(2)” operator.

## Conclusion

Following this article, I hope we now have a better understanding of error handling in RxJava and Kotlin Flow. RxJava has a lot of operators, many of them are really useful (and are missing in Kotlin Flow right now).

We can write our own implementations, but they stick to be error-prone and platform-specific. Say that flatMapConcatDelayError operator: it uses platform-specific thread-safe list, which might work incorrectly with coroutines (which can jump over threads) — mean that mixing concepts might lead to weird issues. Also, the whole implementation might not be that refined, contain races or whatever.

It is possible to do everything we can do in RxJava with Kotlin Flow and hopefully, additional operators will be added to Kotlin Flow as well.

If anyone wants to play with the setup one can find in [this gist](https://gist.github.com/krossovochkin/1a47f05d3ccbf20fffa872b22362e16d). Feel free to post comments and share your examples or ideas on the important things in error handling in RxJava and Kotlin Flow.

Happy coding!