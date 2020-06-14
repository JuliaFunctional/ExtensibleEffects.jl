using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Suppressor
splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun

result = @syntax_eff begin
    a = NoEffect(1)
    b = NoEffect(a + 5.0)
    @pure a, b
end
@test result == (1, 6.0)
