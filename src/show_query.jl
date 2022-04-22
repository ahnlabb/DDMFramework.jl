struct Top
    query::Query
end

AbstractTrees.children(query::Query) = query.subquery
AbstractTrees.children(top::Top) = [top.query]
AbstractTrees.printnode(io::IO, query::Top) = print(io, "Query")

function AbstractTrees.printnode(io::IO, query::Query)
    print(io, "$(query.field)")
    if !isempty(query.args)
        print(io, "(")
        _printargs(io, query.args)
        print(io, ")")
    end
end
function _printargs(io, args)
    next = iterate(args)
    while true
        (k,v), state = next
        _printarg(io, k, v)
        next = iterate(args, state)
        next === nothing && break
        print(io, ", ")
    end
end
function _printarg(io, k, v)
    print(io, "$k: ")
    if v isa Dict
        print(io, "{")
        _printargs(io, v)
        print(io, "}")
    else
        show(io, v)
    end
end

function Base.show(io::IO, q::Query)
    print_tree(io, Top(q))
end
