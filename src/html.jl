function simple_layout(view_fun)
    function wrap(req)
        string_buffer() do io
            println(io, """<!DOCTYPE html>
            <html lang="en">
            <head>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.3/css/bulma.min.css">
            </head>
            <body>""")
            view_fun(req; io=io)
            println(io, "</body>")
            println(io, "</html>")
        end
    end
end

function view_experiments(req; io=IOBuffer())
    for exp_id in keys(req[:db])
        println(io, """<a href="/experiments/$exp_id/">$(show_entry(req[:db], exp_id))</a>""")
    end
    return io
end

function view_plugins(req; io=IOBuffer())
    for p in keys(plugins)
        println(
            io,
            """
            <a href="/plugins/$p/">
                <div class="card">
                    <div class="card-content">
                        <div class="content">
                            $p : $(plugins[p])
                        </div>
                    </div>
                </div>
            </a>
            """
        )
    end
    return io
end

function show_entry(db, exp_id)
    d = db.dict[exp_id]
    """
    <div class="card">
        <div class="card-content">
            <div class="content">
                $(d.metadata.created) $(d.data)
            </div>
        </div>
    </div>
    """
end
