using Distributions

"""Helper function for trapezoidal rule"""
function trapz(x, y)
    return sum((x[2:end] - x[1:(end - 1)]) .* (y[2:end] + y[1:(end - 1)])) * 0.5
end

"""
Run the model for a given action and SOW

Expected Annual Damages are computed using the trapezoidal rule
"""
function run_sim(a::Action, sow::SOW, p::ModelParams)

    # first, we calculate the cost of elevating the house
    construction_cost = elevation_cost(p.house, a.Δh_ft)


    # we don't need to recalculate the steps of the trapezoidal integral for each year
    storm_surges_ft = range(
        quantile(sow.surge_dist, 0.0005); stop=quantile(sow.surge_dist, 0.9995), length=130
    )

    hm_drs = map(p.years) do year
        # Interpolate between short term housing market dr and long term
        # for each year
        
        # Calculate decay rate assuming the long term estimate is for 100 years 
        # and the short term estimate is for 10 years
        lambda = log(sow.lt_dr / sow.st_dr) / (-90)

        # Based on sampled long term rate representing housing market discount rate at 100 years 
        # calculate discount rate for a year assuming an exponentially declining discount rate
        hm_dr= sow.st_dr * exp(- lambda *  (year - minimum(p.years)))

    end



    eads = map(p.years) do year

        # get the sea level for this year
        slr_ft = sow.slr(year)

        # Compute EAD using trapezoidal rule
        pdf_values = pdf.(sow.surge_dist, storm_surges_ft) # probability of each
        depth_ft_gauge = storm_surges_ft .+ slr_ft # flood at gauge
        depth_ft_house = depth_ft_gauge .- (p.house.height_above_gauge_ft + a.Δh_ft) # flood @ house
        damages_frac = p.house.ddf.(depth_ft_house) ./ 100 # damage
        weighted_damages = damages_frac .* pdf_values # weighted damage
        # Trapezoidal integration of weighted damages
        ead = trapz(storm_surges_ft, weighted_damages) 
        ead 
    end

    # NEED TO FIGURE OUT HOW TO INCLUDE HM DR FOR EACH YEAR
    demand_surge = eads ./ 5 # creates the demand surge based on house damage and 20% max surge
    demand_surge = ones(length(demand_surge)) .+ demand_surge # adds 1 to the demand surge % so it can be multiplied with the eads
    eads = eads .* demand_surge # multiplies eads with the demand surge factor
    eads = eads .* p.house.value_usd # converts the new damages with demand surge to usd
    years_idx = p.years .- minimum(p.years)
    discount_fracs = (1 - hm_drs) .^ years_idx
    ead_npv = sum(eads .* discount_fracs)
    return -(ead_npv + construction_cost)
end

