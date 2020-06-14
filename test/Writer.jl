using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Suppressor
splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun



# Writer
# ------

effwriter = @syntax_eff begin
  a = Writer("hello ", 3)
  b = Writer("world!", 5)
  @pure a, b
end
@test effwriter.acc == "hello world!"
@test effwriter.value == (3, 5)

effwriter2 = @syntax_eff begin
  a = Writer("hello ", 3)
  b = collect(a:a+2)
  c = Writer("world!", b*b)
  @pure a, b, c
end

@test effwriter2.acc == "hello world!world!world!"
@test effwriter2.value == [(3, 3, 9), (3, 4, 16), (3, 5, 25)]

effwriter3 = @runhandlers (WriterHandler("PURE"), Vector) @syntax_eff_noautorun begin
  a = Writer("hello ", 3)
  b = collect(a:a+2)
  c = Writer("world!", b*b)
  @pure a, b, c
end
@test effwriter3.acc == "hello world!world!world!PURE"
@test effwriter3.value == [(3, 3, 9), (3, 4, 16), (3, 5, 25)]
