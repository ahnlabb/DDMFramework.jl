plugins = Dict{String,Any}()

function add_plugin(name, fun)
    plugins[name] = fun
end

abstract type AbstractPlugin end
#handle(state::AbstractImageState, data) = handle(state, data["image"], data["params"])

struct CollectingPlugin <: AbstractPlugin
    arr::Vector{Any}
end

CollectingPlugin(params::Dict) = CollectingPlugin([])

function handle(state::CollectingPlugin, data)
    push!(state.arr, data)
    "", state
end

function query(state::CollectingPlugin, q)
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

DynamicPluginWrapper(plugin; handle_fun=handle, query_fun=query, html_fun=show_state) =
    DynamicPluginWrapper(plugin, handle_fun, query_fun, html_fun)

handle(p::DynamicPluginWrapper, data) = p.handle_fun(p.plugin, data)
query(p::DynamicPluginWrapper, q) = p.query_fun(p.plugin, q)
show_state(p::DynamicPluginWrapper, req; io) = p.html_fun(p.plugin, req; io)

const PlugTuple = Tuple{AbstractPlugin,AbstractPlugin}
function handle(plugs::PlugTuple, data)
    left = handle(plugs[1], data)
    right = handle(plugs[2], data)
    [left, right]
end

query(p::PlugTuple, q) = [query(p[1], q), query(p[2], q)]

function show_state(p::PlugTuple, req; io)
    show_state(p[1], req; io)
    show_state(p[2], req; io)
end
