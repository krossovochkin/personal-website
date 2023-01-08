+++
title = "Reactive streams testing"
date = "2023-01-08"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["testing", "rxjava"]
keywords = ["rx", "rxjava", "kotlin flow", "testing"]
description = "Practical considerations for reactive streams testing."
showFullContent = false
+++

## Introduction

We should test the code to guarantee that it does exactly what it is expected to do. Tests not only verify correctness of the program but also set expectations. This becomes especially useful for public API, where tests can be treated as part of documentation that describes not only results but also behavior. Such things help do less painful migrations and refactoring as it becomes clear what behaviors are changing and what we should do about that.  

General note: while many of the items discussed below are important, it doesn’t mean that all of them should be applied blindly to every situation. Adding too many constraints on public API might lead to less flexibility in the future and provide additional maintenance overhead. As usual, be pragmatic.  

When we talk about testing, reactive streams - whether it is RxJava or Kotlin Flow - developers tend to write just a little of tests to verify that values emitted and control flow works as expected. But there are quite a lot of other things that might be worth to test.  

The key difference between the reactive and non-reactive API method is that reactive API has more implicit features that, when not documented, can lead to misunderstanding in the future. Generally speaking, similar points can be applied to the callback-based API as well, though here we’ll take reactive streams as an example.  

In this article, we’ll go briefly through such things and point out why it might be important to extend the test suite with such tests.

We’ll take some class with the method that returns reactive stream and look what we might want to test in order to document its behavior.

```kotlin
class LocationProvider(/* dependencies */)) {

    fun observeLocations(): Flowable<Location> {
        // implementation
    }
}
```

We don’t care about implementation of the class (as it might be different depending on the use-case) and are more interested in looking at the public API and how we might want to test it.

### Values emission

For the sake of completeness, the first thing we test is that values are emitted when expected. Our location provider most likely wraps some platform API and emits value when platform API provides us some.  

This is a very basic test that usually is written always. It looks like this:

```kotlin
fun `when platform provides location then value is emitted`() {

    // setup platform test double to provide location

    // verify value is emitted by provider
    provider.observeLocations()
        .test()
        .assertValue(location)
}
```

Not writing test like this might not catch case when location is not emitted when expected - this will lead to all consumers be basically broken as locations won’t be provided.

The opposite logic of verifying that values are not emitted when they should not - also falls into this section, though it might be more difficult to check. It is always easier to prove existence than to prove that something doesn’t exist. We might think that value was not emitted, but it actually will be a bit later, e.g. because of concurrency. Therefore, testing that value is not emitted should be done carefully.

### Errors

Starting from this item, things start to complicate.  

During computation, there might be some errors - for example, the provider can be designed to return only valid locations and what location is considered being valid might depend on the particular business logic. When such error values are provided by platform API, there are different strategies our provider might implement:

- we might skip invalid values
- or terminate stream with error (this will effectively stop the stream)
- or emit fallback value
- etc.

Also, it might be that platform API instead of providing a value throws an exception - if we don’t handle it inside provider, that exception might also terminate the stream.

It is useful to declare what strategy we use so that consumers are aware of that.  

Usually, it is not that good to pass error downstream, because if consumers don’t handle it the error might not be got caught at all and crash the app. Better to either handle errors inside or change signature to something like `Result<Location, Error>` making consumers to explicitly handle error situations.  

In both cases, we might want to write tests ensuring that the stream is not terminating with error. It might look like this:

```kotlin
fun `when platform fails to provide location then stream has no errors`() {

    // setup platform test double to fail
    
    // verify error is not terminated with error 
    provider.observeLocations()
        .test()
        .assertNoErrors()
}
```

We also can add `assertNoErrors` to each stream verification to ensure that in all cases stream is not terminated with error.

Not writing tests like these might not catch an error that is passed downstream that potentially can crash the app.

### Completion

It might happen so that our stream emits some number of elements and then completes. Some consumers might rely on that and if it is not documented properly, this might lead to issues in the future. Consider, the consumer does something like:

```kotlin
provider.observeLocations()
    .toList()
    .doOnNext { /* do sth with list of locations */ }
```

If at some point in the future we change implementation so that it doesn’t complete anymore - such consumer code will basically hang forever as `toList` expects the stream to be completed. This might lead to app hangs or OOMs if the number of locations grows.  

Therefore, in such cases better to be explicit - we can write tests declaring when stream completes or adding `assertNotComplete` to ensure that our stream is not completed.

### Duplicates

Imagine we have a stream providing locations and we expect that new value will always be different from the previous one. From an implementation standpoint, it is as simple as adding `distinctUntilChanged` to the stream. But consider we haven’t added it in the first place thinking that platform API does that already. We give our API to consumers and they start using it. Later on, we find that platform API might provide duplicate locations and add `distinctUntilChanged` to our implementation. Such a simple change already can break some consumers if they e.g. expected to get values at some particular rate (e.g. once per second) and instead now they have gaps that might lead to some weird behaviors on the client side.

That is why it is important to state whether the stream emits duplicate values or not. If we want our stream to emit new value only if it is different from previous we can write test like:

```kotlin
fun `when duplicate value provided then skips duplicate`() {

    // setup platform test double to emit two duplicate items

    // verify only the first item is emitted by provider
    provider.observeLocations()
        .test()
        .assertValue(location)
        .assertNoErrors()
        .assertNotComplete()
}
```

### Threading

Streams are always operating on some thread. This thread is usually part of some thread pool defined by schedulers. Stream might operate on some particular scheduler (e.g. io) or use caller’s thread. Not being explicit about this might lead to issues in case threading is changed in the implementation. Say, in the beginning there is no particular threading applied and stream basically works on the consumer’s thread. If consumer subscribes to values to be on the main thread (to update some UI component) and later on we change threading to io consumers can crash as UI components should be touched only by main thread. We can state that our implementation works on io and emits values on io - this way it is client's responsibility to switch to other scheduler if needed.

For that we can write test like this:

```kotlin
fun `values are emitted on io`() {
    provider.observeLocations()
        .doOnNext { assertTrue(Thread.currentThread().name.startsWith(“io”)) }
        .test()
}
```

### Hot vs cold

In order to provide more optimized experience, we can provide a hot implementation that will ensure that consumers don’t add CPU and memory pressure by subscribing to `observeLocations` too many times. At the same time, we can not do that if having many subscriptions doesn’t have such an overhead. Being explicit here gives clear expectations for consumers on whether they need to provide additional sharing or not.

Covering this with tests is less obvious and most likely should just ensure that platform API is not called multiple times for each subscriber, something like this:

```kotlin
fun `subscriptions are shared between subscribers`() {
    provider.observeLocations().test()
    provider.observeLocations().test()

    // verify that platform API was called only once
}

```

### Disposal

When sharing subscriptions as an implementation detail, we might want to add test to ensure that if there are no subscribers - we don’t listen for platform API calls to not consume resources. Not doing so, we might end up with a provider being running in the background even if nobody listens to its values. To cover this, we can write the following test:

```kotlin
fun `disposes when no subscribers`() {
    val observer1 = provider.observeLocations().test()
    val observer2 = provider.observeLocations().test()

    observer1.dispose()
    observer2.dispose()

    // verify that platform API was unsubscribed
}
```

### Throttling

If we don’t want to overwhelm consumers with a lot of data, we can apply throttling to emit location e.g. every second. Again, not stating this explicitly might break consumers if the rate is changed afterwards. To ensure correct throttling is applied, one needs to add tests for that:

```kotlin
fun `throttles by one second`() {

    val observer = provider.observeLocations().test()

    // make platform to emit few items 

    // verify only first item emitted
    observer
        .assertValue(location1)
        .assertNoErrors()
        .assertNotComplete()

    testScheduler.advanceTimeBy(1, SECOND)

    // make platform to emit a few more items

    // verify only one new item emitted
    observer
        .assertValues(location1, locationN)
        .assertNoErrors()
        .assertNotComplete()
}
```

### Conclusion

In this article, we took a look at the different angles which it might be useful to consider when covering public API with tests.  

Of course, there are different situations and use cases, so examples above are just examples - sometimes we might want our stream to complete, sometimes we don’t care about termination with error and so on.  

At the same time, designing API thinking about different aspects helps to make better APIs and have easier refactorings in the future.  

If somebody changes the behavior of the implementation, then corresponding test will fail and it will indicate that one should go through the usages of API and check whether some bug will be introduced by such a change. Knowing what to look for simplifies work and the probability of having hidden bugs becomes smaller.  

Happy coding!