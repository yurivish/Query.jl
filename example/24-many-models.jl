using Query, DataFrames, GLM, RCall

R"""
library(gapminder)
x <- gapminder
"""

df = @rget x

q = @from i in df begin
    @group i by i.country into g
    @let model = lm(lifeExp ~ year, g)
    @let residuals::Vector{Float64} = residuals(model)
    @select residuals
    @collect
end

println(q)
