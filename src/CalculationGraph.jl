module CalculationGraph
export history, cached, Source, update!

struct Thunk
    fun
    args
end

mutable struct Source
    x
    age::Int
end

mutable struct Cache
    cache
    thunk::Thunk
    age::Int
end

mutable struct State
    cache
    args
    fun
    age::Int
end

Source(v) = Source(v, 1)
_update!(s::Source) = s
Base.getindex(s::Source) = s.x
function Base.setindex!(c::Source, x)
    c.age += 1
    c.x = x
end

mutable struct Memory
    ref
end

function Base.push!(mem::Memory, val)
    mem.ref = val
end

Base.getindex(mem::Memory, ind) = mem.ref
Base.lastindex(mem::Memory) = 1

(t::Thunk)(inputs...) = t.fun(inputs...)

function thunkify(f, cache)
    function _thunk(args)
        Cache(cache, Thunk(f, args), 0)
    end
    _thunk
end

cached(f) = thunkify(f, Memory(nothing))
history(f) = thunkify(f, [])
function state(f; init=nothing)
    function _thunk(args)
        State(Memory(init), args, f, 0)
    end
end

args(s::State) = s.args
(s::State)(inputs...) = s.fun(s.cache[end], inputs...)
function Base.setindex!(s::State, val)
    push!(s.cache, val)
end
Base.getindex(s::State) = s.cache[end]

args(c::Cache) = c.thunk.args
(c::Cache)(inputs...) = c.thunk.fun(inputs...)
Base.getindex(c::Cache) = c.cache[end]
function Base.setindex!(c::Cache, val)
    push!(c.cache, val)
end

""" update!(c::Cache)
"""
update!(c) = _update!(c)[]

function _update!(c)
    newage = 1
    arglist = []
    for arg in args(c)
        res = _update!(arg)
        newage = max(newage, res.age)
        push!(arglist, res[])
    end
    if newage > c.age
        val = c(arglist...)
        c[] = val
        c.age = newage
    end
    c
end

end
