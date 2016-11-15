using Query, DataFrames, GLM, RCall

R"""
library(gapminder)
library(ggplot2)
x <- gapminder
"""

df = @rget x

q = @from i in df begin
    @group i by i.country into g
    @let model = lm(lifeExp ~ year, g)
    @let residuals = residuals(model)
    @select {country=g.key, data=zip(residuals, g)} into i
    @from j in i.data
    @select {country=convert(String, i.country), continent=convert(String,j[2].continent), j[2].year, j[2].lifeExp, resid=j[1]}
    @collect DataFrame
end

# println(q)

R"""
ggplot($q, aes(year, resid, group = country)) +
    geom_line(alpha = 1 / 3) + 
    facet_wrap(~continent)
"""
