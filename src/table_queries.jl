table_filters = Dict(
    "bin" => function bin(data,sel,n)
        data = filter(!isnan, data)
        if sel == 1
            hi = quantile(data,sel/n)
            row -> row < hi
        elseif sel == n
            lo = quantile(data, (sel-1)/n)
            row -> row > lo
        else
            lo, hi = quantile(data, [(sel-1/n, sel/n)])
            row -> lo <= row < hi
        end
    end,
    
    ">" => function gt(data, v)
        >(v)
    end,
    "<" => function lt(data, v)
        <(v)
    end,   
    "max" => function _max(data)
        ==(maximum(data))
    end,
    "eq" => function gt(data, v)
        ==(v)
    end
)

function add_filter!(filt_generator, key)
    if haskey(table_filters, key)
        error("filter \"$key\" already exists")
    else
        table_filter[key] = filt_generator
    end
end



function if_arg_update(f, data, args, key)
    if haskey(args, key)
        f(data, args[key])
    else
        data
    end
end

function filter_data(state::LazyDF, args)
    if_arg_update(data, args, "filter") do data, filt_arg
        filters = mapfoldl(vcat, filt_arg; init=Pair{String, Base.Callable}[]) do (column, filters)
            map(filters) do filt
                op = table_filter[filt["op"]](data[!,column], filt["args"]...)
                column => op
            end
        end
        reduce((d,f) -> filter(f,d), filters;init=data)
    end
end

function sort_and_sample_data(data, args)
    data = if_arg_update(data, args, "order") do data, order
        columns = [o == "asc" ? data[c] : -data[c] for (o,c) in order]
        key_type = Tuple{eltype.(columns)...}
        by(i) = key_type((c[i] for c in columns))
        select(data, sort(1:nrow(data); by))
    end
    
    data = if_arg_update(limit, data, args, "limit")
    
    if_arg_update(data, args, "sample") do data, sample
        n = sample["n"]
        seed = sample["seed"]
        sample_df(data,n,seed)
    end

end
