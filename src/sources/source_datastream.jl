@require DataStreams begin
using DataStreams
using WeakRefStrings

immutable EnumerableDataStream{T, S<:DataStreams.Data.Source, TC, TSC} <: Enumerable
    source::S
    schema::DataStreams.Data.Schema
end

function query{S<:DataStreams.Data.Source}(source::S)
    if !Data.streamtype(S, Data.Field)
        error("Only sources that support field-based streaming are supported by Query.")
    end

	schema = Data.schema(source)

    col_expressions = Array{Expr,1}()
    columns_tuple_type = Expr(:curly, :Tuple)
    columns_tuple_type_source = Expr(:curly, :Tuple)

    for i in 1:schema.cols
        if schema.types[i] <: WeakRefString
            col_type = String
        elseif schema.types[i] <: Nullable && schema.types[i].parameters[1] <: WeakRefString
            col_type = NAable{String}
        elseif schema.types[i] <: Nullable
            col_type = NAable{schema.types[i].parameters[1]}
        else
            col_type = schema.types[i]
        end

        push!(col_expressions, Expr(:(::), schema.header[i], col_type))
        push!(columns_tuple_type.args, col_type)
        push!(columns_tuple_type_source.args, schema.types[i])
    end
    t_expr = NamedTuples.make_tuple(col_expressions)

    t2 = :(Query.EnumerableDataStream{Float64,Float64,Float64,Float64})
    t2.args[2] = t_expr
    t2.args[3] = typeof(source)
    t2.args[4] = columns_tuple_type
    t2.args[5] = columns_tuple_type_source

    eval(NamedTuples, :(import Query))
    t = eval(NamedTuples, t2)

    e_df = t(source, schema)

    return e_df
end

function length{T, S<:DataStreams.Data.Source, TC,TSC}(iter::EnumerableDataStream{T,S,TC,TSC})
    return iter.schema.rows
end

function eltype{T, S<:DataStreams.Data.Source, TC,TSC}(iter::EnumerableDataStream{T,S,TC,TSC})
    return T
end

function start{T, S<:DataStreams.Data.Source, TC,TSC}(iter::EnumerableDataStream{T,S,TC,TSC})
    return 1
end

function _convertion_helper_for_datastreams(source, row, col, T)
    v = Data.streamfrom(source, Data.Field, Nullable{T}, row, col)
    if isnull(v)
        return NAable{String}()
    else
        return NAable{String}(String(get(v)))
    end
end

@generated function next{T, S<:DataStreams.Data.Source, TC,TSC}(iter::EnumerableDataStream{T,S,TC,TSC}, state)
    constructor_call = Expr(:call, :($T))
    for i in 1:length(TC.types)
        if TC.types[i] <: String
            get_expression = :(Data.streamfrom(source, Data.Field, WeakRefString, row, $i))
        elseif TC.types[i] <: NAable && TSC.types[i].parameters[1] <: WeakRefString
            get_expression = :(_convertion_helper_for_datastreams(source, row, $i, TSC.types[$i].parameters[1]))
        elseif TC.types[i] <: NAable
            get_expression = :(NAable(Data.streamfrom(source, Data.Field, Nullable{$(TC.types[i].parameters[1])}, row, $i)))
        else
            get_expression = :(Data.streamfrom(source, Data.Field, $(TC.types[i]), row, $i))
        end
        push!(constructor_call.args, get_expression)
    end

    quote
    	source = iter.source
        row = state
        a = $constructor_call
        return a, state+1
    end
end

function done{T, S<:DataStreams.Data.Source, TC,TSC}(iter::EnumerableDataStream{T,S,TC,TSC}, state)
    return Data.isdone(iter.source,state,1)
end

end
