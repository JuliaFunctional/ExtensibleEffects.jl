using Monadic

"""
    @syntax_eff begin
      a = [1,2,3]
      b = [a, a*a]
      @pure a, b
    end

Extensible Effects syntax. It applies `effect` to all values which are not prefaced with `@pure`, which lifts them into the `Eff` monad. 
The results are combined using `@syntax_flatmap` on the respective `Eff` monad, which finally is executed using `autorun` algorithm.

Examples
--------

```julia
autohandled_eff = @syntax_eff begin
  a = [1,2,3]
  b = [a, a*a]
  @pure a, b
end

mycustomwrapper(i::Int) = collect(1:i)
# monadic-like syntax to first apply a wrapper before interpreting code to unhandled effects
autohandled_eff = @syntax_eff mycustomwrapper begin
  a = [1,2,3]
  b = [a, a*a]
  @pure a, b
end
```

The Interface
-------------
If you want to add support for new types, you need to provide the following interface: (Vector is only an example)

core function | description
------------- | ------------
`ExtensibleEffects.eff_applies(handler::Type{<:Vector}, effectful::Vector) = true` | specify on which values the handler applies (the handler Vector applies to Vector of course)
`ExtensibleEffects.eff_pure(handler::Type{<:Vector}, value) = [value]` | wrap a plain value into the Monad of the handler, here Vector.
`ExtensibleEffects.eff_flatmap(continuation, effectful::Vector)` | apply a continuation to the current effect (here again Vector as an example). The key difference to plain `TypeClasses.flatmap` is that `continuation` does not return a plain `Vector`, but a `Eff{Vector}`. Applying this `continuation` with a plain `map` would lead `Vector{Eff{Vector}}`. However, `eff_flatmap` needs to return an `Eff{Vector}` instead.
"""
macro syntax_eff(block::Expr)
  block = macroexpand(__module__, block)
  eff = syntax_eff(block)
  esc(:(ExtensibleEffects.autorun($eff)))
end
macro syntax_eff(wrapper, block::Expr)
  block = macroexpand(__module__, block)
  eff = syntax_eff(block, wrapper)
  esc(:(ExtensibleEffects.autorun($eff)))
end
"""
    @syntax_eff_noautorun begin
      a = [1,2,3]
      b = [a, a*a]
      @pure a, b
    end

Extensible Effects syntax which does not run `autorun` routine. As `@syntax_eff`, it applies `effect` to all values which are not prefaced with `@pure`, 
which lifts them into the `Eff` monad. The results are combined using `@syntax_flatmap` on the respective `Eff` monad, which then is directly returned.


Examples
--------

```julia
unhandled_eff = @syntax_eff_noautorun begin
  a = [1,2,3]
  b = [a, a*a]
  @pure a, b
end

mycustomwrapper(i::Int) = collect(1:i)
# monadic-like syntax to first apply a wrapper before interpreting code to unhandled effects
unhandled_eff = @syntax_eff_noautorun mycustomwrapper begin
  a = [1,2,3]
  b = [a, a*a]
  @pure a, b
end
```
"""
macro syntax_eff_noautorun(block::Expr)
  block = macroexpand(__module__, block)
  esc(syntax_eff(block))
end
macro syntax_eff_noautorun(wrapper, block::Expr)
  block = macroexpand(__module__, block)
  esc(syntax_eff(block, wrapper))
end

function syntax_eff(block::Expr, extra_wrapper = :identity)
  @assert iscodeblock(block)  "expecting code block as block argument"
  monadic(
    :(ExtensibleEffects.TypeClasses.map),
    :(ExtensibleEffects.TypeClasses.flatmap),
    extra_wrapper === :identity ? :(ExtensibleEffects.effect) : :(ExtensibleEffects.effect ∘ $extra_wrapper),
    block)
end

iscodeblock(expr::Expr) = expr.head === :block
iscodeblock(other) = false