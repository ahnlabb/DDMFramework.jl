module QueryParser
using CombinedParsers
using AbstractTrees

export Query, parse_query, parse_selection_set

struct Query
    field::String
    args::Dict
    subquery::Vector{Query}
end

Query(name, queries...; args=[]) = Query(name, args, collect(queries))

include("show_query.jl")

function join_map(f, parser, delim)
    w = Sequence(1, parser)
    map(w * Repeat((delim * w)[2])) do (head, tail)
        f(pushfirst!(tail, head))
    end
end

@with_names begin
    space    = Repeat( CharIn(" \r\n") )
    hexDigit = CharIn('0':'9','a':'f','A':'F')
    strChars = CharNotIn("\"\\")
    decimal = Repeat1( CharIn('0':'9') )
    exponent = Sequence(
        CharIn("eE"),
        map(v->parse(Int,v), !(('+'|'-'|missing) * decimal))
    )[2]
    fractional = map(
        v->parse(Float64,v), ## result_type inferred and
        Number,              ## defined explicitely as supertype
        !( "." * decimal ) )
    integral   =  "0" | CharIn('1':'9') * Optional(decimal)

    number = Sequence(map(v->parse(Int,v), !(('+'|'-'|missing) * integral)),
                      (fractional | 0),
                      ( exponent | 0 )) do v
                          (i,f,e) = v
                          ((i+f)*10^e)::Union{Float64,Int64}
                      end


    unicodeEscape = "u" * hexDigit * hexDigit * hexDigit * hexDigit
    escape        = "\\" * ( CharIn("\"/\\\\bfnrt") | unicodeEscape )

    lstring = ( space * "\"" * !Repeat(strChars | escape) * "\"" )[3]

    name_initial = CharIn('_', 'A':'Z', 'a':'z')
    restricted_word = Repeat(CharIn('_', 'A':'Z', 'a':'z', '0':'9'))
    name = (space * !(name_initial * restricted_word) * space)[2]

    data = Either{Any}(Any[
        lstring,
        parser("true"=>true),
        parser("false"=>false),
        parser("null"=>nothing),
        number])
    @syntax jsonExpr = ( space * data * space )[2]

    array = ( "[" * Optional(join(Repeat(jsonExpr),",")) * "]" )[2]
    push!(data, array)

    pair = map(lstring * space * ":" * jsonExpr ) do (k,s,d,v)
        Pair{String,result_type(jsonExpr)}(k,v)
    end;

    arg = map(name * ":" * jsonExpr) do (n, _, d)
        n => d
    end

    args = join_map(Dict, arg, ",")
    arg_list = (space * "(" * args * ")" * space)[3]
    arg_obj = map(v -> v, (space * "{" * args * "}" * space)[3])

    push!(data, arg_obj)

    selection = Delayed(Any)
    @syntax selection_set = (space * "{" * Repeat(selection) * "}" * space)[3]

    field = map(name * Optional(arg_list) * Optional(selection_set)) do (field, args, subquery)
        Query(field, subquery...; args = ismissing(args) ? Dict() : args)
    end

    push!(selection, (space * field * space)[2])

    query_start = space * "query" * space
    @syntax query = ( query_start * selection_set )[2]
end;

parse_query(str) = parse(query, str)
parse_selection_set(str) = parse(selection_set, str)

end
