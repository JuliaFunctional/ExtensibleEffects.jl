using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Suppressor
splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun

# Task / Future
# -------------

efftask = @async @syntax_eff begin
  a = @async 3
  b = @async begin sleep(1); 5 end
  @pure a, b
end
@test fetch(efftask) == (3,5)

using Distributed
efffuture = @spawnat :any @syntax_eff begin
  a = @spawnat :any 3
  b = @spawnat :any begin sleep(1); 5 end
  @pure a, b
end
@test fetch(efffuture) == (3,5)
