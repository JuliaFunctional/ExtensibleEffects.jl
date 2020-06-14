using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Suppressor
splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun

# Helpers
# -------

load(a, prefix="") = @ContextManager function (cont)
  println("$(prefix)before $a")
  result = cont(a)
  println("$(prefix)after $a")
  result
end


load_safe(a, prefix="") = @ContextManager function (cont)
  value = [a, a+1]
  println("$(prefix)before $(value)")
  result = cont(value)
  println("$(prefix)after $(value)")
  empty!(value)
  result
end

# Test
# ----

# compared to syntax_flatmap, syntax_eff can correctly handle
# - alternating Vector and Single-Element-Containers
# - alternating ContextManager and Nothing/Const


test_safe() = @runcontextmanager_ @syntax_eff begin
  a = [10,30]
  b = load_safe(a, "1: ")
  c = collect(1:length(b))
  d = load_safe(a + c, "2: ")
  @pure a, b, c, d, length(d)
end

@test @suppress_out test_safe() == [
  (10, Int64[], 1, Int64[], 2),
  (10, Int64[], 2, Int64[], 2),
  (30, Int64[], 1, Int64[], 2),
  (30, Int64[], 2, Int64[], 2),
]
# CAUTION: running contextmanager last leads to maybe unintuitive execution order
@test splitln(@capture_out test_safe()) == [
  "1: before [10, 11]",
  "2: before [11, 12]",
  "2: before [12, 13]",
  "1: before [30, 31]",
  "2: before [31, 32]",
  "2: before [32, 33]",
  "2: after [32, 33]",
  "2: after [31, 32]",
  "1: after [30, 31]",
  "2: after [12, 13]",
  "2: after [11, 12]",
  "1: after [10, 11]",
]

# If you want tight execution order which releases as soon as possible, you need to run Vector and ContextManager at
# once and at last
test_safe2() = @runhandlers (ContextManagerCombinedHandler(Vector),) @syntax_eff_noautorun begin
  a = [10,30]
  b = load_safe(a, "1: ")
  c = collect(1:length(b))
  d = load_safe(a + c, "2: ")
  @pure a, b, c, d, length(d)
end

@test @suppress_out test_safe2() == [
  (10, Int64[], 1, Int64[], 2),
  (10, Int64[], 2, Int64[], 2),
  (30, Int64[], 1, Int64[], 2),
  (30, Int64[], 2, Int64[], 2),
]
@test splitln(@capture_out test_safe2()) == [
  "1: before [10, 11]",
  "2: before [11, 12]",
  "2: after [11, 12]",
  "2: before [12, 13]",
  "2: after [12, 13]",
  "1: after [10, 11]",
  "1: before [30, 31]",
  "2: before [31, 32]",
  "2: after [31, 32]",
  "2: before [32, 33]",
  "2: after [32, 33]",
  "1: after [30, 31]",
]




load_test1() = @runhandlers (ContextManagerCombinedHandler(Vector), Identity, Nothing) @syntax_eff_noautorun begin
  a = [1, 4, 7]
  b = load(a+1, "first ")
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1, "second ")
  @pure a, b, c, d
end

@test @suppress_out load_test1() == [Identity((1,2,3,4)), nothing, Identity((7, 8, 15, 16))]
@test splitln(@capture_out load_test1()) == [
  "first before 2"
  "second before 4"
  "second after 4"
  "first after 2"
  "first before 5"
  "first after 5"
  "first before 8"
  "second before 16"
  "second after 16"
  "first after 8"
]

load_test2() = @runcontextmanager_ @syntax_eff begin
  a = [1, 4, 7]
  b = load(a+1, "first ")
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1, "second ")
  @pure a, b, c, d
end

@test @suppress_out load_test2() == [Identity((1,2,3,4)), nothing, Identity((7, 8, 15, 16))]
@test splitln(@capture_out load_test2()) == [
  "first before 2"
  "second before 4"
  "first before 5"
  "first before 8"
  "second before 16"
  "second after 16"
  "first after 8"
  "first after 5"
  "second after 4"
  "first after 2"
]

load_test3() = @runhandlers ContextManagerCombinedHandler(Vector) @syntax_eff noautorun(Vector) begin
  a = [1, 4, 7]
  b = load(a+1, "first ")
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1, "second ")
  @pure a, b, c, d
end
@test @suppress_out load_test3() == [Identity((1,2,3,4)), nothing, Identity((7, 8, 15, 16))]
@test splitln(@capture_out load_test3()) == [
  "first before 2"
  "second before 4"
  "second after 4"
  "first after 2"
  "first before 5"
  "first after 5"
  "first before 8"
  "second before 16"
  "second after 16"
  "first after 8"
]
