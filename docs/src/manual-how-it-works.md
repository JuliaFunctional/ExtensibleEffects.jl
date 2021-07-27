```@meta
CurrentModule = ExtensibleEffects
DocTestSetup  = quote
    using ExtensibleEffects
end
```

# How does it actually work?

`ExtensibleEffects` put everything into the meta monad `Eff` and somehow magically by doing so different monads can compose well together. Let's look a bit more into the details.

## Key ingredients

There are two main ingredience for this magic to work:

1. `Eff` is itself a Monad, hence you can work *within* `Eff` without caring about the precise workings of the computational context `Eff`.
2. `Eff` is not only an arbitrary Monad, but a very generic one, sometimes called a kind of *free* Monad. The key result is that we can represent many many of our well known Monads into this `Eff` monad.
3. The ExtensibleEffects system guarantees that the `continuation` in `eff_flatmap(handler, continuation, effectful)` will always return an `Eff` with element type of the same type as `effectful` itself. This makes it possible to define your own effect-handlers *independent* of all the other effect-handlers.

The monad implementation is very simple indeed.

```julia
TypeClasses.pure(::Type{<:Eff}, a) = noeffect(a)
TypeClasses.map(f, eff::Eff) = TypeClasses.flatmap(noeffect ∘ f, eff)
TypeClasses.flatmap(f, eff::Eff) = Eff(eff.effectful, Continuation(eff.cont.functions..., f))
```

In brief, it just stores all functions for later execution in the `Continuation` attribute `cont`. The first function in the `Continuation` is later applied directly to the `eff.effectful`, the second function in `cont` is applied to the result of the first function, the third to the result of that, and so forth (with the addition that all functions return `Eff` which wrap the results). That is it.

---

Let's look at the third ingredient, why the continuation always returns an `Eff` of the very same type.

What is actually the element type of an `Eff`? It is not the typeparameter `Eff{ElementType}`, because `Eff` is defined as `Eff{Effectful, Continuation}`.
We can nevertheless get an intuitive feeling for the element type: When using `map`/`flatmap` like in

```julia
flatmap(eff) do value
  # ...
end
```

The element is the argument to our anonymous function which we map over the container. For example above, the element type would be `typeof(value)`.

For `Eff` the `value` of `flatmap` is specified by whatever function is mapped right befor our call to map. To understand what this is, we need to take a look into whatever is calling our `eff_flatmap`. It turns out this is `ExtensibleEffects.runhandler`. Here is its definition:

```julia
function runhandler(handler, eff::Eff)
  eff_applies(handler, eff.effectful) || return runhandler_not_applies(handler, eff)

  interpreted_continuation = if isempty(eff.cont)
    # `_eff_pure` just calls `eff_pure` and ensures that the return value is of type `Eff`
    Continuation(x -> _eff_pure(handler, x))
  else
    Continuation(x -> runhandler(handler, eff.cont(x)))
  end
  # `_eff_flatmap` just calls `eff_flatmap` and ensures that the return value is of type `Eff`
  _eff_flatmap(handler, interpreted_continuation, eff.effectful)
end
```

It is quite similar to our custom handler we wrote for `State`. In the first line we again check whether our current handler actually applies. For our purposes at the moment, we are only interested in the case where it applies, so we can go on to line 3: Here we construct the actual continuation which is then passed to `eff_flatmap`.
The last line then is already our call to `eff_flatmap` which we wanted to understand in more detail.

Let's summarize the situation and the goal again. It is simpler to follow if we take concrete example. Let's consider that `eff.effectful` is of type `Vector`, and that also `handler = Vector`. We want to understand why the continuation, here `interpreted_continuation`, is returning an `Eff` with element type `Vector` as well.

Looking at the definition of `interpreted_continuation` we can directly read out its return value.

1. In the first case, if `isempty(eff.cont)`, we get an `_eff_pure(Vector, ...)` which indeed will construct an `Eff` with element type `Vector` (the continuation of that `Eff` is still empty).
2. In the second case we get `runhandler(Vector, eff.cont(x))`, which recurses into our very function `runhandler` itself. What does it return?

   1. If the `Vector` handler applies to the next effect `eff.cont(x)::Eff`, we return `eff_flatmap(...)`. Remember `eff_flatmap` belongs to the core interface and indeed for `Vector` always return an `Eff` of element type `Vector`, if everything goes right.
   2. If the `Vector` handler does not apply to the next effect `eff.cont(x)`, we return `runhandler_not_applies(Vector, eff)`. Here is its definition

      ```julia
      function runhandler_not_applies(handler, eff::Eff)
        interpreted_continuation = if isempty(eff.cont)
          Continuation(x -> _eff_pure(handler, x))
        else
          Continuation(x -> runhandler(handler, eff.cont(x)))
        end
        Eff(eff.effectful, interpreted_continuation)
      end
      ```

      The `interpreted_continuation` is constructed exactly identically. The only difference is that instead of calling `eff_flatmap`, we construct an `Eff` which will remember to run our handler for subsequent effects. We are interested in the element type of this returned `Eff`, which is directly defined by what `interpreted_continuation` returns, same as before.

      1. In the first case we have `_eff_pure(Vector, ...)` again, which is an Eff of element type Vector.
      2. In the second case we recurse one more time into our well known `runhandler(Vector, ...)`, what does it return? At this point we already have been once. We have seen all branches our function can take: There was the `_eff_pure(Vector, ...)` branch, which is returning an `Eff` of element type `Vector` quite trivially. There was `_eff_flatmap` which does so as well by definition. Finally there is the recursion branch. Assuming now that the recursion ends, it will itself end in branch one or two and hence also return an `Eff` of element type `Vector`.

To emphasize one implicit but very important aspect of the above argument: Whether things are actually computed or just stored for later execution, to understand which element type the `Eff` has it is not decisive. Everything which matters is what is going to be executed right before. This way the different handlers can actually stack their computations on top of each other without interferring.

## Extensive Example

Finally let's look at a concrete example of running two simple handlers, `Vector` and `Writer`.

```jldoctest
julia> @syntax_eff begin
         a = [2, 3]
         b = Writer("hello.", a*a)
         c = [7, 8]
         d = Writer("world.", a+b+c)
         @pure a, b, c, d
       end
4-element Vector{Writer{String, NTuple{4, Int64}}}:
 Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))
 Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 8, 14))
 Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 7, 19))
 Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 8, 20))

julia> eff = @syntax_eff_noautorun begin
         a = [2, 3]
         b = Writer("hello.", a*a)
         c = [7, 8]
         d = Writer("world.", a+b+c)
         @pure a, b, c, d
       end
Eff(effectful=[2, 3], length(cont)=1)
```

`@syntax_eff` uses autorun and hence is just the same as manually running `@runhandlers (Vector, Writer) @syntax_eff_noautorun ...`, which again translates into

```julia
import ExtensibleEffects: runhandler, runlast_ifpossible, Continuation
runlast_ifpossible(runhandler(Vector, runhandler(Writer, eff)))
```

where `eff` refers to the above variable storing the result of `@syntax_eff_noautorun`. Let's go step by step:

* we start with `runhandler(Writer, eff)`
* the first effect found is not of type Writer, and the `Eff` has still a continuation left, i.e. `eff.cont` is not empty. Hence we construct `Eff(eff.effectful, interpreted_continuation_Writer1)` where `interpreted_continuation_Writer1` recurses into `runhandler` using the handler `Writer`. The inner `eff.cont` is the very first continuation, capturing the entire computation.

  ```julia
  original_continuation1(a) = @syntax_eff_noautorun begin
    b = Writer("hello.", a*a)
    c = [7, 8]
    d = Writer("world.", a+b+c)
    @pure a, b, c, d
  end

  interpreted_continuation_Writer1(a) = runhandler(Writer, original_continuation1(a))
  ```
* `eff2 = runhandler(Writer, eff)` already returns
* `runhandler(Vector, eff2)` is run
* the first effect found is of type Vector, and the `eff2.cont` is again non-empty - it is just our `interpreted_continuation_Writer1`. Hence we will construct a new continuation, let's call it `interpreted_continuation_Vector1`, which recurses into `runhandler` using the handler `Vector`. We can specify it more concretely as

  ```julia
  interpreted_continuation_Vector1 = Continuation(x -> runhandler(Vector, interpreted_continuation_Writer1(x)))
  ```
* this `interpreted_continuation_Vector1` is now passed to `eff_flatmap` for Vector which will call this continuation for all values, here `2` and `3`.
* `interpreted_continuation_Vector1(2)` returns the results of this first branch, which is now a pure value (which you can see at `length(cont)=0`)

  ```julia
  julia> interpreted_continuation_Vector1(2)
  Eff(effectful=NoEffect{Vector{Writer{String, NTuple{4, Int64}}}}(Writer{String, NTuple{4, Int64}}[Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 4, 10)), Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 5, 11))]), length(cont)=0)
  ```

  * Let's look into `interpreted_continuation_Writer1(2)`

    ```julia
    julia> eff3 = interpreted_continuation_Writer1(2)
    Eff(effectful=[4, 5], length(cont)=2)
    ```

    * Given `a = 2`, the original program could continue and returned an `Eff` with the first `Writer` as its effectful value and all the rest as the continuation.

      ```julia
      function original_continuation2(b)
        a = 2
        @syntax_eff_noautorun begin
          c = [7, 8]
          d = Writer("world.", a+b+c)
          @pure a, b, c, d
        end
      end
      ```
    * Then `runhandler(Writer, ...)` was called on top if it, finding an effectful `Writer` and non-empty continuation `original_continuation2` and hence constructing a new continuation

      ```julia
      interpreted_continuation_Writer2 = Continuation(x -> runhandler(Writer, original_continuation2(x)))
      ```

      which is then passed to `eff_flatmap`.
    * Within `eff_flatmap`, the `Writer`'s inner value is extracted, a `4 = 2*2`, and passed on to the continuation.

      ```julia
      julia> interpreted_continuation_Writer2(4)
      Eff(effectful=[7, 8], length(cont)=1)
      ```

      Here what happened step by step:

      * `eff4 = original_continuation2(4)` was called, returning the next program step `Eff(effectful=[4, 5], length(cont)=1)`
      * `runhandler(Writer, eff4)` found a Vector which it cannot handle, and in addition the Effect has a non-empty continuation. Hence it returns an `Eff` with the same effectful (the Vector here) and applying `runhandler(Writer, ...)` to the continuation.

        ```julia
        function original_continuation3(c)
          a = 2
          b = 4
          @syntax_eff_noautorun begin
            d = Writer("world.", a+b+c)
            @pure a, b, c, d
          end
        end

        interpreted_continuation_Writer3 = Continuation(x -> runhandler(Writer, original_continuation3(x)))
        ```

        That is also why the length of `eff.cont` hasn't changed. `original_continuation3` was simply replaced with `interpreted_continuation_Writer3`.
    * finally `eff_flatmap` for `Writer` will work within the returned `Eff` using `Eff`' monad-power, and combine its accumulator to the accumulator of the going-to-be Writer within the `Eff`.

      ```julia
      function ExtensibleEffects.eff_flatmap(continuation, a::Writer)
        eff_of_writer = continuation(a.value)
        map(eff_of_writer) do b
          Writer(a.acc ⊕ b.acc, b.value)
        end
      end
      ```

      As `Eff` does not actually compute anything, but just stores the computation for later execution by appending it to `eff.cont`, we arrive at our final result

      ```julia
      julia> eff3 = interpreted_continuation_Writer1(2)
      Eff(effectful=[7, 8], length(cont)=2)
      ```
  * `runhandlers(Vector, eff3)`

    * it will find an effectful of the correct type and a non-empty continuation, hence creating a continuation

      ```julia
      interpreted_continuation_Vector2(x) = runhandler(Vector, eff3.cont(x))
      ```

      and passing it to `eff_flatmap`
    * `eff_flatmap` will now run it for both of its values `7` and `8`, starting with `7`
    * `eff3.cont(7)` gives a pure result (`length(cont)=0`) of type `NoEffect{Writer}`. Note that this is not a `Writer` effect, but really the end-result which gets wrapped into the trivial effect `NoEffect`.

      ```julia
      julia> eff3.cont(7)
      Eff(effectful=NoEffect{Writer{String, NTuple{4, Int64}}}(Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))), length(cont)=0)
      ```

      How does this came about?

      * `eff3.cont` contains two continuations, the first was `interpreted_continuation_Writer3` (`original_continuation3` followed by `runhandler(Writer, ...)`) and the second came from the extra `map` operation from within `Writer`'s `eff_flatmap` operation.
      * `eff5 = original_continuation3(7)` just continues our original program

        ```julia
        julia> original_continuation3(7)
        Eff(effectful=Writer{String, Int64}("world.", 13), length(cont)=1)
        ```

        The continuation in here is just the last part of our program

        ```julia
        function original_continuation4(d)
          a = 2
          b = 4
          c = 7
          # the following is invalid syntax, because julia cannot typeinfer the effect type which would be needed to call `pure`
          # @syntax_eff_noautorun begin
          #   @pure a, b, c, d
          # end

          # instead we can construct pure manually
          noeffect((a, b, c, d))
        end
        ```
      * `interpreted_continuation_Writer3(7)` is just `runhandler(Writer, eff5)`. The `Writer` handler finds a matching effectful and non-empty continuation, hence creating a new continuation

        ```julia
        interpreted_continuation_Writer4(x) = runhandler(Writer, original_continuation4(x))
        ```

        which is then passed into Writer's `eff_flatmap`

        * `eff_flatmap` extracts the value from the current `Writer`, which is `13` here, and passes it to the continuation
        * The original continuation returns a `NoEffect` effect type which contains the final `Tuple`

          ```julia
          julia> eff6 = original_continuation4(13)
          Eff(effectful=NoEffect{NTuple{4, Int64}}((2, 4, 7, 13)), length(cont)=0)
          ```
        * Calling `runhandler(Writer, eff6)` on it will find non matching effect and empty continuation. Hence it constructs a new `Eff` with original value and new continuation `x -> eff_pure(Writer, x)`.

          ```julia
          julia> runhandler(Writer, eff6)
          Eff(effectful=NoEffect{Writer{typeof(TypeClasses.neutral), NTuple{4, Int64}}}(Writer{typeof(TypeClasses.neutral), NTuple{4, Int64}}(TypeClasses.neutral, (2, 4, 7, 13))), length(cont)=0)
          ```
        * For performance reasons the `Eff` constructor will directly execute any computation which is run on an `NoEffect` effect. This explains the new effectful and `length(cont)=0`. You also see that mapping over `NoEffect` will actually get the wrapped value (here a `Tuple`) as the input, which is then wrapped into `Writer`.
        * `eff_flatmap` will then merge the accumulators, namely the `"world."` from the plain `Writer` as well as the pure accumulator `TypeClasses.neutral` introduced by `eff_pure`. The merging is again realized by mapping over the `Eff`, and as we reached `NoEffect` effect, all computations are now directly executed.
      * at last the old `eff_flatmap` operation gets active, which now merges the accumulators of the inner Writer `"world."` and the outer accumulator `"hello."`. The merging is again realized by mapping over the `Eff`, and as the effect is already `NoEffect`, the computation is executed immediately, giving us

        ```julia
        julia> eff3.cont(7)
        Eff(effectful=NoEffect{Writer{String, NTuple{4, Int64}}}(Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))), length(cont)=0)
        ```
    * `runhandler(Vector, eff3.cont(7))` finds now an `Eff` with empty continuation and different type `Writer`, hence a new `Eff` is build with `eff_pure`

      ```julia
      Eff(eff3.effectful, Continuation(x -> _eff_pure(Vector, x)))
      ```

      For performance improvements, the computation on `NoEffect` is again directly executed, leading into a new `NoEffect` of `Vector` of `Writer`.

      ```julia
      julia> runhandler(Vector, eff3.cont(7))
      Eff(effectful=NoEffect{Vector{Writer{String, NTuple{4, Int64}}}}(Writer{String, NTuple{4, Int64}}[Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))]), length(cont)=0)
      ```
    * The same happens for value `8`, returning another `Eff` of `NoEffect` of `Vector` of `Writer`
    * Using the monad power of `Eff`, both results are now combined by flattening them

      ```julia
      julia> @syntax_flatmap begin
              a = interpreted_continuation_Vector2(7)
              b = interpreted_continuation_Vector2(8)
              @pure [a...; b...]
            end
      Eff(effectful=NoEffect{Vector{Writer{String, NTuple{4, Int64}}}}(Writer{String, NTuple{4, Int64}}[Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13)), Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 8, 14))]), length(cont)=0)
      ```

      The concrete implementation of `Vector`'s `eff_flatmap` is slightly more general, but the principle is the same.
* the continuation for the outer Vector (`interpreted_continuation_Vector1`) is now executed for the second value `3`, too,  giving another `NoEffect` plain value.
* analogously to how the inner two computations have been merged, also the outer two `Eff` of `NoEffect` of `Vector` get merged. We almost have our end result.

  ```julia
  julia> runhandler(Vector, runhandler(Writer, eff))
  Eff(effectful=NoEffect{Vector{Writer{String, NTuple{4, Int64}}}}(Writer{String, NTuple{4, Int64}}[Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13)), Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 8, 14)), Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 7, 19)), Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 8, 20))]), length(cont)=0)
  ```
* Finally `runlast_ifpossible` tries to extract the value out of the `Eff`-`NoEffect` combination.

  ```julia
  julia> runlast_ifpossible(runhandler(Vector, runhandler(Writer, eff)))
  4-element Vector{Writer{String, NTuple{4, Int64}}}:
  Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))
  Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 8, 14))
  Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 7, 19))
  Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 8, 20))
  ```

We have seen the concrete execution of one example, including how the effect system separates lazy computation from actual computation. As long as we haven't reached `NoEffect` and still have unkown handlers to handle, all computation is just lazily stored as functions for later execution. As soon as all handlers are handled, the result is wrapped into the special `NoEffect` effect, on which computation is now executed immediately. From the perspective of the user, the precise timing when something is executed is just an implementation. Hence also `NoEffect` is an implementation detail and you never need to worry about it. Still I hope this helped the interested reader to understand in more detail what is going on behind the scenes.

---

That is it, I hope it is a little bit less magical now, however I myself have to commit that even after implementing the whole package, the power of the extensible effects concept keeps blowing my mind and stays magic.
