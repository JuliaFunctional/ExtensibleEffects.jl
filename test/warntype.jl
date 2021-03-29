using ExtensibleEffects
using DataTypesBasic
using Monadic

f(a, b) = @syntax_eff begin
    a = a
    b = b
    @pure a, b
end

f([1,2,3], Identity(99))

@code_warntype f([1,2,3], Identity(99))
@code_native f([1,2,3], Identity(99))




codetest(x) = @syntax_eff begin
  v = [1,3,4]
  @pure a = x+v
  o = isodd(a) ? Option(100) : Option()
  @pure b = x + a + o
  @pure v, a, o, b
end

@code_native codetest(1)
comparef(x) = [isodd(v+x) ? (v, v+x, 100, v+x+100) : nothing for v in [1,3,4]]
@code_native comparef(1)  # at least same code

@code_warntype codetest(1)  # inference does not work yet...
