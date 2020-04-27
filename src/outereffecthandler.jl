using ExprParsers

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

function insert_into_runhandlers!(handler, expr::Expr)
  found_runhandlers = _insert_into_runhandlers!(handler, expr)
  found_runhandlers ? expr : :(ExtensibleEffects.runhandlers($handler, $expr))
end

macro insert_into_runhandlers(handler, expr)
  expr = macroexpand(__module__, expr)
  esc(ExtensibleEffects.insert_into_runhandlers!(handler, expr))
end
