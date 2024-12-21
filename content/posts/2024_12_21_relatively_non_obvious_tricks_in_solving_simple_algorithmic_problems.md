+++
title = "Relatively Non-Obvious Tricks in Solving Simple Algorithmic Problems"
date = "2024-12-21"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["other"]
keywords = ["algorithms", "interview", "programming", "coding task"]
description = ""
showFullContent = false
+++

# Relatively Non-Obvious Tricks in Solving Simple Algorithmic Problems  

Blowing the dust off LeetCode once again, I found myself, as in the [past](https://krossovochkin.com/posts/2019_09_27_random_interview_coding_task_retrospective/), struggling with coding relatively simple algorithms. Just like with anything else, if you don’t practice for years, you lose some of the hands-on experience.  

On the positive side, I noticed that for some problems, my new submissions were much better and more concise compared to my old ones. That’s an awesome feeling—a tangible measure of growth.  

While tackling certain easy problems, I realized that "easy" usually just means "doesn't require much code." However, the idea behind the optimal solution might still not be very intuitive. Sure, one can use brute force or additional collections, but in most cases, this leads to either a "time limit exceeded" or an "out of memory" error.  

In this article, I’d like to walk through a few examples and provide simple, intuitive proofs for why these solutions work. It’s surprising how many resources focus on implementation while barely explaining why the algorithms work.  

---

## Detect Whether a Singly Linked List Contains a Loop  

[LeetCode](https://leetcode.com/problems/linked-list-cycle/)

This is a classic problem with a two-pointer solution. We initialize a slow and a fast pointer at the beginning of the list. The slow pointer moves one step at a time, while the fast pointer moves two steps at a time.  

- If the fast pointer reaches the end of the list, there is no loop. (If a loop existed, the list wouldn't have an "end.")  
- If the slow and fast pointers meet at some point, there is a loop.  

But why can we guarantee that the pointers will meet if there is a loop?  

The answer lies in the fact that at each iteration, the distance between the slow and fast pointers increases by one. Eventually, both pointers will be inside the loop. Once they’re in the loop, the distance between them decreases by one on each iteration. Therefore, they are guaranteed to meet.  

---

## Find the Majority Element in an Array  

[LeetCode](https://leetcode.com/problems/majority-element/)

To solve this, we iterate through the array once using a counter that starts at zero.  

- If the counter is zero, we set the current element as the candidate.  
- If the counter is non-zero, we check whether the current element matches the candidate: if it does, we increment the counter; if not, we decrement it.  

By the end, the candidate will be the majority element.  

The trickiest part of this solution is understanding why it works. The key is the definition of a majority element: it appears in the array more than half the time. This gives the array an interesting property:  

- If you remove two different numbers (one majority and one non-majority, or two non-majority), the majority element’s frequency remains unaffected.  

We don’t explicitly remove pairs, but the counter emulates this.  
- Incrementing the counter corresponds to finding the same number again.  
- Decrementing corresponds to encountering a different number.  
- Resetting the counter to zero means we’ve found some number of pairs of different numbers that we can remove or ignore and start over.  

Finally, the majority element’s count minus the count of all other elements will always be positive, ensuring that the algorithm identifies it correctly.  

---

## Climbing Stairs  

[LeetCode](https://leetcode.com/problems/climbing-stairs/)

You’re given a staircase, and on each step, you can climb one or two stairs. You need to calculate how many distinct ways you can reach the top.  

At first, this problem seems confusing. Then, realizing the solution involves the Fibonacci sequence might make it seem even more mysterious.  

Here’s why:  

When you're on the i-th step, there are only two ways to get there:  
1. From the i-1-th step by taking one step.  
2. From the i-2-th step by taking two steps.  

Thus, the number of ways to reach the i-th step is simply the sum of the ways to reach the i-1-th and i-2-th steps. That’s exactly the definition of the Fibonacci sequence.  

With this induction step established, all we need are the base cases:  
- There’s only one way to reach the first step.  
- There are two ways to reach the second step (1+1 or 2).  

And that’s it.  

---

## Maximum Subarray Sum  

[LeetCode](https://leetcode.com/problems/maximum-subarray/)

This problem asks us to find the maximum sum of a subarray. Brute-forcing through all subarrays would be too slow, so we use a linear-time solution with constant memory.  

We maintain two variables:  
1. **`currentSum`**: Keeps track of the running sum.  
2. **`maxSum`**: Stores the highest sum found so far.  

At each step:  
- If `currentSum` is positive, we add the next item to it.  
- If `currentSum` is negative, we discard it and start over from the next item.  

Why does this work?  

- If all elements are non-negative, the max sum is simply the sum of all elements. The algorithm handles this well, as `currentSum` never becomes negative.  
- If all elements are negative, the max sum is the largest single element. The algorithm also handles this correctly, as `currentSum` resets for each element, ensuring `maxSum` stores the largest value.  
- In mixed cases, when `currentSum` becomes negative, discarding it is safe because adding any element to a negative sum would result in a smaller value than just starting fresh.  

---

And that’s it for this time.  

Happy coding!

