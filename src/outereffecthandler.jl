using ExprParsers

"""
    @insert_into_runhandlers outer_handler @syntax_eff begin
      # ...
    end

Next to simple Effects which can be directly composed down to plain values and reconstructed again from plain values,
there are also a couple of more elaborate Effects, which values cannot be extracted without providing further context.

Callables are a good example. It is impossible to extract the values of a callable without calling it, or without
constructing another Callable around it.

With all these example the typical flow would be like
```julia

Callable(function (args...; kwargs...)
  callablehandler = CallableHandler(args...; kwargs...)

  SomeOtherNeededContext() do info
    otherhandler = SomeOtherHandler(info)

    # ... possibly further nestings

    @runhandlers (callablehandler, otherhandler #= possible further handlers =#) @syntax_eff begin
      # ...
    end
  end
end)
```

`@inser_into_runhandlers` can be used to simplify and even separate these outer handlers from one another, so that
they can be used as composable interchangeable macros.

For example, here the implementation of `@runcallable` (ignoring macro hygiene)
```julia
macro runcallable(expr)
  :(Callable(function(args...; kwargs...)
    @insert_into_runhandlers(CallableHandler(args...; kwargs...), \$expr)
  end))
end
```
This will search for an existing call to `runhandlers` within the given `expr`, and if found, inserts the
CallableHandler similar to the motivating example above. If no `runhandlers` is found, it will create a new one.

This way, you can compose the nested code-structures very easily.
You only have to be careful, that you always run all outer effects at once, in one single statement,
so that `@insert_into_runhandlers` can actually find the right `runhandlers`.
"""
macro insert_into_runhandlers(handler, expr)
  expr = macroexpand(__module__, expr)
  esc(ExtensibleEffects.insert_into_runhandlers!(handler, expr))
end

insert_into_runhandlers!(handler, symbol::Symbol) = :(ExtensibleEffects.runhandlers($handler, $symbol))
function insert_into_runhandlers!(handler, expr::Expr)
  found_runhandlers = _insert_into_runhandlers!(handler, expr)
  found_runhandlers ? expr : :(ExtensibleEffects.runhandlers($handler, $expr))
end


"""
inserts handler into runhandlers expression and returns true if at least one runhandlers was found
"""
_insert_into_runhandlers!(handler, value) = false
function _insert_into_runhandlers!(handler, expr::Expr)
  if isrunhandlerscall(expr)
    handlerexpr = expr.args[2]  # first argument to macrocall/call
    if handlerexpr isa Expr && handlerexpr.head == :tuple
      insert!(handlerexpr.args, 1, handler)
    else
      handlerexpr_new = :(($handler, $handlerexpr))
      expr.args[2] = handlerexpr_new
    end
    true
  else
    any(expr.args) do subexpr
      _insert_into_runhandlers!(handler, subexpr)
    end
  end
end


const nesteddotparser = EP.NestedDot()
splitdots(value) = [value]
function splitdots(expr::Expr)
  parsed = parse_expr(nesteddotparser, expr)
  insert!(parsed.properties, 1, parsed.base)
end
isrunhandlerscall(value) = false
isrunhandlerscall(expr::Expr) = (
  (expr.head == :macrocall && splitdots(expr.args[1])[end] == Symbol("@runhandlers"))
  || (expr.head == :call && splitdots(expr.args[1])[end] == :runhandlers)
)
