module DDMFramework
using Mux
using Sockets
using Logging
using ImageMagick
using JSON
using Dates
import HTTP

export add_plugin, handle, query

include("plugins.jl")
include("html.jl")

function experiment(app, req)
    req[:state] = req[:db][parse(Int, req[:params][:experiment_id])]
    app(req)
end

function view_app(req; io)
    state = req[:db][parse(Int, req[:params][:experiment_id])]
    show_state(state, req; io)
end

function logcatch(app, req)
    try
        app(req)
    catch e
        showerror(stderr, e, catch_backtrace())
        rethrow()
    end
end

function logtime(app, req)
    response, t = @timed app(req)
    @info "\"$(req[:uri])\": Response sent after $(t * 1000)ms."
    return response
end

function string_buffer(fun)
    io = IOBuffer()
    fun(io)
    String(take!(io))
end

function multipart(app, req)
    headers = Dict(req[:headers])
    content_type = headers["content-type" ∈ keys(headers) ? "content-type" : "Content-Type"]    
    m = match(r"multipart/form-data; boundary=(.*)$", content_type)
    m === nothing && return "Invalid headers"
    boundary_delimiter = m[1]
    length(boundary_delimiter) > 70 && error("boundary delimiter must not be greater than 70 characters")
    
    data = HTTP.MultiPartParsing.parse_multipart_body(req[:data], boundary_delimiter)
    req[:params][:multipart] = Dict(d.name => parse_multipart(d) for d in data)
    app(req)
end

readimg(io) = ImageMagick.load_(read(io))
mime_mapping = Dict(
    "image/tiff" => readimg,
    "image/tif" => readimg,
    "application/json" => mp -> JSON.Parser.parse(read(mp, String)),
    "text/plain" => mp -> read(mp, String)
)

parse_multipart(multi::HTTP.Multipart) = mime_mapping[multi.contenttype](multi.data)

function handle_post(path, func)
    function app(req)
        (response, update) = func(req)
        push!(req[:db], update)
        return response
    end
    return page(path, mux(multipart, app))
end

function update_experiment(c)
    function app(req)
        exp_id = parse(Int, req[:params][:experiment_id])
        state = req[:db][exp_id]
        (response, update) = func(state, req[:params][:multipart])
        
        return json(Dict(:response => response)), exp_id => update
    end
    return app
end

function initiate_experiment(req)
    analysis = req[:params][:multipart]["analysis"]
    parameters = get(req[:params][:multipart], "parameters", Dict{String,Any}())
    exp_id = next_key(req[:db])
    return string(exp_id), exp_id => plugins[analysis](parameters)
end

function handle_get(path, func)
    function app(request)
        response = func(request[:state], request[:query])
        @info "\"$(req[:uri])\":" response
        return response
    end
    return page(path, app)
end

function query_dict(app, req)
    init = Base.ImmutableDict{String,String}()
    req[:query] = foldl(HTTP.URIs.queryparams(req[:query]); init) do dict, kv
        Base.ImmutableDict{String,String}(dict, kv...)
    end
    app(req)
end

function global_dict_db(db)
    function provide_db(app, req)
        req[:db] = db
        app(req)
    end
end

struct ArrDb
    dict::Dict{Int,Any}
end
ArrDb() = ArrDb(Dict{Int,Any}())

Base.getindex(db::ArrDb, i) = db.dict[i].data
Base.keys(db::ArrDb) = keys(db.dict)
next_key(db::ArrDb) = length(db.dict)

function Base.push!(db::ArrDb, update)
    k, data = update
    cur = get!(db.dict, k) do
        (;metadata=(;created=now()), data)
    end
    push!(db.dict, k => (; cur.metadata, data))
    db
end

function serve_ddm_application(;host=ip"127.0.0.1", port=4443)
    inet = Sockets.InetAddr(host, port)
    server = Sockets.listen(inet)
    db = ArrDb()

    experiment_api =
        mux(handle_post("/", initiate_experiment),
            route("/:experiment_id/",
                  experiment,
                  handle_post("/update", update_experiment(handle_update)),
                  handle_get("/", query),
                  Mux.notfound()
                  ),
            Mux.notfound())

    @app main = (
        Mux.defaults,
        logtime,
        logcatch,
        query_dict,
        page("/plugins/", simple_layout(view_plugins)),
        stack(
            global_dict_db(db),
            route("/api/v1/experiments", experiment_api),
            page("/experiments/", simple_layout(view_experiments)),
            route("/experiments/:experiment_id/", simple_layout(view_app))
        ),
        page("/close", req -> (close(server); "closed")),
        Mux.notfound())

    return server, Mux.serve(main, server=server)
end

end # module
