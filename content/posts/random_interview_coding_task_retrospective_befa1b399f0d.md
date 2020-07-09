+++
title = "Random interview coding task retrospective"
date = "2019-09-27"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["java", "coding task"]
keywords = []
description = ""
showFullContent = false
+++

> [![](https://img.shields.io/badge/original-medium-green)](https://medium.com/@krossovochkin/random-interview-coding-task-retrospective-befa1b399f0d)

# Introduction

It happens often that on interviews you’ve asked to perform some coding task. For unknown reason most of the times you’ve asked to write some code not in the IDE, but on piece of paper. I don’t like such tasks on an interview, because in real life one won’t write any kind of code on a paper. If you need to write something not in IDE you face issues like you can’t quickly change something or write new code in between the lines. You don’t get suggestions or autocomplete. Basically, you are out of you zone of comfort. Considering that interview by itself is a stress (no matter how confident you are in your knowledge) you might not complete the task successfully.
But anyway such tasks are pretty common so one should be prepared for them.

I’ve been on an interview recently and had to write some algorithm implementation. Though I’m professional developer for quite some time my (general) programming skills are not that great (shame on me). In real life you rarely need to implement some algorithms by yourself, instead abstract thinking seems more valuable. And if you don’t do something for some time, you start to forget things pretty fast. I wasn’t prepared enough therefore I failed, but it is not what I’d like to talk about.

Here I’d like to revisit the task, complete it and make some conclusions

## The task

The task is pretty simple. There is singly linked list represented as head node. It is required to reverse it.

The algorithm should be the following:

* Take first item in the list (it has pointer to the next item)

* Make next item to point to the first item

* Make first item to point to the previous item (if exists)

* Repeat till the end of list

## Prerequisites

List is described as a Node:

```kotlin
class Node<T>(
    val value: T,
    var next: Node<T>?
)
```

## Solution

### Before start

We’ll start from clarifying some questions:

* List can be quite long, so we should not use some intermediate data structures like temp lists to copy data there

* List cannot be null, we always have head

* List might contain one item, in that case reversed list will be the same as original one

* Algorithm should be quite fast, the expected complexity should be linear (that means we should iterate through the list once)

### Construction

Before reversing the list we should be able to construct it first.
We’ll do it the following way:

```kotlin
Node(1, Node(2, Node(3, Node(4, Node(5, Node(6, Node(7, Node(8, Node(9, Node(10, null))))))))))
```

It will describe the list of 10 items.

For test and debug purposes we might want to print our list to console, for that following function will be helpful:

```kotlin
private fun <T> println(list: Node<T>) {
    var currentNode: Node<T>? = list
    while (currentNode != null) {
        print("${currentNode.value} ")
        currentNode = currentNode.next
    }
    println()
}
```

The output for our created list will be:

```
1 2 3 4 5 6 7 8 9 10
```

### Method signature

The method we’ll implement will have the following signature:

```kotlin
fun <T> Node<T>.reverse(): Node<T>
```

It will modify existing list, not create new one.

### Tests

In order to verify our solution, we should have some tests.
This task will be split into two parts.
First of all we need to be able to compare two lists, for this we’ll create method assertEquals, it will throw exception if lists don’t have equal content:

```kotlin
fun <T> assertEquals(expected: Node<T>, actual: Node<T>) {

    var first: Node<T>? = expected
    var second: Node<T>? = actual

    while (first != null && second != null) {
        if (first.value != second.value) {
            throw RuntimeException()
        }
        first = first.next
        second = second.next
    }

    if (first?.value != second?.value) {
        throw RuntimeException()
    }

    println("OK")
}
```

The tests we’ll make are:

* If list has one item, then reversed list is same as original

* If list has more than one item, then reversed list is reversed correctly

```kotlin
assertEquals(
    Node(1, null),
    Node(1, null).reverse()
)


assertEquals(
    Node(10, Node(9, Node(8, Node(7, Node(6, Node(5, Node(4, Node(3, Node(2, Node(1, null)))))))))),
    Node(1, Node(2, Node(3, Node(4, Node(5, Node(6, Node(7, Node(8, Node(9, Node(10, null))))))))))
        .reverse()
)
```

Now we have our list implementation ready, algorithm is clear and tests are ready as well.

### First implementation

The main challenge in this task is that when we change links (current node should point to previous one and next one should point to current one) is that we should not loose the track of Node which is next for our next node. We’ll solve that by keeping reference to the node which is next of the next node.
The implementation will be like this:

```kotlin
fun <T> Node<T>.reverse(): Node<T> {
    var previousNode: Node<T>? = null
    var currentNode: Node<T> = this
    var nextNode: Node<T>? = currentNode.next

    while (nextNode != null) {
        val afterNextNode = nextNode.next

        nextNode.next = currentNode
        currentNode.next = previousNode

        previousNode = currentNode
        currentNode = nextNode
        nextNode = afterNextNode
    }

    return currentNode
}
```

We run our tests and they pass! So we solve the problem.
But can we do better?

### Second implementation

The issue with current implementation is that we actually use 4 pointers to the list (previous, current, next, afterNext) to reverse the list. But can we do same with only 3 pointers?

If we look carefully at our implementation we’ll see that we basically look one item ahead. And we can use 3 pointers by moving our pointers 1 step behind.
We’ll get rid of afterNextNode pointer and replace references of nextNode to currentNode and currentNode to previousNode.

The solution will be like:

```kotlin
fun <T> Node<T>.reverse(): Node<T> {
    var previousNode: Node<T>? = null
    var currentNode: Node<T>? = this
    var nextNode: Node<T>?

    while (currentNode != null) {
        nextNode = currentNode.next
        currentNode.next = previousNode

        previousNode = currentNode
        currentNode = nextNode

    }

    return previousNode!!
}
```

> NOTE: we use !! in the return, because actually we know that result will be non-null and we don’t want to make our implementation more complex by using unnecessary safe calls

So we used only three pointers and the implementation is quite short. Tests are passed. So seems we’re fine.
But can we do better?

### Final implementation

The last improvement we might do is to handle special case when list contains only one item. Currently if list has one item then we’ll still enter while loop and use few references.
Let’s add additional check at the beginning:

```kotlin
fun <T> Node<T>.reverse(): Node<T> {
    if (this.next == null) {
        return this
    }

    var previousNode: Node<T>? = null
    var currentNode: Node<T>? = this
    var nextNode: Node<T>?

    while (currentNode != null) {
        nextNode = currentNode.next
        currentNode.next = previousNode

        previousNode = currentNode
        currentNode = nextNode

    }

    return previousNode!!
}
```

And it is our final solution.

## Conclusion

Interviews are difficult and always stressful. One can easily make some weird mistakes, not answer some questions or not solve some problems and one can be not prepared enough.
But it is not that embarrassing to not answer/know something. It is embarrassing to not draw conclusions and not try to revisit the questions/tasks you’ve failed and learn from your mistakes.

Happy learning.
