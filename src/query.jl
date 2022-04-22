include("QueryParser.jl")
using .QueryParser

function resolve_field(parent, field, args, dtype, schema, resolvers)
    parent = if haskey(resolvers, dtype) && haskey(resolvers[dtype], field)
        resolvers[dtype][field](parent, args)
    else
        parent[field]
    end
    parent, schema[dtype][field]
end

function resolve_query(query, parent, dtype, schema, resolvers)
    (parent, dtype) = resolve_field(parent, query.field, query.args, dtype, schema, resolvers)
    if isempty(query.subquery)
        parent
    else
        execute_query(query.subquery, schema, resolvers; parent, dtype)
    end
end

function execute_query(query::Vector{Query}, schema, resolvers; parent=nothing, dtype=schema["query"])
    map(query) do q
        q.field => resolve_query(q, parent, dtype, schema, resolvers)
    end |> Dict
end

function execute_query(q::String, args...; kwargs...)
    execute_query(Vector{Query}(parse_selection_set(q)), args...; kwargs...)
end
