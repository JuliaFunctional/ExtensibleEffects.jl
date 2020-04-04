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
  esc(syntax_eff(block))
end

iscodeblock(expr::Expr) = expr.head === :block
iscodeblock(other) = false

macro syntax_eff(a, b)
  one_is_codeblock = iscodeblock(a) || iscodeblock(b)
  both_are_codeblocks = iscodeblock(a) && iscodeblock(b)
  @assert one_is_codeblock && !both_are_codeblocks  "one and exactly one of the arguments has to be a codeblock"

  if iscodeblock(a)
    wrapper = :identity
    block = a
    effecthandlers = b
  else
    wrapper = a
    block = b
    effecthandlers = :none
  end

  block = macroexpand(__module__, block)
  esc(syntax_eff(block, wrapper, effecthandlers))
end

macro syntax_eff(wrapper, block, effecthandlers)
  @assert iscodeblock(block) "expecting the middle argument to be the code block"
  block = macroexpand(__module__, block)
  esc(syntax_eff(block, wrapper, effecthandlers))
end

function syntax_eff(block::Expr, extra_wrapper = :identity, effecthandlers = :none)
  _effexpr = monadic(
    :(ExtensibleEffects.TypeClasses.map),
    :(ExtensibleEffects.TypeClasses.flatmap),
    extra_wrapper === :identity ? :(ExtensibleEffects.effect) : :(ExtensibleEffects.effect ∘ $extra_wrapper),
    block)
  # We run NoEffect first, to speed up results
  effexpr = :(ExtensibleEffects.runhandler(ExtensibleEffects.NoEffect, $_effexpr))
  @show effecthandlers typeof(effecthandlers)
  if effecthandlers === :none
    effexpr
  # in general in julia, symbols given from the outside are delivered to a macro as QuoteNode
  elseif effecthandlers == QuoteNode(:autorun)
    :(ExtensibleEffects.autorun($effexpr))
  else
    var, effect_handling = _build_runhandler_expr(effecthandlers)
    quote
      $var = $effexpr
      $effect_handling
    end
  end
end

function _build_runhandler_expr(effecthandlers)
  # create a variable in which we assume to get the result of the syntax_eff
  @gensym vareff
  if effecthandlers isa Expr && effecthandlers.head === :tuple
    # extract tuple directly to have better typeinference
    effect_handling = Base.foldr(effecthandlers.args, init = vareff) do x, acc
      :($acc |> ExtensibleEffects.runhandler($x))
    end
    # return the variable as well as the effect handling
    vareff, :(ExtensibleEffects.runlast($effect_handling))
  else
    # treat effecthandlers at runtime
    vareff, :(ExtensibleEffects.runhandlers($effecthandlers, $vareff))
  end
end
