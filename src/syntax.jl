using Monadic

"""
    # plain syntax to interprete code to unhandled effects
    unhandled_eff = @syntax_eff begin
      a = [1,2,3]
      b = [a, a*a]
      @pure a, b
    end

    mycustomwrapper(i::Int) = collect(1:i)
    # monadic-like syntax to first apply a wrapper before interpreting code to unhandled effects
    unhandled_eff = @syntax_eff mycustomwrapper begin
      a = [1,2,3]
      b = [a, a*a]
      @pure a, b
    end

    # syntax to interprete code and immediately run the specified effects such that the final type nesting corresponds
    # to the given order of effects
    # e.g. ``(Vector, Option)`` will result into type `Vector{Option{...}}`
    handled = @syntax_eff begin
      a = [1,2,3]
      b = isodd(a) ? Option(a + 3) : Option()
      @pure a, b
    end (Vector, Option)  # always expecting tuple, i.e. if it would only be Vector, the syntax expects ``(Vector,)``

    # syntax to interprete code and immediately run effects using ``ExtensibleEffects.autorun``
    # the order of effects is taken from the code, the first encountered effecttype being the most outer container
    # i.e. the below will result in a type Vector{Option{...}}
    handled = @syntax_eff begin
      a = [1,2,3]
      b = isodd(a) ? Option(a + 3) : Option()
      @pure a, b
    end :autorun
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


"""
    @runhandlers handlers eff

For convenience we provide `runhandlers` function also as a macro.

With this you can easier run left-over handlers from an `@syntax_eff` autorun.

Example
-------
```
@runhandlers WithCall(args, kwargs) @syntax_eff begin
  a = Callable(x -> 2x)
  @pure a
end
```
"""
macro runhandlers(handlers, eff)
  esc(:(ExtensibleEffects.runhandlers($handlers, $eff)))
end
