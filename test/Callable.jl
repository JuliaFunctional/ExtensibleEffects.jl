using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Suppressor
splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun


# Callable
# --------

# callable is the only standard type which needs a custom handler
# hence a perfect example of how such custom handlers are lovely integrated into the API

myflatmap = @syntax_flatmap begin
  a = Callable(x -> x+2)
  b = Callable(x -> a + x)
  @pure a, b
end
@test myflatmap(3) == (5, 8)

myeff = Callable(function(args...; kwargs...)
  @runhandlers CallableHandler(args...; kwargs...) @syntax_eff begin
    a = Callable(x -> x+2)
    b = Callable(x -> a + x)
    @pure a, b
  end
end)
@test myeff(3) == (5, 8)

# we provide a custom macro for this common callable pattern which does exactly the same

myeff2 = @runcallable @syntax_eff begin
  a = Callable(x -> x+2)
  b = Callable(x -> a + x)
  @pure a, b
end
@test myeff2(3) == (5, 8)

myeff3 = @runcallable @syntax_eff begin
  v = [1,3,4]
  a = Callable(x -> x+v)
  o = isodd(a) ? Option(100) : Option()
  b = Callable(x -> x + a + o)
  @pure v, a, o, b
end

@test myeff3(1) == [nothing, nothing, Identity((4,5,100,106))]
@test myeff3(2) == [Identity((1,3,100,105)), Identity((3,5,100,107)), nothing]


# Really nice to have: We create optimal code!!!
@code_native myeff3(1)
comparef(x) = [isodd(v+x) ? (v, v+x, 100, v+x+100) : nothing for v in [1,3,4]]
@code_native comparef(1)  # suprisingly, this is even a bit larger in machine code
