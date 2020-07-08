+++
title = "Kotlin-android-synthetics performance analysis (with ButterKnife)"
date = "2019-02-18"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = []
keywords = []
description = ""
showFullContent = false
+++

# Introduction

After comment that [synthetic is no longer recommended practice](https://android-review.googlesource.com/c/platform/frameworks/support/+/882241) and [some arguments](https://proandroiddev.com/the-argument-over-kotlin-synthetics-735305dd4ed0) I decided to go deeper into issue with performance of *kotlin-android-synthetics* by analyzing generated Java and byte code and comparing to other approaches (such as vanilla-*findViewById *and *ButterKnife*).

## Vanilla-findViewById

This is sample Activity we’ll work with throughout the article.
Approach with *findViewById *will be our baseline.

Sample consists of:

* *Activity *class

* One *TextView *property inside *Activity *with *lateinit *modifier

* Initializing *TextView *property in *onCreate *in *Activity*

* Setting dynamically few properties on *TextView *afterwards

{{< highlight kotlin >}}
class MainActivity : AppCompatActivity() {

    private lateinit var textView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        textView = findViewById(R.id.textView)

        update()
    }

    private fun update() {
        textView.text = "Text"
        textView.setTextColor(Color.RED)
        textView.textSize = 14.0f
    }
}
{{< / highlight >}}

Here is what we’ll get if we try to look at generated java code:

{{< highlight java >}}
public final class MainActivity extends AppCompatActivity {
   private TextView textView;
   private HashMap _$_findViewCache;

   protected void onCreate(@Nullable Bundle savedInstanceState) {
      super.onCreate(savedInstanceState);
      this.setContentView(-1300009);
      View var10001 = this.findViewById(-1000050);
      Intrinsics.checkExpressionValueIsNotNull(var10001, "findViewById(R.id.textView)");
      this.textView = (TextView)var10001;
      this.update();
   }

   private final void update() {
      TextView var10000 = this.textView;
      if (this.textView == null) {
         Intrinsics.throwUninitializedPropertyAccessException("textView");
      }

      var10000.setText((CharSequence)"Text");
      var10000 = this.textView;
      if (this.textView == null) {
         Intrinsics.throwUninitializedPropertyAccessException("textView");
      }

      var10000.setTextColor(-65536);
      var10000 = this.textView;
      if (this.textView == null) {
         Intrinsics.throwUninitializedPropertyAccessException("textView");
      }

      var10000.setTextSize(14.0F);
   }

   public View _$_findCachedViewById(int var1) {
      if (this._$_findViewCache == null) {
         this._$_findViewCache = new HashMap();
      }

      View var2 = (View)this._$_findViewCache.get(var1);
      if (var2 == null) {
         var2 = this.findViewById(var1);
         this._$_findViewCache.put(var1, var2);
      }

      return var2;
   }

   public void _$_clearFindViewByIdCache() {
      if (this._$_findViewCache != null) {
         this._$_findViewCache.clear();
      }

   }
}
{{< / highlight >}}

We immediately have a number of questions:

* We haven’t used synthetics in this *Activity*, we just have apply plugin: 'kolin-android-extensions' in our *build.gradle* (which is added by default).
Why we have ***_$_findViewCache***, ***_$_findCachedViewById*** and ***_$_clearFindViewByIdCache***?

* Why we have three null-checks for our *TextView *property (which can throw *throwUninitializedPropertyAccessException)?*

* If keys for view cache are primitive integers, why we have *HashMap*? Keys in HashMap are Integer objects, so each *get *with primitive int will end up with autoboxing primitive value into Integer object (which pollutes memory)

Let’s try to answer these questions one by one.

### Code generation issue

I have no exact answer to the question why we have synthetic code generated for class which hasn’t used them.
Most likely (as [*LayoutContainers *are supported](https://kotlinlang.org/docs/tutorials/android-plugin.html#layoutcontainer-support) — including *Activity*, *Fragment*, *View*) code is generated for all these classes without checking whether some features of synthetics are actually used in them.
Maybe it is just easier to generate to all supported classes than to check where exactly code is needed.
Also it might help with incremental builds as after code generation and first build success there is no need to redo it again.

This might look like an overhead from code perspective (and it basically is). Thankfully we have *multidex*, so number of methods is no longer an issue.
For release build *ProGuard *(or *R8*) will remove unused methods and fields and will do many other optimizations so the problem will gone (eventually there even won’t be *update()* method in resulting release byte-code as code will be inlined into *onCreate *method)

### Lateinit checks

Various *Intrinsic *checks are generated by Kotlin for Java. On Kotlin level it is easy to enforce and check that values are not null/nullable etc., but when it comes to Java there are no guarantees that everything will work well.

As *TextView *property is not final it is possible that between two lines value will be set to *null*. Intrinsic checks ensure that if some contract is violated exception is thrown as soon as possible.

This again might look as an overhead if we know that we’ll initialize *TextView *in *onCreate *(and we’ll check that value is not null) and that we’ll not try to change property concurrently and that we don’t call *update()* method before *onCreate*, so that additional checks are not really required (or at least it could be one).
But it is something we know, not the compiler.

One could look at generated Java code and decide to do little trick with *.apply* function:

{{< highlight kotlin >}}
private fun update() {
    textView.apply {
        text = "Text"
        setTextColor(Color.*RED*)
        textSize = 14.0f
    }
}
{{< / highlight >}}

So the resulting Java code will be:

{{< highlight java >}}
private final void update() {
   TextView var10000 = this.textView;
   if (this.textView == null) {
      Intrinsics.*throwUninitializedPropertyAccessException*("textView");
   }

   TextView var1 = var10000;
   var1.setText((CharSequence)"Text");
   var1.setTextColor(-65536);
   var1.setTextSize(14.0F);
}
{{< / highlight >}}

So we have only one check and then update all properties on local property. Neat.

Though such optimizations are definitely premature as anyway in release build ProGuard will do better optimization work without making your code look a bit weird.

### HashMap/SparseArray

Why *HashMap* is used instead of *SparseArray*?

As keys are integers each lookup will trigger boxing of the integer value which will badly impact memory usage and make GC to trigger more often.
Seems *SparseArray *is better option because we’ll have primitive integers as keys, why it is not used?

Actually there is a way to generate code with *SparseArray*. For that it is needed to add to *build.gradle*:

{{< highlight groovy >}}
androidExtensions {
    defaultCacheImplementation = "SPARSE_ARRAY"
}
{{< / highlight >}}

After that we’ll have *SparseArray* as cache for views.

Also it is possible to disable cache by using “NONE”, though this option hardly ever useful.

### Result

To conclude, evaluation of vanilla approach:
+ one-time initialization (in *onCreate*)
+ fast subsequent getters (property keeps reference to *View*)
– a lot of boilerplate (properties, *findViewById *calls)

## ButterKnife

Let’s look at the same example with ButterKnife:

{{< highlight kotlin >}}
class ButterKnifeAcivity : AppCompatActivity() {

    @BindView(R.id.textView)
    lateinit var textView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        ButterKnife.bind(this)

        update()
    }

    private fun update() {
        textView.text = "Text"
        textView.setTextColor(Color.RED)
        textView.textSize = 14.0f
    }
}
{{< / highlight >}}

Generated Java code (synthetics part is removed):

{{< highlight java >}}
public final class ButterKnifeAcivity extends AppCompatActivity {
   @BindView(-1000050)
   @NotNull
   public TextView textView;

   @NotNull
   public final TextView getTextView() {
      TextView var10000 = this.textView;
      if (this.textView == null) {
         Intrinsics.throwUninitializedPropertyAccessException("textView");
      }

      return var10000;
   }

   public final void setTextView(@NotNull TextView var1) {
      Intrinsics.checkParameterIsNotNull(var1, "<set-?>");
      this.textView = var1;
   }

   protected void onCreate(@Nullable Bundle savedInstanceState) {
      super.onCreate(savedInstanceState);
      this.setContentView(-1300009);
      ButterKnife.bind((Activity)this);
      this.update();
   }

   private final void update() {
      TextView var10000 = this.textView;
      if (this.textView == null) {
         Intrinsics.throwUninitializedPropertyAccessException("textView");
      }

      var10000.setText((CharSequence)"Text");
      var10000 = this.textView;
      if (this.textView == null) {
         Intrinsics.throwUninitializedPropertyAccessException("textView");
      }

      var10000.setTextColor(-65536);
      var10000 = this.textView;
      if (this.textView == null) {
         Intrinsics.throwUninitializedPropertyAccessException("textView");
      }

      var10000.setTextSize(14.0F);
   }
}
{{< / highlight >}}

So, basically everything is the same. The difference is only that additional getter and setter for our *TextView *was generated.
It is actually redundant (and will be removed by *ProGuard*), because *ButterKnife *injector will work directly on field:

{{< highlight kotlin >}}
public final class ButterKnifeAcivity_ViewBinding implements Unbinder {
  private ButterKnifeAcivity target;

  @UiThread
  public ButterKnifeAcivity_ViewBinding(ButterKnifeAcivity target) {
    this(target, target.getWindow().getDecorView());
  }

  @UiThread
  public ButterKnifeAcivity_ViewBinding(ButterKnifeAcivity target, View source) {
    this.target = target;

    target.textView = Utils.findRequiredViewAsType(source, R.id.textView, "field 'textView'", TextView.class);
  }

  @Override
  public void unbind() {
    ButterKnifeAcivity target = this.target;
    if (target == null) throw new IllegalStateException("Bindings already cleared.");
    this.target = null;

    target.textView = null;
  }
}
{{< / highlight >}}

So, basically using *ButterKnife* is similar to vanilla approach. The only difference is that we don’t have to write a lot of *findViewById *calls (though we still need to write one line per property — *Binds *annotation — but it is anyway better as we have actual property and view id near to each other).

There is small downside that *ButterKnife *uses reflection to instantiate *ViewBinding *class. But this is usual trade-off between reflection and code generation.

### Result

To conclude, evaluation of *ButterKnife *approach:
+ one-time initialization (in *onCreate*)
+ fast subsequent getters (property keeps reference to *View*)
+/– quite a lot of boilerplate (still need to define properties, though no need to write a lot of *findViewById *mehod calls, instead just one method bind — but it is needed to add *Binds *annotation to each property)

## Synthetics

Same sample using synthetics:

{{< highlight kotlin >}}
import kotlinx.android.synthetic.main.activity_main.*

class ExtensionsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        update()
    }

    private fun update() {
        textView.text = "Text"
        textView.setTextColor(Color.RED)
        textView.textSize = 14.0f
    }
}
{{< / highlight >}}

Generated Java code:

{{< highlight java >}}
public final class ExtensionsActivity extends AppCompatActivity {
   private SparseArray _$_findViewCache;

   protected void onCreate(@Nullable Bundle savedInstanceState) {
      super.onCreate(savedInstanceState);
      this.setContentView(-1300009);
      this.update();
   }

   private final void update() {
      TextView var10000 = (TextView)this._$_findCachedViewById(id.textView);
      Intrinsics.checkExpressionValueIsNotNull(var10000, "textView");
      var10000.setText((CharSequence)"Text");
      ((TextView)this._$_findCachedViewById(id.textView)).setTextColor(-65536);
      var10000 = (TextView)this._$_findCachedViewById(id.textView);
      Intrinsics.checkExpressionValueIsNotNull(var10000, "textView");
      var10000.setTextSize(14.0F);
   }

   public View _$_findCachedViewById(int var1) {
      if (this._$_findViewCache == null) {
         this._$_findViewCache = new SparseArray();
      }

      View var2 = (View)this._$_findViewCache.get(var1);
      if (var2 == null) {
         var2 = this.findViewById(var1);
         this._$_findViewCache.put(var1, var2);
      }

      return var2;
   }

   public void _$_clearFindViewByIdCache() {
      if (this._$_findViewCache != null) {
         this._$_findViewCache.clear();
      }

   }
}
{{< / highlight >}}

Here we have version with *SparseArray *to not have, as discussed above, useless autoboxing of integer keys.

The main issue with generated code is that even as we call three methods on same property sequentially, we still have 3 lookups in view cache (yes, *findViewById *will be called just once — at first time, but why to get value from cache all the time?).

Again, we can work-around this by using *.apply*, as we did in vanilla approach. Then generated code will be like:

{{< highlight java >}}
private final void update() {
   TextView var1 = (TextView)this._$_findCachedViewById(id.textView);
   var1.setText((CharSequence)"Text");
   var1.setTextColor(-65536);
   var1.setTextSize(14.0F);
}
{{< / highlight >}}

Looks like we’ve improved our code a bit, as now we’ll call cache only once (and if HashMap is used, then we’ll not have two additional boxing of integer primitive).
That actually looks pretty good.

But if we look at generated *dex *byte-code for release build, then it turns out everything is not that easy and straightforward.
Below are two listings, first one is byte-code from decompiled release APK of original example, second one for case with “optimization” of *.apply*.

**Original**:

{{< highlight kotlin >}}
.class public final Lcom/krossovochkin/butterknifetest/ExtensionsActivity;
.super Landroidx/appcompat/app/c;


# instance fields
.field private j:Ljava/util/HashMap;


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Landroidx/appcompat/app/c;-><init>()V

    return-void
.end method

.method private a(I)Landroid/view/View;
    .registers 4

    iget-object v0, p0, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->j:Ljava/util/HashMap;

    if-nez v0, :cond_b

    new-instance v0, Ljava/util/HashMap;

    invoke-direct {v0}, Ljava/util/HashMap;-><init>()V

    iput-object v0, p0, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->j:Ljava/util/HashMap;

    :cond_b
    iget-object v0, p0, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->j:Ljava/util/HashMap;

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    invoke-virtual {v0, v1}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/view/View;

    if-nez v0, :cond_26

    invoke-virtual {p0, p1}, Landroidx/fragment/app/d;->findViewById(I)Landroid/view/View;

    move-result-object v0

    iget-object v1, p0, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->j:Ljava/util/HashMap;

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p1

    invoke-virtual {v1, p1, v0}, Ljava/util/HashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

    :cond_26
    return-object v0
.end method


# virtual methods
.method public final onCreate(Landroid/os/Bundle;)V
    .registers 3

    invoke-super {p0, p1}, Landroidx/appcompat/app/c;->onCreate(Landroid/os/Bundle;)V

    const p1, 0x7f0a001e

    invoke-virtual {p0, p1}, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->setContentView(I)V

    sget p1, Lcom/krossovochkin/butterknifetest/a$a;->textView:I

    invoke-direct {p0, p1}, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->a(I)Landroid/view/View;

    move-result-object p1

    check-cast p1, Landroid/widget/TextView;

    const-string v0, "textView"

    invoke-static {p1, v0}, La/a/a/a;->a(Ljava/lang/Object;Ljava/lang/String;)V

    const-string v0, "Text"

    check-cast v0, Ljava/lang/CharSequence;

    invoke-virtual {p1, v0}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V

    sget p1, Lcom/krossovochkin/butterknifetest/a$a;->textView:I

    invoke-direct {p0, p1}, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->a(I)Landroid/view/View;

    move-result-object p1

    check-cast p1, Landroid/widget/TextView;

    const/high16 v0, -0x10000

    invoke-virtual {p1, v0}, Landroid/widget/TextView;->setTextColor(I)V

    sget p1, Lcom/krossovochkin/butterknifetest/a$a;->textView:I

    invoke-direct {p0, p1}, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->a(I)Landroid/view/View;

    move-result-object p1

    check-cast p1, Landroid/widget/TextView;

    const-string v0, "textView"

    invoke-static {p1, v0}, La/a/a/a;->a(Ljava/lang/Object;Ljava/lang/String;)V

    const/high16 v0, 0x41600000    # 14.0f

    invoke-virtual {p1, v0}, Landroid/widget/TextView;->setTextSize(F)V

    return-void
.end method
{{< / highlight >}}

**With .*apply* “optimization”:**

{{< highlight kotlin >}}
.class public final Lcom/krossovochkin/butterknifetest/ExtensionsActivity;
.super Landroidx/appcompat/app/c;


# instance fields
.field private j:Ljava/util/HashMap;


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Landroidx/appcompat/app/c;-><init>()V

    return-void
.end method


# virtual methods
.method public final onCreate(Landroid/os/Bundle;)V
    .registers 4

    invoke-super {p0, p1}, Landroidx/appcompat/app/c;->onCreate(Landroid/os/Bundle;)V

    const p1, 0x7f0a001e

    invoke-virtual {p0, p1}, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->setContentView(I)V

    sget p1, Lcom/krossovochkin/butterknifetest/a$a;->textView:I

    iget-object v0, p0, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->j:Ljava/util/HashMap;

    if-nez v0, :cond_16

    new-instance v0, Ljava/util/HashMap;

    invoke-direct {v0}, Ljava/util/HashMap;-><init>()V

    iput-object v0, p0, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->j:Ljava/util/HashMap;

    :cond_16
    iget-object v0, p0, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->j:Ljava/util/HashMap;

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    invoke-virtual {v0, v1}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/view/View;

    if-nez v0, :cond_31

    invoke-virtual {p0, p1}, Landroidx/fragment/app/d;->findViewById(I)Landroid/view/View;

    move-result-object v0

    iget-object v1, p0, Lcom/krossovochkin/butterknifetest/ExtensionsActivity;->j:Ljava/util/HashMap;

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p1

    invoke-virtual {v1, p1, v0}, Ljava/util/HashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

    :cond_31
    check-cast v0, Landroid/widget/TextView;

    const-string p1, "Text"

    check-cast p1, Ljava/lang/CharSequence;

    invoke-virtual {v0, p1}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V

    const/high16 p1, -0x10000

    invoke-virtual {v0, p1}, Landroid/widget/TextView;->setTextColor(I)V

    const/high16 p1, 0x41600000    # 14.0f

    invoke-virtual {v0, p1}, Landroid/widget/TextView;->setTextSize(F)V

    return-void
.end method
{{< / highlight >}}

Again, few questions and observations:

* It turned out that *HashMap* is in the byte-code, though we added in config that we want to use *SparseArray *(and generated Java code was exactly showing us that we have *SparseArray*).
So it seems optimization during release compilation replaced *SparseArray *with *HashMap *(for unknown reason)
So we not only have ***.field private j:Ljava/util/HashMap;*** we also have autoboxing in place*** invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;***
So looks like our optimization is really good as we avoid useless autoboxing?
Interesting stuff, though I don’t know why it happens

* Byte-code for our *apply *“optimization” is shorter. We exactly see that in first listing there are getters from *HashMap *coming first and only then setters on *TextView *are called, when in second listing setters on *TextView* are called almost one by one.
Additional thing is that by not calling view cache multiple times *ProGuard* was able to inline code related to view cache directly to *onCreate *method (so we don’t have method to call view cache by id)

So it seems our apply “optimization” worked and we have smaller byte-code, also avoided additional autoboxing in HashMap and not calling view cache multiple times.
Is it enough to recommend using apply “optimization”? I think no. Though there is some impact in the resulting release byte-code it is still matter of optimizations on byte-code level. We usually should not do any code tricks to make byte-code faster.
Even if right now solution works, then we need to check over time that this optimization is still working.
Otherwise it is better to have clean code.

### Result

To conclude, evaluation of Synthetics approach:
+ no boilerplate (automatic properties creation and binding*)
+/– dynamic initialization (views are not binded in *onCreate *but on first call. Whether it is a plus or not actually depends)
– slow getters (either *HashMap *with autoboxing of key or relatively slow lookup in *SparseArray *— which seems still converted to *HashMap *in release; possible delay for first time get)

## Conclusion

So, use or not use?

Actually it depends.
I think synthetics is pretty useful tool for common cases when you have simple screens and not using e.g. ‘includes’ and other stuff.
If one needs more control, then definitely vanilla approach is better (though has more boilerplate).
ButterKnife looks as something between the two and because of that [still] a good tool to work with.

Though next generation of helper tools for working with view bindings I would expect to be built on top of the idea of ButterKnife and just additionally generate properties with Bind annotations automatically.

Synthetics approach seems a bit too broad with a lot of things underneath, with less control. Approach which only looks good for beginners (as you don’t need to think about many things), though dangerous and actually seems to be designed for professionals.
Synthetics approach definitely has the worst performance comparing to vanilla or ButterKnife, but I hope that some optimizations will be done in the future so it will become really good approach.

Happy coding!