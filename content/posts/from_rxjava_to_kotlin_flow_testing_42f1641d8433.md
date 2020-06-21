+++
title = "From RxJava to Kotlin Flow: Testing"
date = "2020-03-05"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = []
keywords = []
description = "Comparing approaches to testing in RxJava and Kotlin Flow"
showFullContent = false
+++

![[Source](https://unsplash.com/photos/9kSTF9PvETM)](https://cdn-images-1.medium.com/max/2000/0*vdvxw_Xv2ADnyc2_)*[Source](https://unsplash.com/photos/9kSTF9PvETM)*
> This post is part of series of comparing RxJava to Kotlin Flow. Previous articles were about [Threading](https://proandroiddev.com/from-rxjava-2-to-kotlin-flow-threading-8618867e1955), [Backpressure](https://proandroiddev.com/from-rxjava-to-kotlin-flow-backpressure-d1fb91e6dea8), [Error Handling,](https://proandroiddev.com/from-rxjava-to-kotlin-flow-error-handling-da1f6a4f2708) [Stream Types](https://proandroiddev.com/from-rxjava-to-kotlin-flow-stream-types-7916be6cabc2), [Throttling](https://proandroiddev.com/from-rxjava-to-kotlin-flow-throttling-ed1778847619)

## Introduction

Testing is a crucial part of whole development. Testing allows you to write programs in a reliable fashion, prevent regressions and have many other goodies. I won’t go through the list of advantages of writing tests in this article though.
In testing it is important to have tools which allow you to write reliable tests and also tools which allow you to test your business logic.
Business logic might be inside some function which calculates data and returns result, but also it might be some loading of data from network or doing some work in reaction to UI events. In places where we might have RxJava integrated. So it is very important to be able to test our rx-chains.
In this article we’ll go through the most important concepts in RxJava testing and compare it with what we have in Kotlin Flow.

## Testing in RxJava

General arsenal of testing tools in RxJava consist of TestObserver and TestScheduler.
We can subscribe to any stream with special test observer and then assert events which happen inside the stream over time.
With Test schedulers we can either provide blocking work in places where it was designed to be concurrent and also work with virtual clock.

## Testing in Kotlin Flow

In Kotlin Flow main components are TestCoroutineScope and TestCoroutineDispatcher. Running tests in test coroutine scope allows you to verify that no job leaked test execution and gives you access to test dispatcher which allows you to work with virtual clock.

## Comparison

### Simple assert on stream

We’ll start from simple assertion of the stream values. We might want to verify that subscribing to some stream (e.g. repository method) provides required items and for example has no errors but completes in the end.

Test for Rxjava in this case will look like the following:

    Observable.just(1, 2, 3)
        .test()
        .assertValues(1, 2, 3)
        .assertNoErrors()
        .assertComplete()

Here we have simple observable which emits three values and then completes. We subscribe to it using test() method and receive TestObserver as a result. Then we can make assertions on that observer. For example check that we have all three values emitted and that stream completed without errors.

In Kotlin there is no TestObserver implementation yet. So in order to verify that our stream contains required items we’ll have to just collect into list and look at the results:

    runBlockingTest {
        val result = flowOf(1, 2, 3)
            .toList(mutableListOf())

        assertEquals(listOf(1, 2, 3), result)
    }

We could use runBlocking for our test, but it is better to always use runBlockingTest as it provides more features and specially designed for testing.

Testing of Kotlin Flow seems more similar to general unit testing (as for example with Sequences). But don’t make a decision too early, let’s look at next examples.

### Assert on dynamic stream

In the next example we’ll try to test dynamic stream. First let’s try to define what I mean here by dynamic stream. Usually we have some stream (say, Observable), which starts emitting items upon subscription. If we have such stream then the only thing we can do to test it — is to subscribe and see the results. But it is not always enough.
Consider the case when you have some function which is triggered when user clicked on some button. Your function might be in one class and original stream of UI events be in a separate class (for example on view). In this case when you want to test your class you have Observable of streams as a dependency. And in test we won’t have any user, we even won’t have UI. So, we need a way to emulate user events. And we’ll do that using “dynamic stream”, where we can send events on demand.
In RxJava for that we’ll use Subject. If we want to send some event to our class, we’ll just send event to that Subject. And we’ll provide that subject to the class we’re testing.

Let’s see how it looks in test example:

    val subject = PublishSubject.create<Int>()

    val observer = subject.test()

    observer
        .assertNoValues()
        .assertNoErrors()
        .assertNotComplete()

    subject.onNext(1)

    observer
        .assertValues(1)
        .assertNoErrors()
        .assertNotComplete()

We create our test subject and subscribe to it with test.
Then we assert that we don’t have any values in it.
After that we send some event (say we send UI click event to our class) and verify that on the receiver side we received that event.

In Kotlin Flow analog of Subject is Channel, so let’s do the following:

    runBlockingTest {
        val subject = Channel<Int>()
        val values = mutableListOf<Int>()
        val job = launch {
            subject.consumeAsFlow()
                .collect { values.add(it) }
        }

        assertEquals(emptyList<Int>(), values)

        subject.send(1)

        assertEquals(listOf(1), values)

        job.cancel()
    }

We created our channel in which we’ll send events. But as Kotlin Flow doesn’t have any test observer, we have to store our list of values locally and add values to that list when we receive new item.
The issue with such approach is that it is verbose and we have to do that in each test. Also we have to wrap collecting of the items in flow inside separate coroutine (started with launch) because our channel won’t be closed till the end of test and if any work is not completed before test ended, we’ll get an exception from runBlockingTest. So it is important to store reference to job and cancel it in the end of test.
Sounds too complex. Let’s try to make it a bit better by writing our own implementation of TestObserver for Kotlin Flow:

    fun <T> Flow<T>.test(scope: CoroutineScope): TestObserver<T> {
        return TestObserver(scope, this)
    }

    class TestObserver<T>(
        scope: CoroutineScope,
        flow: Flow<T>
    ) {

        private val values = mutableListOf<T>()
        private val job: Job = scope.launch { 
            flow.collect { values.add(it) } 
        }

        fun assertNoValues(): TestObserver<T> {
            assertEquals(emptyList<T>(), this.values)
            return this
        }

        fun assertValues(vararg values: T): TestObserver<T> {
            assertEquals(values.toList(), this.values)
            return this
        }

        fun finish() {
            job.cancel()
        }
    }

We wrap that local list of values inside our observer and provide methods similar to what we have in RxJava.
After using our test observer we’ll have such a test:

    runBlockingTest {
        val subject = Channel<Int>()
        val observer = subject.consumeAsFlow().test(this)

        observer.assertNoValues()

        subject.send(1)

        observer.assertValues(1)

        observer.finish()
    }

Looks better. But pay attention that we still have to finish our test observer in the end of test.

Now let’s also re-write test for our first example using our test observer:

    runBlockingTest {
        flowOf(1, 2, 3)
            .test(this)
            .assertValues(1, 2, 3)
            .finish()
    }

Again, it now seems to look more declarative.

### Custom Scheduler/Dispatcher

In streams we usually subscribe/observe on some particular Scheduler, for example io or mainThread. Though in tests we don’t have main thread at all and using io thread might provide some latency and need to add logic to convert async code into blocking one.
It is good pattern to provide dependencies instead of using singletons, so it can also be applied to schedulers.
For example if we have some load function which works on some particular scheduler, to make it testable, we can provide that scheduler as a dependency:

    private fun load(
        scheduler: Scheduler = Schedulers.computation()
    ): Observable<Int> {
        return Observable.just(1)
            .delay(1, TimeUnit.SECONDS, scheduler)
    }

By default delay works on computation scheduler, which might make testing more difficult.
For example if we write such a test:

    load()
        .test()
        .assertValues(1)
        .assertNoErrors()
        .assertComplete()

It will fail, because test will be completed before separate computation thread finished.
In tests we can provide separate scheduler and one option is to use trampoline.

    load(Schedulers.trampoline())
        .test()
        .assertValues(1)
        .assertComplete()
        .assertNoErrors()

Now our test passes, as now we basically run our code in a blocking manner.
Note that we’ll wait for the whole delay to expire, so this test will be quite long (more than a second), which is not that good for unit testing.

In Kotlin Flow I haven’t found any alternative to trampoline. Coroutines are suspending and not blocking, so trying to make them work on single thread seems not a good option. But there is a way to workaround that in a following way:

    runBlockingTest {
        val observer = load(coroutineContext.minusKey(Job))
            .test(this)

        advanceUntilIdle()

        observer
            .assertValues(1)
            .finish()
    }

And our test load function is:

    private fun load(context: CoroutineContext): Flow<Int> {
        return flow {
            delay(1000)
            emit(1)
        }.flowOn(context)
    }

What we do here is provide separate context (it is still good approach to provide context/dispatcher as a dependency, so we can use separate one in tests).
We have to do small trick by removing Job from context, because flow context can’t have a job.
And we use advanceUntilIdle method to wait until our delay expired.
Note that advancing clock changes virtual time, so that we don’t have to wait for a second and test will be pretty fast.

### Work with virtual clock

Last but not least let’s see how to have a full power of controlling the stream by working with virtual clock.
The idea is simple — when we have some streams which emit values with some delays or with some throttling we might encounter issues in testing, because usually these operators work on a background threads (or suspending) and because any time-bound work is pretty difficult to test in real-time.
For that there is virtual clock which can be advanced on demand by requested amount of time.

In RxJava such ability has TestScheduler. It has function advanceTimeBy where we can skip some time.
Let’s look at the final example where we’ll test debounce operator with our TestScheduler:

    val scheduler = TestScheduler()

    val subject = PublishSubject.create<Int>()
    val observer = subject
        .debounce(1, TimeUnit.SECONDS, scheduler)
        .test()

    observer
        .assertNoValues()
        .assertNotComplete()
        .assertNoErrors()

        subject.onNext(1)

    observer
        .assertNoValues()
        .assertNotComplete()
        .assertNoErrors()

        scheduler.advanceTimeBy(500, TimeUnit.MILLISECONDS)

    observer
        .assertNoValues()
        .assertNotComplete()
        .assertNoErrors()

        scheduler.advanceTimeBy(500, TimeUnit.MILLISECONDS)

    observer
        .assertValues(1)
        .assertNotComplete()
        .assertNoErrors()

This test is much longer than previous ones, though pretty simple, let’s look what we have here.
First we create our test scheduler and subject which we’ll throttle with debounce.
Inside debounce we provide our test scheduler so now we’ll be able to control timing.
After setup is done we just verify that we don’t have any values emitted.
As we have debounce of 1 second, first emitted value should be emitted after that timeout expired (if there won’t be any more emitted values).
We send event to our subject and verify that it hasn’t been emitted.
Then we advance time by 500ms — half time of timer — and verify that no value is emitted.
And finally we advance time by 500ms which should expire timer and emit value. And we verify that exactly this happened.

Pretty powerful.

In Kotlin Flow there is TestCoroutineDispatcher which is inherited in runBlockingTest. The test will be similar to what we have in Rx (and of course we add our TestObserver implementation to make it more concise):

    runBlockingTest {
        val subject = Channel<Int>()
        val observer = subject.consumeAsFlow()
            .debounce(1000)
            .test(this)

        observer.assertNoValues()

        subject.send(1)

        observer.assertNoValues()

        advanceTimeBy(500)

        observer.assertNoValues()

        advanceTimeBy(500)

        observer
            .assertValues(1)
            .finish()
    }

## Bonus

If we took a look at how tests are written in sources of kotlin coroutines, we could find something interesting: there is a TestBase class which has some powerful API ([link](https://github.com/Kotlin/kotlinx.coroutines/blob/master/kotlinx-coroutines-core/jvm/test/TestBase.kt)).
One of that API is expect, which declares order in which code expected to be invoked.

Let’s look at one test for debounce operator:

    @Test
    public fun testBasic() = withVirtualTime {
        expect(1)
        val flow = flow {
            expect(3)
            emit("A")
            delay(1500)
            emit("B")
            delay(500)
            emit("C")
            delay(250)
            emit("D")
            delay(2000)
            emit("E")
            expect(4)
        }

        expect(2)
        val result = flow.debounce(1000).toList()
        assertEquals(listOf("A", "D", "E"), result)
        finish(5)
    }

To understand what is the expected order of execution one should just look at indexes inside expect.
Also it uses auto-incremental virtual time — whenever execution hits delay it automatically advances virtual time by that.
Finally we collect result to list — something we’ve already encountered.

But this TestBase implementation is not available, though looks pretty well. Hoping it to get into kotlin-coroutines-test package.

## Conclusion

Testing of RxJava and Kotlin Flow is similar, though kotlin library still seems to miss important concepts such as TestObserver to simplify testing. Other than that it is possible to verify same behaviors in a similar fashion. And the most important is abililty to work with virtual clock.
Testing is imporant and it is good that Kotlin coroutines have built-in testing support.

Happy coding!

*Thanks for reading!
If you enjoyed this article you can like it by **clicking on the👏 button** (up to 50 times!), also you can **share **this article to help others.*

*Have you any feedback, feel free to reach me on [twitter](https://twitter.com/krossovochkin), [facebook](https://www.facebook.com/vasya.drobushkov)*
[**Vasya Drobushkov**
*The latest Tweets from Vasya Drobushkov (@krossovochkin). Android developer You want to see a miracle, son? Be the…*twitter.com](https://twitter.com/krossovochkin)
