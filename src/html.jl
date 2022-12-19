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

function default_plugin_page(name, json)
    string_buffer() do io
        println(io, """<!DOCTYPE html>
        <html lang="en">
        <head>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.3/css/bulma.min.css">
        <link href="https://cdn.jsdelivr.net/npm/jsoneditor@9.5.6/dist/jsoneditor.min.css" rel="stylesheet" type="text/css">
        <script src="https://cdn.jsdelivr.net/npm/jsoneditor@9.5.6/dist/jsoneditor.min.js"></script>
        </head>
        <h1>System and Plugin configuration</h1>
        <body>
            <div class="card">
                <div class="card-content">
                    <div class="content">
                        <div class="columns">
                            <div class="column">
                                <input id="fileJson" type="file" accept=".json" onChange="fileJson()" />
                                <textarea class="textarea" id="jsontext"></textarea>
                            </div>
                            <div class="column">
                                <div id="jsoneditor" style="width: fill;"></div>
                                <div class="field is-grouped">
                                    <p class="control">
                                        <button class="button" onClick="setJson()">Load JSON from text</button>
                                    </p>
                                    <p class="control is-right">
                                        <button class="button is-primary" onClick="post()">Submit</button>
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <script>
                const container = document.getElementById("jsoneditor")
                const jsontext = document.getElementById("jsontext")
                const editor = new JSONEditor(container, {})

                const initialJson = $(JSON.json(json))
                editor.set(initialJson)
                jsontext.value = JSON.stringify(initialJson, null, '  ')
                function setJson() {
                   editor.set(JSON.parse(jsontext.value))
                }

                function fileJson() {
                    let fileToLoad = document.getElementById("fileJson").files[0];
                    let fileReader = new FileReader();
                    fileReader.onload = function(fileLoadedEvent) {
                        let textFromFileLoaded = fileLoadedEvent.target.result;
                        jsontext.value = textFromFileLoaded
                        setJson()
                    };
                    fileReader.readAsText(fileToLoad, "UTF-8");
                }

                function post() {
                    const formData = new FormData();
                    formData.append("analysis", "$(name)");


                    const content = JSON.stringify(editor.get());
                    const blob = new Blob([content], { type: "application/json"});
                    formData.append("parameters", blob);

                    const request = new XMLHttpRequest();
                    request.open("POST", "/api/v1/experiments/");
                    request.send(formData);

                    request.onload = function() {
                        if (request.status === 200) {
                            window.location.href = "/experiments/";
                        } else {
                            console.log(request.response);
                        }
                    }
                          
                }
            </script>
        </body>
        """)
        println(io, "</body>")
        println(io, "</html>")
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
                Exp. $(exp_id): $(d.metadata.created) $(d.data)
            </div>
        </div>
    </div>
    """
end
