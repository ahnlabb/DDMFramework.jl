plugins = Dict{String,Any}()

function add_plugin(name, fun)
    plugins[name] = fun
end

function add_plugin(plugin)
    plugins[name(plugin)] = plugin
end

abstract type AbstractPlugin end
#handle(state::AbstractImageState, data) = handle(state, data["image"], data["params"])

function plugin_page(plugin, req)
    default_plugin_page(req[:params][:plugin], Dict())
end

struct CollectingPlugin <: AbstractPlugin
    arr::Vector{Any}
end

CollectingPlugin(params::Dict) = CollectingPlugin([])

function handle_update(state::CollectingPlugin, data)
    push!(state.arr, data)
    "", state
end

function query_state(state::CollectingPlugin, q)
    json(state.arr)
end

function show_state(state, req; io)
    try
        Base.show(io, MIME"text/html"(), state)
    catch MethodError
        Base.show(io, MIME"text/plain"(), state)
    end
end

function Base.show(io::IO, ::MIME"text/html", state::CollectingPlugin)
    println(io, "<pre>")
    for r in state.arr
        show(io, r)
        println(io,"")
    end
    println(io, "</pre>")
end

function Base.show(io::IO, state::CollectingPlugin)
    n = length(state.arr)
    print(io, "CollectingPlugin: $(n) entr" * (n == 1 ? "y" : "ies"))
end

struct DynamicPluginWrapper <: AbstractPlugin
    plugin
    handle_fun::Base.Callable
    query_fun::Base.Callable
    html_fun::Base.Callable
end

DynamicPluginWrapper(plugin; handle_fun=handle, query_fun=query_state, html_fun=show_state) =
    DynamicPluginWrapper(plugin, handle_fun, query_fun, html_fun)

handle_update(p::DynamicPluginWrapper, data) = p.handle_fun(p.plugin, data)
query_state(p::DynamicPluginWrapper, q) = p.query_fun(p.plugin, q)
show_state(p::DynamicPluginWrapper, req; io) = p.html_fun(p.plugin, req; io)

const PlugTuple = Tuple{AbstractPlugin,AbstractPlugin}
function handle_update(plugs::PlugTuple, data)
    left = handle_update(plugs[1], data)
    right = handle_update(plugs[2], data)
    [left, right]
end

query_state(p::PlugTuple, q) = [query_state(p[1], q), query_state(p[2], q)]

function show_state(p::PlugTuple, req; io)
    show_state(p[1], req; io)
    show_state(p[2], req; io)
end

struct MultiPointAnalysisMeta
    analysis
    name::String
    keyfun
    keytest
end

function schema(mpa::MultiPointAnalysisMeta)
    schema = Dict(
        "query" => "Query",
        "Query" => Dict(
            name(mpa) => name(mpa),
            "fov" => "FOV"
        ),
        "FOV" => Dict(
        )
    )
end

query_resolvers(fields...) = Dict("Query" => Dict(fields...))

function resolvers(mpa::MultiPointAnalysisMeta)
    query_resolvers(
                   name(mpa) => (parent, args) -> collect_state(state, args),
                   "fov" => (parent, args) -> get_fovs(state, args)
                  )
end

struct MultiPointAnalysis <: AbstractPlugin
    meta::MultiPointAnalysisMeta
    config::Dict{String,Any}
    fov_arr
end

multipoint(analyisis, name::String, keyfun; keytest=(==)) = MultiPointAnalysisMeta(analysis, name, keyfun, keytest)

FOV = Pair{Any, Array{DataFrame}}
(a::MultiPointAnalysisMeta)(config) = MultiPointAnalysis(a, config, FOV[])

name(p::MultiPointAnalysisMeta) = p.name

function add_key_columns!(df, key::NT) where NT <: NamedTuple
    for (k, v) in pairs(key)
        df[!, k] .= v
    end
    df
end

function add_key_columns!(df, key)
    df[!, :key] .= key
    df
end

function collect_objects(state::MultiPointAnalysis)
    objects = DataFrame()
    for (fov_id, fov) in enumerate(state.fov_arr)
        key, data = fov
        for (t, prop) in enumerate(data)
            df = copy(prop)
            df[!, :fov_id] .= fov_id
            df[!, :t] .= t
            add_key_columns!(df, key)
            append!(objects, df)
        end
    end
    objects
end

function get_fov!(state::MultiPointAnalysis, params)
    key = state.meta.keyfun(params)
    fov_id = findfirst(state.fov_arr) do (k, _)
        state.meta.keytest(key, k) 
    end
    if isnothing(fov_id)
        fov = FOV(key,[])
        push!(state, fov)
        return fov
    end
    return state.fov_arr[fov_id]
end

function handle_update(state::MultiPointAnalysis, data)
    image = data["image"]
    fov = get_fov!(state, metadata(image))

    props = state.meta.analysis(image, state.config)

    push!(fov, props)

    ("0", state)
end

function query_state(state::MultiPointAnalysis, query)
    execute_query(query["query"], schema(state.meta), resolvers(state.meta)) |> JSON.json
end

function show_state(p::MultiPointAnalysis, req; io)
end

struct Map <: AbstractPlugin
    fun
    plugins::Vector{AbstractPlugin}
end

function Map(fun, plugins...)
    function init(config)
        states = map(plugins) do p
            p(config[name(p)])
        end
        Map(fun, states)
    end
end

function handle_update(plugin::Map, data)
    updates = map(plugin.plugins) do p
        _, state = handle_update(p, data)
        state
    end
    "0", Map(plugin.fun, updates)
end

function query_state(p::Map, q)
    objects = map(collect_objects, p.plugins)
    p.fun(objects..., q)
end
