using Distributions

"""Helper function for trapezoidal rule"""
function trapz(x, y)
    return sum((x[2:end] - x[1:(end - 1)]) .* (y[2:end] + y[1:(end - 1)])) * 0.5
end

"""
Run the model for a given action and SOW

Expected Annual Damages are computed using the trapezoidal rule
"""
function run_sim_house(a::Action, sow::SOW, p::ModelParams, printtest::Bool, returneads::Bool)
    housevalue = p.house.value_usd
    house_disc = sow.house_discount
    # first, we calculate the cost of elevating the house
    construction_cost = elevation_cost(p.house, a.Δh_ft)

    # we don't need to recalculate the steps of the trapezoidal integral for each year
    storm_surges_ft = range(
        quantile(sow.surge_dist, 0.0005); stop=quantile(sow.surge_dist, 0.9995), length=130
    )

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

    # demand_surge = eads ./ 5 # creates the demand surge based on house damage and 20% max surge
    # if printtest
    #     print("Demand Surge: ", eads, "\n", "\n")
    # end

    # demand_surge = ones(length(demand_surge)) .+ demand_surge # adds 1 to the demand surge % so it can be multiplied with the eads
    # eads = eads .* demand_surge # multiplies eads with the demand surge factor

    # if printtest
    #     print("EAD: ", eads, "\n", "\n")
    # end


    housevalues = []
    for n in 1:length(eads)
        if printtest
            print("Housing discount rates: ", house_disc, " at ", n, " years", "\n")
        end

        eads[n] = eads[n] * housevalue # converts the new damages with demand surge to usd

        housevalue = housevalue * (1 + house_disc)
        push!(housevalues, housevalue)
        if n == 24
            house_disc = house_disc - 0.005
        end
        if n == 74
            house_disc = house_disc - 0.005
        end
    end

    #identical as above but without a for loop and easier to print
    # house_drs = map(p.years) do year
    #     if year - minimum(p.years) > 24
    #         house_dr = (1.045) ^ 24 * (1.004) ^ (year - minimum(p.years) - 24) 

    #     # elseif year - minimum(p.years) > 74
    #     #     house_dr = (1 + sow.house_discount - 0.01) ^ (year - minimum(p.years)) 
    #     else house_dr = (1 + sow.house_discount) ^ (year - minimum(p.years))
    #     end
    # end

    # if printtest
    #     print("Housing value multiplier: ", house_drs, "\n", "\n")
    # end

    # eads = eads * housevalue .* house_drs 
    
    if printtest
        print("EAD given housing val. and discount: ", eads, "\n", "\n")
    end 
    
    years_idx = p.years .- minimum(p.years)
    discount_fracs = (1 - sow.discount_rate) .^ years_idx
    ead_npv = sum(eads .* discount_fracs)

    if returneads
        return (-(ead_npv + construction_cost), housevalues )
    end

    return -(ead_npv + construction_cost)
end

