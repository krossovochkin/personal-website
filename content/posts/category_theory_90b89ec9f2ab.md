+++
title = "Category theory"
date = "2020-04-26"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = []
keywords = []
description = "Short synopsis on lectures about Category theory and programming"
showFullContent = false
+++

![[Source](https://unsplash.com/photos/5mZ_M06Fc9g)](https://cdn-images-1.medium.com/max/2000/0*jmBKs8ZyL7WkG5op)*[Source](https://unsplash.com/photos/5mZ_M06Fc9g)*

## Disclaimer

This is short synopsis of great [set of lectures](https://www.youtube.com/playlist?list=PLbgaMIhjbmEnaH_LTkxLI7FMa2HsnawM_). What is written here is by no means true, one should refer to original lectures or some books etc. This is written mostly for myself in case I wanted to revisit the topic in the future.
Everything below is not “what it is” but mostly “how I understood that”. So, there might be mistakes and so on.

## Category

Category consists of:

* objects / dots (a, b, c, …)

* morphisims / arrows (f, g, …).

![morphism from a into b, connects two objects](../../img/1_vxo6VwCrQFO4MCF-BkvWBg.png)*morphism from a into b, connects two objects*

* composition

![apply g after f](../../img/1_UaMI_UNLIcE_3IqSPLl9Gw.png)*apply g after f*

And should:

* be associative:

![Order of composition doesn’t matter](../../img/1_YMnV0zJ_i4hGz3xV-x-A0w.png)*Order of composition doesn’t matter*

* have identity morphism

![There is an arrow to itself](../../img/1_qAsvwgQvdeNyK5Mw8l2g-Q.png)*There is an arrow to itself*

## Category examples

### Category 0 (empty)

* no objects

* no morphisms

### Category 1 (singleton)

* 1 object

* 1 identity morphism

![](../../img/1_cXZ14CRmpPql2jnBe2MTkw.png)

### Category with 2 objects and 1 morphism

* 2 objects

* 1 morphism from one object to another

* 2 identity morphisms

![Applying identity morphisms to any morphism is equivalent to that morphism itself](../../img/1_L-hA-0ipk7CDsbqxmNp7Aw.png)*Applying identity morphisms to any morphism is equivalent to that morphism itself*

![](../../img/1_tmd5NfDhrt4A39vQVHJ1_Q.png)

## Universal construction

* identify pattern

* define ranking

* define best

## Iso- / mono- / epi- morphisms

### Isomorphism

![f is isomorfism](../../img/1_1FkUip712csmYoyqAH779g.png)*f is isomorfism*

![Isomorphic implies inverse morphism](../../img/1_k-3eIAYBfxFITeTcXa-FSw.png)*Isomorphic implies inverse morphism*

### Injective / monic / monomorphism

![f is monomorphism](../../img/1_U72imb-phjN9Kh2bfWs6Xg.png)*f is monomorphism*

![](../../img/1_Z69JE9wP87ac7jPrHLYaHQ.png)

![](../../img/1_-w2j8iV2FxqYycpq9niEEg.png)

### Surjective / epic / epimorphism

![](../../img/1__xSRGNDwNWxxAnY3XT-YiA.png)

![](../../img/1_9FxzzjrfAIVIjBKzVzNOHw.png)

## Order relation

![](../../img/1_eqC3PHe39Ipv4j6xMSnmSw.png)

**Hom-set** — set of all arrows from a to b.

### Pre-order

Hom-set is either empty or singleton. Can contain loops.

**Example**: “less or equal” order relation.

![All these arrows can hold, and there is a loop between a and b](../../img/1_rQqZFEhGVYHSlT4dwGdRyQ.png)*All these arrows can hold, and there is a loop between a and b*

### Partial order

Pre-order without loops.

**Example**: “less” order relation.

### Total order

All objects have relations

## Monoid

Category with 1 object and many morphisms from that object to itself.

Hom-set: M(m, m) — set of all arrows.

## Terminal and initial objects

Terminal object — object to which there is arrow from any other object in category.

Initial object — object from which there is an arrow to any other object in category.

Opposite category is a category with “reversed arrows”. Terminal object is initial in opposite category.

![](../../img/1_Ik063rWKn83MKf5DtNaW6g.png)

## Product

![](../../img/1_nQYjIeS4F1U6khncbA_iPg.png)

![](../../img/1_eBLG2zNefFPGruaVzt5feg.png)

c is a better product than c’ (in terms of order relation)

p, q — projections

Product in programming is a Pair:

    data class Pair<A : Any, B : Any>(
        val fst: A,
        val snd: B
    )

## Sum (Co-Product)

Similar to Product, with reversing arrows

![](../../img/1_B_rc892rxarA_1LngmY2Tg.png)

i, j — injections

![](../../img/1_-jgL9B9Y4J3cC9MPjgKuqw.png)

In programming it can be described as Either:

    class Either<A: Any, B: Any> 
    private constructor(private val a: A?, private val b: B?) {

    companion object {
            
            fun <A: Any, B: Any> left(a: A): Either<A, B> {
                return Either(a, null)
            }
            
            fun <A: Any, B: Any> right(b: B): Either<A, B> {
                return Either(null, b)
            }
        }
    }

## Algebraic Data Types

### Product

* symmetry

![](../../img/1_mGiselFmo3hhlQJ3TWzIZg.png)

* associativity

![](../../img/1_NuZzCT3r5HEYTScfq_dOQQ.png)

* identity

![](../../img/1_-IP6AA2YJcjsCIzz9KYYuQ.png)

### Sum

* symmetry

![](../../img/1_tyv7Db85iHciV4bnG-_ewA.png)

* associativity

![](../../img/1_hrTRzIIRUv7xoYlD5cAS_g.png)

* identity

![](../../img/1_bBiqTfo1TLdwJyQ_tTo3pw.png)

### Product and Sum

* distribution

![](../../img/1_D8HH32BNRWFqUPEk4cazwQ.png)

* annihilation

![](../../img/1_EpM_l4OkrNu0mNp071plIg.png)

### Semiring

With defined product and sum (without inverse operations) we get Semiring.

### Example 1 Boolean

![](../../img/1_rlkMkqjrELV5sjgwNCRwtQ.png)

### Example 2 Option

![](../../img/1_z1K17gzrVlgKA2UTxaPnfA.png)

### Example 3 List

![](../../img/1_XcLRCi2JXfhWbCKi08Y0Bg.png)

## Functor

Functor — mapping from one category to another with preserving structure.
Objects are mapped into objects, morphisms into morphisms.
Preserving structure means that composition and identity is preserved.

Functor can be though as a container.

![](../../img/1_LhJ2EuXv-tfhns2OJV1qcg.png)

![](../../img/1_38gKpYfFSCtJ9zpNx7Ih0Q.png)

### Special Types of Functors

* Faithful — injective on all hom-sets

* Full — surjective on all hom-sets

* Constant Δc — functor which maps all objects into single object c and all morphisms into single morphism idc

* Endofunctor — functor from one category to the same category

### Example 1 Option

* mapping objects

![](../../img/1_-IhkVFu-BkEMZb8Q3zNuPw.png)

* mapping morphisms

![](../../img/1__3YXmXq5buqzlT02364u9A.png)

* preserve identity

![](../../img/1_uj1n7ybjBxLl-WToWWcrrg.png)

* preserve composition

![](../../img/1_-j4to1UPQXEq1u_37_Am5A.png)

### Example 2 List

* mapping objects

![](../../img/1_0GRi_LQ2ZGuFyYj0ukE4rA.png)

### Functor in programming

    interface Functor<A> {
        fun <B> map(f: (A) -> B): Functor<B>
    }

## BiFunctor

### Cat

Cat — category of categories

* objects are categories

* morphisms are functors

### Product Category

![](../../img/1_MLfp45tqd4MpxVHgU9llzA.png)

### BiFunctor

BiFunctor is mapping from product category into another category.

![](../../img/1_BFDOC6tf_MK5g-nv807qew.png)

Sum is also a BiFunctor

### BiFunctor in programming

    interface Bifunctor<A : Any, B: Any> {
        
        fun <C : Any> first(f: (A) -> C): Bifunctor<C, B>
        
        fun <D : Any> second(f: (B) -> D): Bifunctor<A, D>
        
        fun <C : Any, D : Any> bimap(f: (A) -> C, g: (B) -> D): Bifunctor<C, D>
    }

## ProFunctor

### ADT construction via composition

Constant Functor

    data class Const<C : Any, A : Any>(val c: C): Functor<A> {
        
        override fun <B : Any> fmap(f: (A) -> B): Const<C, B> {
            return Const<C, B>(c)
        }
    }

Identity Functor

    data class Just<A : Any>(val a: A) : Functor<A> {
        
        override fun <B : Any> fmap(f: (A) -> B): Just<B> {
            return Just(f(a))
        }
    }

Maybe via composition

    class Maybe<A> = Either(Const<Unit, A>, Identity<A>)

Either is a BiFunctor, Const and Identity are Functors.

### ProFunctor

ProFunctor — mapping from product of category with its opposite category to that category.

![](../../img/1_Dx_0cWCqBxz0fOw0huWfaQ.png)

    interface Contravariant<A : Any> {
        
        fun <B : Any> contramap(f: (B) -> A): Contravariant<B>
    }

### ProFunctor in programming

    interface Profunctor<A : Any, B : Any> {
        
        fun <C : Any> lmap(f: (C) -> A): Profunctor<C, B>
        
        fun <D : Any> rmap(f: (B) -> D): Profunctor<A, D>
        
        fun <C : Any, D : Any> dimap(f: (C) -> A, g: (B) -> D): Profunctor<C, D>
    }

## Functions/exponentials

### Currying

![](../../img/1_zmol75zV_8iq_yG9uefetw.png)

![](../../img/1_bMFEOWT0euDcq8PRCWUUdA.png)

    fun <A, B, C> curry(f: (Pair<A, B>) -> C): (A) -> ((B) -> C)
    fun <A, B, C> uncurry(f: (A) -> ((B) -> C)): (Pair<A, B>) -> C

### Cartesian Closed Category (CCC)

Category is CCC if it has:

* product

* exponential

* terminal object

### Exponential

![](../../img/1_dX6fZ7x_nL4KDbb_7449rg.png)

### Examples

![](../../img/1_LoSOZ8oAa51jc0klrbBnnw.png)

### Proposition of types / Curry-Howard-Lambok isomorphism

![](../../img/1_HISxOm1Nypn56xnFgFkb9Q.png)

## Natural transformation

Natural transformation — mapping between Functors (or objects to morphisms).

![Naturality square](../../img/1_l7KSKBY2E53yM6cDx6J1Uw.png)*Naturality square*

![](../../img/1_spc7KLqoTT47SYMTE510RQ.png)

Natural transformation is isomorphic if all components are isomorphic.

### Naturatlity condition

![](../../img/1_NUaWfQeR_x7N5rav-XW7BA.png)

### Natural transformation in programming

NT in programming is polymorphic function.

![](../../img/1_WvQdPvFVWl8gWzQPqoCHMg.png)

### Example

    fun <A> List<A>.head(): Option<A> {
        return if (this.isEmpty()) None else Just(this.first())
    } 

    // list.fmap().head() == list.head().fmap()

Reversing order of function application can be used in optimizations.

### Intuition

Functor — map container contents

Natural transformation — map container

Naturality condition says that it doesn’t matter what to do first and what second: map container or map container contents.

### Examples of Natural Transformations

![](../../img/1_ScDfgCatepNBBNzq_vFgEg.png)

## Monad

Monad — Monoid in category of endofunctors

![Monoid](../../img/1_La-_GvI2mi1try-RMfyCPg.png)*Monoid*

Monoid object in category [C, C] (category of endofunctors) is a Monad

### Applicative

Applicative is a functor with:

![](../../img/1_zex6hPwux56glKfvjFgRXA.png)

### Monad

Monad is Applicative with:

![](../../img/1_IQu5N_RXM5U0EW-HdJcuVw.png)

Other functions:

![](../../img/1_cQQ5OHPsG08Ua8uUUjsVoA.png)

## Final words

Lectures were great, a lot of insides on the how world is constructed, how other math disciplines are based on these very high-level thoughts. And how all of this is related to programming, which is for sure a computer **science**.

To make a bit of a practice [made few implementations ](https://github.com/krossovochkin/CategoryTheoryExamples)of things which were an examples throughout the course. For sure, implementation is not that great, but it is in Kotlin which is more functional than Java (but not that as Scala or Haskell). Implementations are just examples and have no real usage. If one is interested in better implementations I think it is good to take a look at [arrow-kt](https://arrow-kt.io/).

Happy coding

*Thanks for reading!
If you enjoyed this article you can like it by **clicking on the👏 button** (up to 50 times!), also you can **share **this article to help others.*

*Have you any feedback, feel free to reach me on [twitter](https://twitter.com/krossovochkin), [facebook](https://www.facebook.com/vasya.drobushkov)*
[**Vasya Drobushkov**
*The latest Tweets from Vasya Drobushkov (@krossovochkin). Android developer You want to see a miracle, son? Be the…*twitter.com](https://twitter.com/krossovochkin)
