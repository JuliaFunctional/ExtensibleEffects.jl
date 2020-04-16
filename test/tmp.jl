using TypeClasses
using ExtensibleEffects

myflatmap = @syntax_flatmap begin
  a = Callable(x -> x+2)
  b = Callable(x -> a + x)
  @pure a, b
end
myflatmap(3)

myeff = @syntax_eff begin
  a = Callable(x -> x+2)
  b = Callable(x -> a + x)
  @pure a, b
end
result = myeff |> runhandler(Callable) |> runlast

result(4)(5)
pure(Callable, 4)(1232)
@syntax_eff begin
  a = [1,2,3]
  b = [10,20]
  @pure a, b
end :autorun

using ExtensibleEffects
using TypeClasses
myeff = Callable(function (args...; kwargs...)
  AnotherContext(
    let
    context(Callable) = args, kwargs
    context(AnotherContext) = 42
    @with_context context @syntax_eff begin
      a = Pseudo(1)
      b = Pseudo(2)
      @pure a, b
    end)
end)

macro with_context(context, syntax_eff::Expr)
  @assert syntax_eff.head === :macrocall && syntax_eff.args[1] === Symbol("@syntax_eff")
  
  QuoteNode((a, b))
end

myeff @CallableContext @AnotherContext @syntax_eff begin
  a = Pseudo(1)
  b = Pseudo(2)
  @pure a, b
end
result = myeff |> runhandler(Pseudo) |> runlast

eff = Eff{DataTypesBasic.Identity{Tuple{Int64,Int64,Int64}},Tuple{ExtensibleEffects.var"#5#7"{UnionAll}}}(DataTypesBasic.Identity{Tuple{Int64,Int64,Int64}}((1, 2, 3)), Continuation{Tuple{ExtensibleEffects.var"#5#7"{UnionAll}}}((ExtensibleEffects.var"#5#7"{UnionAll}(Pseudo),)))
