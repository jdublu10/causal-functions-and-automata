(*|
================================
Transducers are Causal Functions
================================

|*)


(*|
Consider the set :math:`2^\omega` of infinite lists of natural numbers. What are the "nice" functions :math:`2^\omega \to 2^\omega`? 
As indicated by the quotes, the answer to this question is highly dependent on your aesthetic preferences.
Naturally, different people with different needs have proposed different answers based on a wide variety of values of "nice".

One potential value of "nice" is the vacuous one: all (mathematically definable) functions :math:`2^\omega \to 2^\omega` are allowed!
Among these are functions that aren't even definable as functions in your favorite programming language,
such as the function :math:`f : 2^\omega \to 2^\omega` defined by :math:`f(1^\omega) = 0^\omega` and  :math:`f(s) = s`: the function
which is the identity everywhere, except for on the stream of all ones, where it's the stream of all zeroes.
This function is clearly not computable in any sense: in order to determine even the first element of the output stream,
all infinitely-many elements of the input need to be inspected.

Restricting "nice" to mean "computable" restricts the class significantly. Indeed, the main result is 
the rule out functions like the one above. A classic result in computability theory is that the computable
functions :math:`f : 2^\omega \to 2^\omega` are *continous* in a particular sense [#]_ which means that any finite prefix
of the output of :math:`f` can only depend on a finite prefix of its input.

However, the computable functions can include some unwanted behavior. Of particular interest for the purposes of this
piece is functions that "go back on their word".
A simple example of this is the function defined by the equations :math:`f(00s) = 01s`, :math:`f(01s) = 10s`, :math:`f(1s) = 1s`.
To see why this might be undesierable, consider a situation where the input list to the function is being *streamed in*, bit by bit, from
some outside source. Similarly, suppose the output is being produced bit by bit, and is fed to some similar transformation down the line.
Unfortunately, the function :math:`f` cannot be implemented in this manner: if the first bit of input is a :math:`0`,
the implementation must wait until the *second* bit arrives to emit the first bit of output. To faithfully implement this
in such a "stream transformer" machine model, the machine would need the ability to either (a) block until the second bit arrives, or
(b) emit a dummy value for the first output and then "retract" it once it got the second bit of input.

Our goal in this document is to characterize the stream functions :math:`f : 2^\omega \to 2^\omega` which
can be implemented as stream processing machines which are both (a) "productive", in the sense that they always
emit an output for each input, and (b) are "truthful" in the sense that they never have to go back on their word.

|*)

(*|
To begin, let's define a cobinductive [#]_. type of streams, with elements drawn from a type `A`.
This type is generated by one constructor, `SCons`, which means that every stream `s` is equal to
`SCons x s'`, where `x` is an element of type `A` (the "head" of the stream), and `s'` is another stream.
The circularity of this definition combined with the lack of a `SNil` constructor means that all
values of type `stream A` are infinite.
|*)


CoInductive stream (A : Type) : Type :=
| SCons : A -> stream A -> stream A.

(*|

More or less by definition, the functions `stream A -> stream B` which can be written in Coq
are computable. Unfortunately, we must work a bit harder to get the other properties.

Intuitively, both the truthfulness and productivity properties are facts about *prefixes* of streams.
Truthfulness says that passing a larger prefix yields only a larger output, while productivity says
precisely by how much the output should grow. Of course, while this makes intuitive sense, it's not
immediately clear how to define these properties formally. After all, stream functions `f : stream A -> stream B`
are defined on *entire* streams, not prefixes!

The insight required to guide us past this quandry is that truthful, productive functions on prefixes of streams
should actually be defined *in terms of* functions on their prefixes. To investigate this idea further, let's
introduce a type of prefixes.

|*)

Inductive vec (A : Type) : nat -> Type :=
| Empty : vec A 0
| Snoc {n} : vec A n -> A -> vec A (S n).

(*|
Above is a definition of length-indexed vectors, represented as snoc-lists.
These will represent prefixes of streams.


The most important (for our purposes) operation on vectors is truncation: deleting the
last element. Because we've implemented vectors as length-indexed snoc lists,
truncate is trivial to implment, as shown below.
|*)

Definition truncate {A} {n : nat} (l : vec A (S n)) : vec A n := 
  match l in vec _ (S n) return vec A n with
  | Snoc _ l _ => l
  end.


(*|
Truncation is particularly interesting because it lets us reframe streams in terms of their prefixes.
A stream can be thought of as a family of vectors `vs : forall n, vec n`, one of each length,
such that the :math:`n+1` st is just the :math:`n` th with one element tacked on to the end.
Swapping the perspective around, this is to say that that `vs n = truncate (vs (n + 1))`.
Intuitively, this view of streams is consistent with their view as coinductively defined objects:
they are lists that we may unfold to any finite depth.

Causal Functions
================

Viewing streams this way leads us to our first definition of productive & truthful functions on streams!
|*)


Record causal (A : Type) (B : Type) : Type := mkCausal {
  f : forall n, vec A n -> vec B n;
  caused : forall n l, f n (truncate l) = truncate (f (S n) l)
}.

(*|

For historical reasons, these objects are called "causal functions", which consist of

 1. A family of maps `f n : vec A n -> vec B n` taking `A`-vectors of length `n` to `B`-vectors of length `n`.
    For a causal function `c` and some nat `m`, we will call `f c m` the `m`-th component of `c`.
    The typing of these components ensures the "one-at-a-time" productivity of this family, viewed as a stream function.
    Vectors of length 1 yield vectors of length 1, and adding one more element to the input yields
    exactly one more element of output. But nothing in the type ensures that the first elmement
    remained the same. That's the job of the second component of the record, which consists of...

 2. Proofs that the family `f` "commutes with truncation", as shown in the commutative diagram below.
    Intuitively, `f n (truncate l) = truncate (f (S n) l)` says that `f n` and `f (S n)` must agree on the
    first `n` elements of their input: only the final element of `f (S n)` can be "new".

|*)

(*|
.. image:: square.png
   :width: 50%

Gluing all of these squares together, the data of a causal function is contained in the
following diagram: a pair of infinitely descending chains, connected pointwise
by the components of `f`.

.. image:: causal-presheaf-diagram.png
   :width: 75%

To the observer trained in the arts of category theory, this may spark some recognition:
`vec` is "just" an :math:`\omega`-presheaf, and causal functions are "just" presheaf morphisms.
|*)

(*|

Now with our definition of causal functionns in hand, it's time to interpret causal functions as stream functions, i.e. turn a causal map
that operates on finite prefixes of a stream into one that transforms whole streams.

To begin, we note that causal maps naturally act as functions `A -> B` by considering the `f 1 : vec 1 -> vec 1` component as a map on
singleton lists. 
|*)
Definition causalApply1 {A B} (c : causal A B) (x : A) : B.
Admitted.

(*|
This should allow us to lift a causal function from `A` to `B` to a function from streams of `A`-s
to streams of `B`-s.
Intuitively, the process is straightforward. Given a causal function `c`,
we will define its interpreation as a stream map `interpCausal c : stream A -> stream B` as the
function which takes a stream `SCons x s`, and returns the stream `SCons y s'`,
where `y` is the result of using `c` as a function `A -> B` and passing `x`, and `s'` is the
result of the recursive call.

This intuitive idea is translated into code below.
|*)

CoFixpoint interpCausalWrong {A B} (c : causal A B) (s : stream A) : stream B :=
  match s with
  | SCons _ x s => let y := causalApply1 c x in
                   SCons _ y (interpCausalWrong c s)
  end.


(*|
Unfortunately, as the identifier suggests, this is wrong in an important way.
To understand why, consider the stream `SCons x (SCons y s)`. The function `interpCausalWrong`
sends this to `SCons x' (SCons y' s')`, with `x' = causalApply1 c x` and `y' = causalApply1 c y`.
Unfolding the definition of `causalApply1`, this means that `x'` and `y'` are both the result of
applying the first component of `c`.

However, we would expect the first two bits of the output be the results of applying the
2nd component of `c` to the length-2 vector `Snoc (Snoc x Empty) y`.

To fix this, we must shift our perspective. If we've processed `n` elements of the stream so far,
We produce the `n+1`-st output by `Snoc`-ing the `n+1`-st input onto the prior `n`,
applying the `n+1`-st component of `c`, and then taking the tail.
This process is encoded by the function `causalApplySnoc` below.
|*)


Definition causalApplySnoc {A B} {n : nat} (c : causal A B) (l : vec A n) (x : A) : B :=
  match f _ _ c (S n) (Snoc _ l x) in vec _ (S n) return B with
  | Snoc _ _ y => y
  end.

(*|
We can now write `interpCausal` by simply accumulating elements as we see them, and kicking the
whole process off with the empty stream.
|*)

CoFixpoint interpCausalAux {A B} {n : nat} (c : causal A B) (l : vec A n) (s : stream A) : stream B :=
  match s with
  | SCons _ x s => let y := causalApplySnoc c l x in
                   SCons _ y (interpCausalAux c (Snoc _ l x) s)
  end.

Definition interpCausal {A B} (c : causal A B) : stream A -> stream B :=
  fun s => interpCausalAux c (Empty _) s.

(*|
To our initual query of "which are the nice functions" `stream -> stream`,
`interpCausal` provides the answer: "those which arise as `interpCausal c` for some causal function `c`".
|*)

(*|

Transducers
===========

As it turns out, causal functions are just one formalism for capturing this class of stream maps!
Another is by way of *transducers*, which are best thought of as stateful functions of type `A -> B`.
More precisely, a transducer is a function that takes in an `A`, and produces both an output `B`, and a new transducer:
the new state. The coinductive definition below uses a single constructor `T` to encode this:
every transducer `t : transd` is of the form `T f`, where `f : A -> B * transd` is a function
from an input `A` to pair of an output `B` and a new transducer to take the place of the old one.
|*)

CoInductive transd (A : Type) (B : Type): Type := 
| T : (A -> B * transd A B) -> transd A B.

(*|
Of course, nothing in the type discipline prevents us from using the same `f` multiple times
and ignoring the output `transd`, so we will just have to be careful about not accidentally reusing stale states.

Because stepping the transducer requires a pattern match, we wrap this behavior in a function `step : transd A B -> A -> B * (transd A B)`,
defined below.
|*)

Definition step {A B} (t : transd A B) (x : A) : B * transd A B :=
    match t with
    | T _ _ f => f x
    end.

(*|
To get a sense of how transducers work, let's define a transducer which computes the partial sums of its input.
|*)

CoFixpoint partialSumAux (n : nat) : transd nat nat :=
  T _ _ (fun x => let y := x + n in (y, partialSumAux y)).

Definition partialSum : transd nat nat := partialSumAux 0.

(*|
This transducer accumulates a running total `n` of the values it's seen so far. When it gets 
an input `x`, it outputs `x + n`, and transitions to a new state where the running total *is* `x + n`.

With an illustative example in hand, we can start to look at ways of interpreting
transducers. Unlike last time, the natural thing works!
A transducer `t` is interpreted as the function that, when given a stream `SCons x s`,
steps `t` on `x`, producing output `y` and a new transducer `t'`, and returns the stream with `y`
cons'd to the front of interpreting `t'` on the rest of the stream.


|*)

CoFixpoint interpTransd {A B} (t : transd A B) : stream A -> stream B :=
  fun s =>
    match s with
    | SCons _ x s => let (y,t') := step t x in
                     SCons _ y (interpTransd t' s)
    end.

(*|
The fact that stepping `t` returns a new transducer ready to handle the rest of the stream
means we don't have to do any auxiliary state-passing: it's all handled by the
definition of the particular `t`.

`interpTransd` provides yet another answer to the question of which functions `stream A -> stream B` are nice:
those which arise by `interpTransd t` for some transducer t!
|*)

(*|
Back and Forth
==============

As it happens, the two answers we have discussed thus far seem to actually be the same: 
transducers and causal functions define the same class of stream morphisms.
The first step in showing this is to show that transducers and causal functions are inter-convertible:
we can turn one into the other, and vice versa. Surprisingly, both directions are straightforward.

We begin by showing that transducers can be interpreted as causal functions. Given a
transducer `t`, the components of the corresponding causal function are the functions `vec A n -> vec B n`
which fold `step t` over the input vector from left to right, threading the updated state through.
This is implemented in the two functions below: `stepN` handles the threading of the transducer through,
and `execN` simply projects out the result.
|*)

Fixpoint stepN {A B} {n} (t : transd A B) (l : vec A n) : transd A B * vec B n :=
    match l with
    | Empty _ => (t,Empty _)
    | Snoc _ l' x => let (t',l'') := stepN t l' in
                     let (y,t'') := step t' x in
                     (t'',Snoc _ l'' y)
    end.

Definition execN {A B} (t : transd A B) : forall n, vec A n -> vec B n :=
  fun n l => snd (stepN t l).

(*|  
To turn this family of components defined by `execN t` into a causal map, we must also prove the
commuting squares which show that `execN t` commutes with truncation. Proving this will require
a sort of "eta law" for `execN` called `execN_snoc`. In short, this says that
the result of the `n+1`-st component of `execN t` is just that of the `n`-th, with one more step of `t` tacked on at the end.
|*)

Theorem execN_snoc {A B} : forall t n l x, execN t (S n) (Snoc A l x) = Snoc B (execN t n l) (let (t',_) := stepN t l in fst (step t' x)).
Proof.
  intros.
  unfold execN.
  cbn.
  destruct (stepN t l).
  destruct (step t0 x).
  cbn.
  reflexivity.
Qed.

Require Import Coq.Program.Basics.
Require Import Coq.Program.Equality.

Theorem execN_caused {A B} (t : transd A B) : forall (n : nat) (l : vec _ (S n)),
  execN t n (truncate l) = truncate (execN t (S n) l).
Proof.
  intros.
  (*| We begin by using the `dependent destruction` tactic, which uses the fact that `l` has length at least one to refine our goal to handling the case where `l` is actually `Snoc l a`. |*)
  dependent destruction l. (* .unfold -.h#* .h#t .h#l .h#a *)
  cbn. (* .unfold -.h#* .h#t .h#l .h#a *)
  (*| We then apply the `execN_snoc` lemma to massage the `execN t (S n) (Snoc _ l a)` term into a form where we can directly reduce `truncate`. |*)
  rewrite execN_snoc. (* .unfold -.h#* .h#t .h#l .h#a *)
  (*| Ignoring the cruft in the second component of the snoc, we note that the RHS is of the form `truncate (Snoc _ (execN t l) _)`, which directly reduces by one use of `cbn` to `execN t l`, as required. |*)
  cbn. (* .unfold -.h#* .h#t .h#l .h#a *)
  reflexivity.
Qed.

(*| With components and proofs in hand, we can package them together to get a function `transdToCausal : transd A B -> causal A B`. |*)

Definition transdToCausal {A B} (t : transd A B) : causal A B :=
  mkCausal _ _ (execN t) (execN_caused t).

(*| Of course, we can also go backwards: causal maps define transducers. This translation works essentially
the same way as the interpretation of causal functions as stream maps: we accumulate the previously-seen values,
and apply the `n+1`-st component after `n` accumulated values to get the next.
|*)

CoFixpoint causalToTransdAux {A B} {n : nat} (c : causal A B) (l : vec A n) : transd A B :=
  T _ _ (fun x => 
           let y := causalApplySnoc c l x in
           (y, causalToTransdAux c (Snoc _ l x))
        ).

Definition causalToTransd {A B} (c : causal A B) : transd A B :=
  causalToTransdAux c (Empty _).

(*|
What's Left
===========

Of course, these maps back and forth create natural proof obligations. In order to show that causal maps
and transducers define the same set of stream functions, it remains to show the following:

 1. The `causalToTransd` and `transdToCausal` functions are (weakly) inverses, up to suitable equivalence relations on
    `causal A B` and `transd A B`.
 2. Equivalent causal functions and equivalent trandsucers are interpreted as equivalent stream functions: i.e. the functions
    `interpCausal` and `interpTransd` are congruences.


We begin by defining the equivalence relations in question. Stream equialence is defined as the standard extensional equality
on streams: two streams are equivalent if their heads are equal, and their tails are equivalent.
|*)

Definition head {A} (s : stream A) : A :=
  match s with
  | SCons _ x _ => x
  end.

Definition tail {A} (s : stream A) : stream A :=
  match s with
  | SCons _ _ s' => s'
  end.

CoInductive stream_eq {A} : stream A -> stream A -> Prop :=
| Eq_SCons : forall s s', head s = head s' -> stream_eq (tail s) (tail s') -> stream_eq s s'.

(*|
The natural notion of equality for causal functioins is that of extensional equality of their components.
Note that `causal_eq c c'` is different from strict equality `c = c'` for two reasons. For one, it disregards
the `caused` component of `c` and `c'`: this is a way of rendering the equality proofs irrelevant without having
them live in `SProp`. Second, the equality is extensional, commponentwise: to say that `f _ _ c = f _ _ c'` would
be far too strong in coq's type theory.
|*)

Definition causal_eq {A B} (c : causal A B) (c' : causal A B) :=
  forall n l, f _ _ c n l = f _ _ c' n l.

(*|
Finally, transducer equality is the natural extensional equality: two transducers are equivalent if,
for any `x : A`, their outputs are equal, and they step to equivalent transducers.
|*)

CoInductive transd_eq {A B} : transd A B -> transd A B -> Prop :=
| Eq_T : forall t t', (forall (x : A), (fst (step t x)) = (fst (step t' x)) /\ transd_eq (snd (step t x)) (snd (step t' x))) -> transd_eq t t'.

(*|
Proving these equivalences will require quite a few lemmata. We begin with two "eta laws" about vectors,
deconstructing values of type `vec A n` into terms with constructors at their heads based on `n`.
|*)

Definition last {A} {n : nat} (l : vec A (S n)) : A :=
  match l in vec _ (S n) return A with
  | Snoc _ _ x => x
  end.

Lemma vec_eta_0 {A} : forall (l : vec A 0), l = Empty A.
Proof.
  dependent destruction l. reflexivity.
Qed.

Lemma vec_eta_S {A} : forall n (l : vec A (S n)), l = Snoc _ (truncate l) (last l).
Proof.
  dependent destruction l. eauto.
Qed.

Lemma causalApplySnoc_correct {A B} :
  forall (c : causal A B) n (l : vec A n) (x : A),
    (causalApplySnoc c l x) = last (f _ _ c _ (Snoc _ l x)).
Proof.
  intro c.
  dependent induction l; intro x.
  - unfold causalApplySnoc.
    rewrite (vec_eta_S 0 (f _ _ c 1 (Snoc _ (Empty _) x))).
    cbn.
    reflexivity.
  - unfold causalApplySnoc.
    rewrite (vec_eta_S (S n) (f A B c (S (S n)) (Snoc A (Snoc A l a) x))).
    cbn.
    reflexivity.
Qed.

Lemma causalToTransd_stepN_correct {A B} : forall c n l, stepN (causalToTransd c) l = (causalToTransdAux c l, f A B c n l).
Proof.
  intros.
  unfold execN.
  dependent induction l.
  - cbn.
    unfold causalToTransd.
    rewrite (vec_eta_0 (f A B c 0 _)).
    reflexivity.
  - cbn.
    rewrite IHl.
    cbn.
    rewrite causalApplySnoc_correct.
    rewrite (vec_eta_S n (f A B c (S n) (Snoc A l a))).
    cbn.
    rewrite <- (caused _ _ c n (Snoc _ l a)). reflexivity.
Qed.

(*|
Now, we can prove one of the two round-trip directions: given a causal function,
turning it into a transducer and then back into a causal function, yields an equivalent causal function to the original.
|*)

Theorem causalToTransdAndBack {A B} :
  forall (c : causal A B), causal_eq c (transdToCausal (causalToTransd c)).
Proof.
  unfold causal_eq.
  intro c.
  dependent induction l.
  - cbn. rewrite (vec_eta_0 (f A B c 0 (Empty A))). reflexivity.
  - unfold transdToCausal.
    cbn.
    unfold execN.
    rewrite causalToTransd_stepN_correct. 
    auto.
Qed.

(*|
Naturally, we also want to prove the other direction of the round trip.
This requies a fairly involved generalization of the coinductive hypothesis (found in `transdToCausalAndBack_aux`),
from which the actual theorem (`transdToCausalAndBack`) follows directly.
|*)

Lemma transdToCausalAndBack_aux {A B} : forall (t : transd A B) n (l : vec A n),
  transd_eq
  (fst (stepN t l))
  (causalToTransdAux (transdToCausal t) l).
Proof.
  cofix coIH.
  intros.
  apply Eq_T.
  intro x.
  split.
  * cbn. rewrite causalApplySnoc_correct. unfold transdToCausal. cbn.
    unfold execN.
    cbn.
    destruct (stepN t l); cbn.
    destruct (step t0 x); cbn.
    reflexivity.
  * cbn.
    assert (snd (step (fst (stepN t l)) x) = fst (stepN t (Snoc _ l x))).
    + cbn.
      destruct (stepN t l).
      cbn.
      destruct (step t0 x).
      cbn.
      reflexivity.
  + rewrite H.
    apply coIH.
Qed.



Theorem transdToCausalAndBack {A B} :
  forall (t : transd A B), transd_eq t (causalToTransd (transdToCausal t)).
Proof.
  intro t.
  assert (transd_eq
  (fst (stepN t (Empty _)))
  (causalToTransdAux (transdToCausal t) (Empty _))) by (apply transdToCausalAndBack_aux).
  cbn in H.
  exact H.
Qed.

(*|
But the fact that the functions between `causal A B` and `transd A B` are inverses up to
our custom equivalence relations doesn't mean that the stream types they define are the same!
For that we'll need that the interpretation functions for causal functions and transducers
respect the respective equivalences.


|*)

Lemma interpCausalAux_cong {A B} :
  forall (c c' : causal A B), causal_eq c c' -> forall s, forall n (l : vec A n), stream_eq (interpCausalAux c l s) (interpCausalAux c' l s).
Proof.
  intros c c' eqpf; simpl.
  cofix coIH.
  intros s n l.
  destruct s.
  apply Eq_SCons.
  - cbn.
    unfold causalApplySnoc.
    assert (f _ _ c (S n) (Snoc _ l a) = f _ _ c' (S n) (Snoc _ l a)) by (apply eqpf).
    rewrite H.
    reflexivity.
  - cbn. apply coIH.
Qed.
  
Theorem interpCausal_cong {A B} :
  forall (c c' : causal A B), causal_eq c c' -> forall s, stream_eq (interpCausal c s) (interpCausal c' s).
Proof.
  intros.
  apply interpCausalAux_cong.
  apply H.
Qed.

Theorem interpTransd_cong {A B} :
  forall (t t' : transd A B), transd_eq t t' -> forall s, stream_eq (interpTransd t s) (interpTransd t' s).
Proof.
  cofix coIH.
  intros t t' pf.
  intro s.
  destruct s.
  destruct pf as [t t' pf].
  apply Eq_SCons.
  - unfold head.
    cbn.
    assert (fst (step t a) = fst (step t' a)) by (apply pf).
    destruct (step t a).
    destruct (step t' a).
    cbn in H.
    apply H.
  - unfold tail. cbn.
    assert (transd_eq (snd (step t a)) (snd (step t' a))) by (apply pf).
    destruct (step t a).
    destruct (step t' a).
    cbn in H.
    apply coIH.
    apply H.
Qed.

(*|
.. [#] For the curious: by endowing :math:`2` with the discrete topology and :math:`2^\omega` with the product topology, the computable functions :math:`2^\omega \to 2^\omega` are continuous.
.. [#] We will not be discussing coinduction or cofixpoints in this document, but the unfamiliar reader can safely ignore this detail, and treat the coinductive definitions as just special syntax for defining datatypes that have infinite values.
|*)

(*|
Reflections on Literate Programming in Coq
==========================================
This document was written as my final project in Prof. Andrew Head's course
"Live and Literate Programming" in Fall 2022. After a semester of studying literate programing,
this case study left me with a few take-aways and recommendations for future designers of literate programming
tools for theorem provers like Coq.

* Literate programming tools should never enforce that the code in the woven
  (pdf/html output) view appear in the same order as it does in the original code
  view. Unfortunately, Alectryon requires definition-order documents. I would much
  prefer something like Torii where I can weave the code together in an order that
  makes pedagogical sense, but does not necessarily pass the proof checker. The
  writing style in this document is severely hampered by the need to present
  everything before it appears.

* Alectryon does not permit the hiding of definition bodies. Many of the theorems
  and definitions that appear in this document are "standard" in the sense that
  they require little mathematical insight to prove or develop. Some examples
  include the `cons` and `tail` functions on snoc-lists, as well as the
  compatability theorems like `cons_snoc` or `truncate_cons`. Unfortunately,
  Alectryon requires that if the statements and type signatures of these theorems
  and definitions are to be shown in the document, then their proofs and bodies
  must also be shown. This is significant cruft that draws the reader away from
  their real task understanding the *imporant* theorems and definitions.

* It is very difficult to write an Alectryon document without the use of the
  library's custom emacs-based editing tool which allows one to fluidly change
  back and forth between code-primary and markdown-primary views. The philosophy
  of the tool is that neither view should be considered "primary", and that there
  is no third view that the code and markdown compile from. In practice, however,
  without the use of the emacs extension (or emacs altogether), the Coq format
  quickly becomes primary.


|*)

