struct TypeVal{T}
    TypeVal{T}() where T = new{T}()
end

# needed because of https://discourse.julialang.org/t/need-help-on-understanding-type-inference-performance/80600/5
macro specializetype(var, expr)
    var = esc(var)
    expr = esc(expr)
    quote
        let
            f(::Type{$var}) where $var = $expr
            f($var) = $expr
            f($var)
        end
    end
end