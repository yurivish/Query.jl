using BenchmarkTools

using Query, DataFrames, NamedTuples

data = fill(@NT(name=>"David", age=>38., children=>2), 1_000_000)

df = DataFrame(name=fill("David",1_000_000), age=fill(38.,1_000_000), children=fill(2,1_000_000))

@benchmark @from i in $(df) begin
    @where i.age>30. && i.children >= 2
    @select i
    @collect DataFrame
end

q = @from i in df begin
    @where i.age>30. && i.children >= 2
    @select @NT(Name=>lowercase(i.name))
end

@benchmark collect(q)

@benchmark @from i in $(data) begin
    @where i.age>30. && i.children >= 2
    @select i
    @collect
end

@benchmark @from i in $(data) begin
    @where i.age>30. && i.children >= 2
    @select lowercase(i.name)
    @collect
end
