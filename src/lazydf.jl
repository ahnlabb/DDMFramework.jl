struct LazyDF
    df
    transforms
    selection
end

struct LimitDF
    df
    n
end

LazyDF(df; kwtf...) = LazyDF(df, Dict(String(k) => v for (k,v) in kwtf))
LazyDF(df, transforms) = LazyDF(df, transforms, collect(1:DataFrames.nrow(df)))

function Base.filter(filt, df::LazyDF)
    #deleteat!(df.selection, (filt[2]).(df[filt[1]]))
    select(df, (filt[2]).(df[filt[1]]))
end

select(df::LazyDF, sel) = LazyDF(df.df, df.transforms, df.selection[sel])
limit(df::LazyDF, n::Int64) = LimitDF(df, n)
function Base.getindex(df::LimitDF, i...)
    if length(df.df[i...]) < df.n
        df.df[i...][1:end]
    else
        df.df[i...][1:df.n]
    end
end

DataFrames.nrow(df::LazyDF) = length(df.selection)

function Base.getindex(t::LazyDF, idx, col)
    col = String(col)
    if haskey(t.transforms, col)
        columns, op = t.transforms[col]
        op((t[idx, c] for c in columns)...)
    else
        t.df[t.selection[idx], col]
    end
end

Base.getindex(t::LazyDF, ::typeof(!), col) = t[col]
Base.getindex(t::LazyDF, col::AbstractString) = t[1:DataFrames.nrow(t), col]
Base.getindex(t::LazyDF, col::Symbol) = t[String(col)]

