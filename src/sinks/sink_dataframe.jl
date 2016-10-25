@require DataFrames begin

function DataFrames.DataFrame{T}(source::Enumerable{T})
    return collect(source, DataFrames.DataFrame)
end

DataFrames.ModelFrame{T}(f::DataFrames.Formula, d::Enumerable{T}; kwargs...) = DataFrames.ModelFrame(f, DataFrames.DataFrame(d); kwargs...)

function StatsBase.fit{T<:StatsBase.StatisticalModel}(::Type{T}, f::DataFrames.Formula, source::Enumerable, args...; contrasts::Dict = Dict(), kwargs...)
    mf = DataFrames.ModelFrame(f, source, contrasts=contrasts)
    mm = DataFrames.ModelMatrix(mf)
    y = model_response(mf)
    DataFrames.DataFrameStatisticalModel(fit(T, mm.m, y, args...; kwargs...), mf, mm)
end

function StatsBase.fit{T<:StatsBase.RegressionModel}(::Type{T}, f::DataFrames.Formula, source::Enumerable, args...; contrasts::Dict = Dict(), kwargs...)
    mf = DataFrames.ModelFrame(f, source, contrasts=contrasts)
    mm = DataFrames.ModelMatrix(mf)
    y = model_response(mf)
    DataFrames.DataFrameRegressionModel(fit(T, mm.m, y, args...; kwargs...), mf, mm)
end

function StatsBase.fit{T<:StatsBase.RegressionModel,GTKey,GT<:NamedTuple}(::Type{T}, f::DataFrames.Formula, source::Grouping{GTKey,GT}, args...; contrasts::Dict = Dict(), kwargs...)
    mf = DataFrames.ModelFrame(f, Query.query(source), contrasts=contrasts)
    mm = DataFrames.ModelMatrix(mf)
    y = model_response(mf)
    DataFrames.DataFrameRegressionModel(fit(T, mm.m, y, args...; kwargs...), mf, mm)
end

@generated function _filldf(columns, enumerable)
    n = length(columns.types)
    push_exprs = Expr(:block)
    for i in 1:n
        if columns.parameters[i] <: DataArray
            ex = :( push!(columns[$i], isna(i[$i]) ? NA : get(i[$i])) )
        else
            ex = :( push!(columns[$i], i[$i]) )
        end
        push!(push_exprs.args, ex)
    end

    quote
        for i in enumerable
            $push_exprs
        end
    end
end

function collect(enumerable::Enumerable, ::Type{DataFrames.DataFrame})
    T = eltype(enumerable)
    if !(T<:NamedTuple)
        error("Can only collect a NamedTuple iterator into a DataFrame")
    end

    columns = []
    for t in T.types
        if isa(t, TypeVar)
            push!(columns, Array(Any,0))
        elseif t <: NAable
            push!(columns, DataArray(t.parameters[1],0))
        else
            push!(columns, Array(t,0))
        end
    end
    df = DataFrames.DataFrame(columns, fieldnames(T))
    _filldf((df.columns...), enumerable)
    return df
end

function collect{TS,Provider}(source::Queryable{TS,Provider}, ::Type{DataFrames.DataFrame})
    collect(query(collect(source)), DataFrames.DataFrame)
end

end
