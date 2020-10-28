+++
title = "Middle Point"
date = "2020-10-28"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["programming", "middle point", "overflow"]
keywords = []
description = ""
showFullContent = false
+++

### Introduction

Working with numbers in programming never was a simple thing. In math, we deal with various sets of numbers - whole numbers, rational, complex. All these sets are infinite - that means that for any number we can find another smaller one and one which is bigger. In programming when we work with numbers we deal with some subset of these sets - that many that can be represented with a given amount of bits.
When we want to work with whole numbers we can use e.g. Integer, which are the numbers being able to be represented usually with 4 bits. For floating-point numbers - say Double - it is 8 bits. There is no plus or minus infinity (in Double there are +/- infinity, though they are used for special cases).

Let's look at a simple problem: given start and end number - calculate number which is in the middle. That means that we need to find such a number, which distance both to start and end will be the same.  
In math this is a simple problem: `(a + b) / 2` is the number. Let's look at what difficulties we'll face while writing such a program.  
We'll start with Integers first and then take a look at floating-point numbers.

### Design API

We'd like to have a function that takes two numbers as parameters returning the middle point as a result. That means that for Integers we might have:
```kotlin
fun middle(start: Int, end: Int): Int
```
For Double:
```kotlin
fun middle(start Double, end: Double): Double 
```
And in general, if we would like to work with any number:
```kotlin
fun middle(start: Number, end: Number): Number
```

### Analyze solution existence

As said before - we're dealing with a subset of numbers in programming. Therefore the first question we'd like to answer is whether we'll have a solution for any given set of numbers.  
Here we have three situations:
- start is greater than the end. We can safely assume that start should not be greater than the end. In such a case no solution exists, because our logical rule is broken. That means that here we can throw an exception.  
Let's write a test for this:
```kotlin
@Test(expected = IllegalArgumentException::class)
fun `if start greater than end then throws exception`() {
	middle(5, 4)
}
```
- start is equal to end. In such a case middle both points are in the same place - and the middle will be there as well. Therefore we can return either start or end as a result.  
This can be handled by this test case:
```kotlin
@Test
fun `if start == end then start`() {
	assertEquals(5, middle(5, 5))
}
```
- start is less than the end. Here we can apply our general logic of calculating the middle point.

With this our initial setup for a function will be:
```kotlin
fun middle(start: Int, end: Int): Int {
	if (start > end) throw IllegalArgumentException()
	if (start == end) return start
	...
}
```

### Integer naive approach

An additional case which we should cover with Integer numbers is a case when we have two numbers with odd distance. Assume we have `start = 3` and `end = 6`. The correct middle point here would be `4.5`. But it is not possible to represent such a number as Integer.  
To cover that case we'll introduce an exception - in such cases we'll return closest smaller to the real middle point number.  
This will be covered with: 
```kotlin
@Test
fun `if distance is odd then returns closest smaller`() {
	assertEquals(4, middle(3, 6))
}
```

For any other pair of points, we'll be able to have a solution. If `start` and `end` can be represented as Integers (they are in the subset of whole numbers which can be represented as Integer) middle point will be between them and that means solution also will be represented as Integer without issues.

The naive approach would be to apply our math knowledge, we'll write our function body:
```kotlin
fun middle(start: Int, end: Int): Int {
	...
	return (start + end) / 2
}
```

But this would be incorrect because if `start = 1` and `end = Int.MAX_VALUE` then `start + end` overflows and the result will be negative.  

### Integer handling overflow

That means that whenever we design a function that works with numbers, we need to consider that not all whole numbers can be represented as Integer. Specifically, we need to carefully take a look at boundaries.  
For handling this there is a good trick:
```
(a + b) / 2 = a / 2 + b / 2 = a - a / 2 + b / 2 = a + (b - a) / 2
```
With a simple trick, we now avoid the sum of big numbers therefore our case with `start = 1` and `end = Int.MAX_VALUE` now works correctly. So, our function will be:
```kotlin
fun middle(start: Int, end: Int): Int {
	...
	return start + (end - start) / 2
}
```
But now we have subtraction, which means we need to pay attention to `Int.MIN_VALUE` as well. What if we have `start = Int.MIN_VALUE` and `end = 5`. Now we have an overflow again.

After considering all of this we come up with a solution: depending on whether start and end have same sign or different, we'll use different formula. And the function will be:
```kotlin
fun middle(start: Int, end: Int): Int {
    return when {
        start > end -> throw IllegalArgumentException()
        start == end -> start
        start < 0 && end > 0 -> (start + end) / 2
        else -> start + (end - start) / 2
    }
}
```

And the set of tests:
```kotlin
@Test
fun `if start greater than 0 and end greater than 0 and no overflow`() {
	assertEquals(6, middle(1, 11))
}

@Test
fun `if start greater than 0 and end greater than 0 and has overflow`() {
	assertEquals(Int.MAX_VALUE - 1, middle(Int.MAX_VALUE - 2, Int.MAX_VALUE))
}

@Test
fun `if start less than 0 and end less than 0 and no overflow`() {
	assertEquals(-6, middle(-11, -1))
}

@Test
fun `if start less than 0 and end less than 0 and has overflow`() {
	assertEquals(Int.MIN_VALUE + 1, middle(Int.MIN_VALUE + 1, Int.MIN_VALUE + 2))
}

@Test
fun `if start less than 0 and end greater than 0 and no overflow`() {
	assertEquals(1, middle(-4, 6))
}

@Test
fun `if start less than 0 and end greater than 0 and has overflow`() {
	assertEquals(-1, middle(Int.MIN_VALUE, Int.MAX_VALUE - 1))
}
```

Not as simple as was at first thought.

### Double naive approach

Now let's look at Double. Here we can be sure that we'll be able to represent the result correctly for the case when the middle point can't be represented as an Integer because of the decimal part.

Let's just copy-paste our function changing Int to Double:
```kotlin
fun middle(start: Double, end: Double): Double {
    return when {
        start > end -> throw IllegalArgumentException()
        start == end -> start
        start < 0 && end > 0 -> (start + end) / 2
        else -> start + (end - start) / 2
    }
}
```

Are we good? Not really. With floating-point numbers, one should work carefully because of precision. While with Integers it is not possible to represent numbers less than `Int.MIN_VALUE` and greater than `Int.MAX_VALUE` and points in between two closest Integer values, with doubles we might not preserve exact numbers in between two points with the required precision.

Consider the following test:
```kotlin
@Test
fun `double inexact`() {
	assertEquals(0.45, middle(0.3, 0.6), 1.0e-17)
}
```
The solution should be `0.45`, but after math applied to Double numbers, there might be an error. And instead of `0.45`, we'll get `0.44999999999999`. That is why when doing a comparison we have to add precision. If we take say `1.0e-16` - test passes. But if we take `1.0e-17` - it fails, because the result can be represented with the required precision. This is something we should be aware of. Our function will return the best possible result.

### Double infinity

With Double, we not only have `Double.MIN_VALUE` and `Double.MAX_VALUE`. Also, we have `Double.NEGATIVE_INFINITY` and `Double.POSITIVE_INFINITY`. These are special values and let's look at how our implementation works with them.  
But first, let's think about the expected results.

We might say that if start or end is represented as infinity then the result is unknown. We don't know how far we can go with either. So, the simplest thing we can do is to check for these values and, for example, throw an exception.  
But also we can do some additional calculations.  
For example, if we have `start = Double.NEGATIVE_INFINITY` and `end = Double.NEGATIVE_INFINITY`? Our start and end both the same, so it feels that we can return `Double.NEGATIVE_INFINITY` as a result. Same for `Double.POSITIVE_INFINITY`. And this case is already covered by our check for `start == end`.

What about one number is infinity and another is not? Can we assume that result should be infinity as well? I guess so. Because whatever we sum with infinity - the result will be infinity again.

And what about the case when `start == Double.NEGATIVE_INFINITY` and `end == Double.POSITIVE_INFINITY`? Here the result is undefined. We don't know what is bigger - negative infinity or positive infinity. We could speculate that result should be `0`. And probably it is up to a designer of the method. I think that in such a case it is better to throw an exception.

And our set of tests is now should have:
```kotlin
@Test(expected = IllegalArgumentException::class)
fun `double start is negative infinity and end is positive infinity then throws exception`() {
	middle(Double.NEGATIVE_INFINITY, Double.POSITIVE_INFINITY)
}

@Test
fun `double start is negative infinity and end is not infinity then negative infinity`() {
	assertEquals(Double.NEGATIVE_INFINITY, middle(Double.NEGATIVE_INFINITY, Double.MAX_VALUE), 1.0e-16)
}

@Test
fun `double start is not infinity and end is positive infinity then positive infinity`() {
	assertEquals(Double.POSITIVE_INFINITY, middle(Double.MIN_VALUE, Double.POSITIVE_INFINITY), 1.0e-16)
}

@Test
fun `double start == end == negative infinity then negative infinity`() {
	assertEquals(Double.NEGATIVE_INFINITY, middle(Double.NEGATIVE_INFINITY, Double.NEGATIVE_INFINITY), 1.0e-16)
}

@Test
fun `double start == end == positive infinity then positive infinity`() {
	assertEquals(Double.POSITIVE_INFINITY, middle(Double.POSITIVE_INFINITY, Double.POSITIVE_INFINITY), 1.0e-16)
}
```

And our fixed solution for Double now looks like:
```kotlin
fun middle(start: Double, end: Double): Double {
    return when {
        start == Double.NEGATIVE_INFINITY && end == Double.POSITIVE_INFINITY -> throw IllegalArgumentException()
        start > end -> throw IllegalArgumentException()
        start == end -> start
        start < 0 && end > 0 -> (start + end) / 2
        else -> start + (end - start) / 2
    }
}
```

### Double NaN

There is yet another special value in Double - `Double.NaN`. Here the solution is simple: if either start or end is `Double.NaN` then we should throw an exception, as we can't calculate the result.

We add two more test cases:
```kotlin
@Test(expected = IllegalArgumentException::class)
fun `start == NaN then throws exception`() {
	middle(Double.NaN, 1.0)
}

@Test(expected = IllegalArgumentException::class)
fun `end == NaN then throws exception`() {
	middle(1.0, Double.NaN)
}
```
And adjust our function to handle that:
```kotlin
fun middle(start: Double, end: Double): Double {
    return when {
        start.isNaN() -> throw IllegalArgumentException()
        end.isNaN() -> throw IllegalArgumentException()
        start == Double.NEGATIVE_INFINITY && end == Double.POSITIVE_INFINITY -> throw IllegalArgumentException()
        start > end -> throw IllegalArgumentException()
        start == end -> start
        start < 0 && end > 0 -> (start + end) / 2
        else -> start + (end - start) / 2
    }
}
```

One thing to note is that it is tempting to make a comparison with `start == Double.NaN`, but it would be a mistake.  
If we look at implementation of `isNan` method, we'll see the following:
```java
public static boolean isNaN(double v) {
	return (v != v);
}
```
`Double.NaN` is not equal to itself, so `start == Double.NaN` would be incorrect.

> With Double it is possible to not throw an exception but instead in exceptional cases return `Double.NaN`. It is again totally acceptable and depends on the API designer's decision.

### Number

Let's say we'd like to write a general function for any Number. We have various options:
- create a separate option for any type of Number (though we wouldn't handle the case with some third party implementations). This way we will check the type of provided number and choose the correct function with some fallback (probably Double or BigDecimal)
- create a single version which under the hood will use the broadest type - say BigDecimal. Then the client will convert the result to the required Number implementation. This will give us a single method, though it will be heavier in terms of resources.

For simplicity, let's go with the second option.

Here we can apply just something like:
```kotlin
fun middle(start: Number, end: Number): Number {
    if (start == end) {
        return start
    }
    val a = start.toString().toBigDecimal()
    val b = end.toString().toBigDecimal()

    return when {
        a > b -> throw IllegalArgumentException()
        a < BigDecimal.ZERO && b > BigDecimal.ZERO -> (a + b) / 2.toBigDecimal()
        else -> a + (b - a) / 2.toBigDecimal()
    }
}
```
First, we'll check for our initial equality to avoid redundant conversion.
Then we first convert numbers to string and then to BigDecimal. We do that to avoid losing information.
Finally, we have our usual checks. Thanks to Kotlin operator overload it looks pretty well with `+` instead of `plus`.

### Conclusion

In this article, I wanted to show two things. First, that math as we study it at university and math in programming are two different things. In programming, we face additional limitations that we can't ignore. Second that even some small and simple functions require thorough API design. Depending on what our goal is, what constraints we have, how we'd like to approach the corner and exceptional cases (fail fast or continue gracefully) we'll have different results.  
Pay attention to details, apply as much care to the system and its smaller parts.

Happy coding.