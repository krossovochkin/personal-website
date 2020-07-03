+++
title = "The Real Kotlin Flow benefits over RxJava"
date = "2020-05-17"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = []
keywords = []
description = "Attempt to analyze the benefits of Kotlin Flow over RxJava."
showFullContent = false
+++

![[Source](https://unsplash.com/photos/Lks7vei-eAg)](https://images.unsplash.com/photo-1553877522-43269d4ea984?ixlib=rb-1.2.1&auto=format&fit=crop&w=1357&q=80)*[Source](https://unsplash.com/photos/Lks7vei-eAg)*

## Introduction

Recently the article about Kotlin Flow benefits over RxJava was published by [Antoni Castejón García](undefined):
[**Kotlin Flow benefits over RxJava**
*Lately I’ve been implementing a new project using Kotlin Asynchronous Flows instead of RxJava as I was used to. Why? I…*proandroiddev.com](https://proandroiddev.com/kotlin-flow-benefits-over-rxjava-b220658f1a92)

Though Antoni made a good work and many thanks to him for providing his feedback and experience (we need to share our thoughts, this improves community acknowledgment in various areas) — I found few places in the article with which I don’t fully or partially agree. Some points, in my opinion, were missing. So, I decided to make a follow-up feedback post on what I consider the real benefits of Kotlin Flow over RxJava. Feedback is also a good thing as it helps us to drive forward and maybe look at the same things from a different angle.

I didn’t want to be mean or offend anyone, especially Antoni. So, if one finds that some wording sounds offensive — please blame my English. My goal is not to argue or point to some mistakes, but to provide my humble opinion. At first, I was thinking about writing a comment to the original story, but the comment was too long, so I decided to make it as a separate article.

The format will be simple — I’ll just take some quotes and add my humble comments. In the end, will try to summarize what I have in my head.

I’ll have a three-level comparing:

* 🚨 Kotlin Flow is either not better or worse than RxJava at the given point. Or there are some drawbacks.

* 🆗 Kotlin Flow has some benefit over RxJava

* ✅ Kotlin Flow has a clear advantage over RxJava

Let’s go!

## Decoding original article
> However, if you want to implement a *Subject* related pattern you will have to use *Channels* for now. It is not a problem, but you will end up having a lot of *ExperimentalCoroutinesApi* annotations in your project. The good thing is they announced that they are going to implement a way to catch and share flows in *StateFlow*([check here](https://github.com/Kotlin/kotlinx.coroutines/issues/1973)) so, hopefully, this will be fixed soon.

🚨 Channels are somewhat equivalents of RxJava Subjects. Previously we could use ConflatedBroadcastChannel instead of BehaviorSubject and BroadcastChannel instead of PublishSubject. But with introduction of StateFlow it comes a bit more interesting, as channels seem not that good (open question). Maybe in the future in the standard library there will be something else for PublishSubject as well.
And yes, this API is experimental, so it can be changed at any time.

🚨 Over time many of theExperimentalCoroutinesApi are promoted to the next level. But now they are FlowPreview which guarantee neither binary nor source compatibility. The simplest examples are debounce and flatMapMerge. They are in preview now. 
So, yes, now you will face fewer ExperimentalCoroutinesApi methods, but still many of them are not stable.
> This is the first adjective that comes to my mind to describe the framework. Creating a Flow instance is super simple:
> *flow { emit("whatever") }*
> That’s it. You don’t have to deal with different methods to create a stream as we have in Rx. You don’t have to think if you have to use *just* , *create,* *defer* or whichever of the [multiple operators](https://github.com/ReactiveX/RxJava/wiki/Creating-Observables) they have.

🚨 Let’s be honest. Kotlin Flow also has flowOf(...), which is essentially same as just in RxJava and might be misused in the same way:

    flowOf(makeNetworkRequest())

🆗 Other than that I agree that writing custom flows (and flow builder is basically the same as using create in RxJava) is simple. But at the same time I think that RxJava version, being probably a bit more verbose, is the same:

    create { it.onNext("whatever") }

Wait, but could one spot the difference? RxJava’s version will remain not completed when Kotlin Flow version will complete at the end.
Everything is simple when you know the details
> Also, flows are always **cold observables** (If you don’t know the difference between a cold and a hot observable you can read it [here](https://github.com/Reactive-Extensions/RxJS/blob/master/doc/gettingstarted/creating.md#cold-vs-hot-observables)). So, you just create a flow and at the moment there is someone observing, it starts to emit.

🚨 So, as a Observable, Flowable in RxJava, so no advantage here
> It’s not only more simple to create observables but also to transform them. In Rx we have operators to work with synchronous and asynchronous operations. For instance, *map* is for synchronous operations, on the other hand, *flatMap* is for asynchronous ones. Because of the fact that all flow operators accept a *suspend* function, all of them are prepared for asynchronous operations. We don’t need both a *map* and a *flatMap* operator, just a *map* one. Another example is the *filter* method which is synchronous in Rx, while the equivalent flow one is asynchronous.

🚨 Let’s try to make that clear: map and flatMap are not for sync/async operations.
> # Map is to transform content of the stream.
> # FlatMap to transform stream.

The most interesting thing is that in opposite it is possible to always use flatMap and not use map, because:

    map(f: (A) -> B) = flatMap { a -> just(f(a)) }

Though in reality flatMap implementation provides more overhead, so use whichever operator is needed in your particular situation. If you want to transform content of the stream — use map.

This is in theory, referencing some functional programming stuff.

🚨 Yes, body of map method in RxJava is called synchronously, but synchronously **on a scheduler **on which current part of the chain is working. So, I see no issue with that.

🚨 In RxJava there are multiple stream types: Single, Completable, Observable etc. So flatMap (with other versions like flatMapSingle) are used to convert some streams to other ones.
Also flatMap allows concurrency (by merging various streams), when map is for different use case.

In Kotlin there is only one stream type: Flow. Instead of Single etc. there are just general suspending functions. And this is exactly why map in Kotlin Flow accepts lambdas with suspend — because somehow () -> T (analog of Single) has to be supported in the chain. flatMap version works with Flow, so it seems there is not much choice.

The issue with having map to accept suspending functions is that now we can do something like this:

<iframe src="https://medium.com/media/dccaf2f325f4efb01fa55c39cf1a42e5" frameborder=0></iframe>

In RxJava we would do something like:

<iframe src="https://medium.com/media/01d78e11d3278c52702c686697c0be14" frameborder=0></iframe>

One might say that RxJava is too verbose. Maybe, but not that is important. In RxJava we have clearly defined that our function hiThere provides a new stream. And like any other stream, it might be subscribed on some different scheduler. This is huge knowledge because from the usage I already know what function can do.
If there would be map — then I’ll understand that there will be just transformation of values (which will be done on the particular scheduler in the chain).

With Kotlin Flow and map accepting suspend it is not that clear. By looking at usage I don’t know whether it is just a stream content transformation or “flatMapping” some suspending “stream type”. I will have to look at the implementation and for me it is a downside.

So, it might be convenient to write code with map accepting suspend, but it should be more difficult to read. And readability is important.
Probably if we had map for content transformation and flatMapSuspend or something like this for suspend-map — it would be better.
But yes “it is too verbose” :)

More on stream types in RxJava and Kotlin Flow one can find here:
[**From RxJava to Kotlin Flow: Stream Types**
*Comparing Stream Types in RxJava and Kotlin Flow*proandroiddev.com](https://proandroiddev.com/from-rxjava-to-kotlin-flow-stream-types-7916be6cabc2)
> You can end up having the same behavior as an Rx operator just **composing suspend methods**. For instance, *interval* is an Rx operator that emits a *Long* every X time ( *Observable.interval(1, TimeUnit.Seconds)* ), you can implement it by composing:

🚨 You’ve created your implementation of the interval operator. The issue is that on many projects there might be different implementations of some simple operators and one will have to dig into each implementation to check how it works. Behavior won’t be documented. It might contain bugs (if one think that it is so simple to write some operator correctly with coroutines — just check the implementations in the standard lib, for example, for [debounce](https://github.com/Kotlin/kotlinx.coroutines/blob/master/kotlinx-coroutines-core/common/src/flow/operators/Delay.kt#L42-L72), which is relatively simple to [write by yourself with Handler](https://proandroiddev.com/decoding-handler-and-looper-in-android-d4f3f2449513))
Common operators in the standard library is a good thing. It unifies behaviors, provides documentation. These methods are used by many people and bugs are filed and hopefully fixed.

And talking about custom operators — it is still possible to write operator in the same way with RxJava create (but beware Thread.sleep — more on that below)
> Another example: In Rx we have *onErrorReturn* and *onErrorResumeNext* to recover from an error and, in flow, we just have the method *catch* instead.

🆗 Half-point goes to Kotlin Flow. Basically as with map/flatMap it is possible to use onErrorResumeNext always. But it provides more overhead, so one can decide. The advantage of Kotlin Flow is that the same operator for different implementations is somewhat equal.

Same time, Kotlin Flow doesn’t have doOnError and one will have to write either own method or do something like:

    .catch { 
        doSomething(it)
        throw it
    }
> Backpressure handling

✅ Good thing is that in Kotlin Flow there is no need to use separate stream type to handle backpressure. Flow by itself supports backpressure.
In RxJava there are Observable which doesn’t support backpressure and Flowable, which does. This is because Flowable is heavier than Observable as backpressure handling adds overhead.
More on this in the article:
[**From RxJava to Kotlin Flow: Backpressure**
*Quick comparison between backpressure solutions in RxJava and Kotlin Flow*proandroiddev.com](https://proandroiddev.com/from-rxjava-to-kotlin-flow-backpressure-d1fb91e6dea8)
> Context preservation

🆗 Nice, but somewhat whatever. Kotlin Flow has just a different approach. I can’t say whether it is better or not for now. I think one can get used to any.
More info on the threading in the article:
[**From RxJava 2 to Kotlin Flow: Threading**
*Comparing threading in RxJava 2 and Kotlin Flow*proandroiddev.com](https://proandroiddev.com/from-rxjava-2-to-kotlin-flow-threading-8618867e1955)
> Lifetime

✅ The fact that coroutines (and therefore Flow) can be launched/collected only in some particular scope — is good, because the compiler won’t allow you to make mistake and launch coroutine without some scope.

🚨 But regarding viewModelScope for coroutines: it is possible to make something similar for RxJava as well. Android Jetpack team just invests time into coroutines support and not RxJava.

<iframe src="https://medium.com/media/3a8ab29e35384265868cb86f25e428d8" frameborder=0></iframe>

Of course, this won’t enforce you to add all your subscriptions that way. One might set up custom lint rule for that or so, though it wouldn’t be trivial.
> According to this [github project](https://github.com/Kotlin/kotlinx.coroutines/tree/master/benchmarks/src/jmh/kotlin/benchmarks/flow/scrabble) Flow is a little bit **faster** than Rx

🆗 Let’s add that as a plus. Though everyone should have a cold head thinking about benchmarks
> You don’t need other external libraries than the *kotlinx-coroutines-core*one, the **stable version** of Flow was released in the *1.3.0* version.

🚨 In RxJava one can add also only one library and it is stable-stable.

🚨 Only some parts (core) are stable in Flow. Many operators are in preview or experimental, but we’ve already discussed that.

## What was missing

There are few things that in my opinion were missing from the list of the advantages of Kotlin Flow:

* ✅ Flow is based on coroutines so the execution is suspending and not blocking. That allows one to write some custom operators using delay instead of Thread.sleep. It might have a big impact as if you do some blocking sleep on computation thread pool you are effectively blocking other tasks from running

* ✅ As Flow is based on coroutines which are multiplatform compatible — it is possible to use them in multiplatform projects. One can’t use RxJava for that. There are other options like [Reaktive](https://github.com/badoo/Reaktive) though.

* ✅ One can pass nullable values in the Flow. There is no need to wrap values in Option as in RxJava

## Conclusion

Let’s sum up the real advantages of Kotlin Flow over RxJava are:

* ✅ Multiplatform support

* ✅ Suspending execution

* ✅ No separate stream type for backpressure support. Flow has built-in backpressure support out of the box (because of suspension)

* ✅ Enforcement to be collected in the coroutine scope (no leaked streams)

* ✅ Nullability support

* 🆗 Writing custom flows/operators is simpler

* 🆗 Less cognitive load when for more use-cases there is single operator which covers all when in RxJava there are different versions (usually because of optimizations).

* 🆗 Context preservation

* 🆗 Seems they are faster and have less memory consumption. But we should understand that benchmarks are benchmarks.

Though this article is about advantages, it is required in my opinion to always add downsides to make a picture more clear.

* 🚨 Flow itself is stable. But operators, channels, etc might be missing, in preview or experimental. Keep that in mind

* 🚨 Coroutines are more complex than RxJava. Because RxJava is written in Java with threads. These topics are discussed widely, there are articles, books, etc. If one faced some issue — it is easy to debug, look at sources, and so on. With coroutines and flow we still are in the process of generating information and sharing it. Debugging is still difficult. Code generated by compiler even can’t be decompiled which makes it difficult to analyze.

* 🚨 Kotlin Flow has fewer operators than RxJava in the standard library. But I guess it is a matter of time.

In my opinion in the coming years we’ll get used to Kotlin Flow and most likely new projects will be written using it not RxJava. Though there is little gain to rewrite existing apps to Kotlin Flow. At least now. But right now is the best time to start learning and trying on your pet projects maybe.

Happy coding!

*Thanks for reading!
If you enjoyed this article you can like it by **clicking on the👏 button** (up to 50 times!), also you can **share **this article to help others.*

*Have you any feedback, feel free to reach me on [twitter](https://twitter.com/krossovochkin), [facebook](https://www.facebook.com/vasya.drobushkov)*
[**Vasya Drobushkov**
*The latest Tweets from Vasya Drobushkov (@krossovochkin). Android developer You want to see a miracle, son? Be the…*twitter.com](https://twitter.com/krossovochkin)
