using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Suppressor
splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun


# State
# -----

state_flatmap = @syntax_flatmap begin
  a = State(x -> (x+2, x*x))
  b = State(x -> (a + x, x))
  @pure a, b
end
@test state_flatmap(3) == ((5,14), 9)

state_eff = @runstate @syntax_eff begin
  a = State(x -> (x+2, x*x))
  b = State(x -> (a + x, x))
  @pure a, b
end
@test state_eff(3) == ((5,14), 9)

# nesting Callable and State works well, because Callable uses `@insert_into_runhandlers` to add its handler.
callable_state_eff = @runcallable @runstate @syntax_eff begin
  v = [1,3,4]
  a = State(s -> (v+s, s*s))
  o = isodd(a) ? Option(100) : Option()
  b = Callable(x -> x + a + o)
  @pure v, a, o, b
end

vector, state = callable_state_eff(1)(3)
@test state == 6561
@test vector == [nothing, nothing, Identity((4, 85, 100, 186))]

# CAUTION: the other way around it does not interact well, actually we implemented to throw an error
@test_throws ErrorException @runstate @runcallable @syntax_eff begin
  v = [1,3,4]
  a = State(s -> (v+s, s*s))
  o = isodd(a) ? Option(100) : Option()
  b = Callable(x -> x + a + o)
  @pure v, a, o, b
end

# We could have allowed for this interaction as well, using `@insert_into_runhandlers`, however this would lead
# to non-well-formed results:
# The outer level should be a State then, however it is not, it just has a plain Callable inside, without added state,
# while the state is actually added WITHIN the callable.
