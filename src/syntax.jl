using Monadic

macro syntax_eff(block::Expr)
  block = macroexpand(__module__, block)
  esc(syntax_eff(block))
end
macro syntax_eff(wrapper, block::Expr)
  block = macroexpand(__module__, block)
  esc(syntax_eff(block, wrapper))
end
macro syntax_eff_run(effecthandlers, block::Expr)
  block = macroexpand(__module__, block)
  var, effect_handling = _build_runeffect_expr(effecthandlers)
  esc(quote
    $var = $(syntax_eff(block))
    $effect_handling
  end)
end
macro syntax_eff_run(effecthandlers, wrapper, block::Expr)
  block = macroexpand(__module__, block)
  var, effect_handling = _build_runeffect_expr(effecthandlers)
  esc(quote
    $var = $(syntax_eff(block, wrapper))
    $effect_handling
  end)
end

function syntax_eff(block::Expr, extra_wrapper = :identity)
  effexpr = monadic(
    :(ExtensibleEffects.TypeClasses.map),
    :(ExtensibleEffects.TypeClasses.flatmap),
    extra_wrapper === :identity ? :(ExtensibleEffects.effect) : :(ExtensibleEffects.effect ∘ $extra_wrapper),
    block)
  # We run NoEffect first, to speed up results
  :(ExtensibleEffects.runeffect(ExtensibleEffects.NoEffect, $effexpr))
end

function _build_runeffect_expr(effecthandlers)
  # create a variable in which we assume to get the result of the syntax_eff
  @gensym vareff
  if effecthandlers isa Expr && effecthandlers.head === :tuple
    # extract tuple directly to have better typeinference
    effect_handling = Base.foldr(effecthandlers.args, init = vareff) do x, acc
      :($acc |> ExtensibleEffects.runeffect($x))
    end
    effect_handling_last = :($effect_handling |> ExtensibleEffects.runlast)
    # return the variable as well as the effect handling
    vareff, effect_handling_last
  else
    # treat effecthandlers at runtime
    # return the variable as well as the effect handling
    vareff, quote
      (Base.foldr($effecthandlers, init = $vareff) do x, acc
        acc |> ExtensibleEffects.runeffect(x)
      end) |> ExtensibleEffects.runlast
    end
  end
end
