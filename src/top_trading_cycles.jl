#=
Implement the Top Trading Cycles algorithm. Support both two-sided 
matching market and one-sided matching market problems.

Author: Akira Matsushita

=#
import LightGraphs: DiGraph, simplecycles
import .Util: get_acceptables

# two-sided matching market
"""
    top_trading_cycles(market; inverse=false)

Compute a matching of a two-sided matching market by the TTC 
algorithm.

# Arguments

* `market::TwoSidedMatchingMarket` : The structure of the market that 
  contains two sides of agents (students and schools).
* `inverse::Bool=false`: If true, this function returns a matching
  that is Pareto efficient for schools. Otherwise it returns a 
  Pareto efficient matching for students.

# Returns

* `matching::Matching` : The resulting matching of the TTC algorithm.
"""
function top_trading_cycles(market::TwoSidedMatchingMarket; inverse::Bool=false)
    if inverse
        agents, objects = market.schools, market.students
    else
        agents, objects = market.students, market.schools
    end 

    # matrix of acceptable/unacceptable agents
    is_acceptable = get_acceptables(objects.prefs, agents.size)

    # IDs representing unmatched
    agent_unmatched, object_unmatched = 0, 0

    # Numbers of agents'/objects' vacant slots
    nums_agents_vacant = copy(agents.caps)
    nums_objects_vacant = copy(objects.caps)

    # Lengths of preferences
    len_agent_prefs = [size(p, 1) for p in agents.prefs]
    len_object_prefs = [size(p, 1) for p in objects.prefs]

    # Next objects/agents pointing at
    next_object_ranks = ones(Int, agents.size)
    next_agent_ranks = ones(Int, objects.size)
    next_objects = Vector{Int}(agents.size)
    next_agents = Vector{Int}(objects.size)

    agents_remaining::Int = agents.size
    objects_remaining::Int = objects.size

    # matching
    matching = Matching(agents.size, objects.size)

    total_size = agents.size + objects.size
    adj_mat = Matrix{Bool}(total_size, total_size)

    # Main loop
    while agents_remaining > 0 && objects_remaining > 0
        adj_mat .= false

        # set objects that agents point at
        for a in 1:agents.size
            if nums_agents_vacant[a] > 0
                while true
                    if next_object_ranks[a] > len_agent_prefs[a]
                        next_objects[a] = agent_unmatched
                        nums_agents_vacant[a] = 0
                        agents_remaining -= 1
                        break
                    end
                    obj = agents.prefs[a][next_object_ranks[a]]
                    # pointing herself
                    if obj == agent_unmatched
                        next_objects[a] = agent_unmatched
                        nums_agents_vacant[a] = 0
                        agents_remaining -= 1
                        break
                    end
                    # pointing at an object
                    if nums_objects_vacant[obj] > 0 && is_acceptable[a, obj]
                        next_objects[a] = obj
                        break
                    end
                    next_object_ranks[a] += 1
                end

                next_obj = next_objects[a]
                if next_obj != agent_unmatched
                    adj_mat[a, agents.size+next_obj] = true
                end
            end
        end

        # set agents that objects point at
        for o in 1:objects.size
            if nums_objects_vacant[o] > 0
                while true
                    if next_agent_ranks[o] > len_object_prefs[o]
                        next_agents[o] = object_unmatched
                        nums_objects_vacant[o] = 0
                        objects_remaining -= 1
                        break
                    end
                    age = objects.prefs[o][next_agent_ranks[o]]
                    # pointing itself
                    if age == object_unmatched
                        next_agents[o] = age
                        nums_objects_vacant[o] = 0
                        objects_remaining -= 1
                        break
                    end
                    # pointing at an agent
                    if nums_agents_vacant[age] > 0
                        next_agents[o] = age
                        break
                    end
                    next_agent_ranks[o] += 1
                end

                next_age = next_agents[o]
                if next_age != object_unmatched
                    adj_mat[agents.size+o, next_age] = true
                end
            end
        end

        # detect cycles
        cycles = simplecycles(DiGraph(adj_mat))
        for c in cycles
            # reorder a cycle so that odd elements are agents
            if c[1] > agents.size
                first_obj = shift!(c)
                Base.push!(c, first_obj)
            end
            for i in 1:(size(c, 1) >> 1)
                agent = c[2*i-1]
                object = c[2*i] - agents.size
                matching[object, agent] = true
                next_object_ranks[agent] += 1
                next_agent_ranks[object] += 1
                nums_agents_vacant[agent] -= 1
                nums_objects_vacant[object] -= 1
                if nums_agents_vacant[agent] == 0
                    agents_remaining -= 1
                end
                if nums_objects_vacant[object] == 0
                    objects_remaining -= 1
                end
            end
        end
    end

    return matching
end


# one-sided matching market
"""
    top_trading_cycles(market, priority, owners)

Compute a matching of a one-sided matching market by the TTC 
algorithm. This function requires all `caps` of agents and objects 
to be one. 

# Arguments

* `market::OneSidedMatchingMarket` : The structure of the market that 
  contains agents and objects.
* `priority::Priority` : The priority of agents.
* `owners::Owners` : The ownership of the objects. The number 
  of owners of each object should be zero or one.

# Returns

* `matching::Matching` : The resulting matching of the TTC algorithm.
"""
function top_trading_cycles(market::OneSidedMatchingMarket, 
    priority::Priority, owners::Owners)
    agents, objects = market.agents, market.objects

    if any(agents.caps .!= 1) || any(objects.caps .!= 1)
        throw(ArgumentError(
            "All elements of `agents.caps` and `objects.caps` should be 1"))
    end

    if any(sum(owners.owners, 1) .> 1)
        throw(ArgumentError(
            "The number of owners of each object should be 0 or 1"))
    end

    if owners.num_agents != agents.size
        throw(ArgumentError(
            "`owners.num_agents` does not match `agents.size`"))
    end

    if owners.num_objects != objects.size
        throw(ArgumentError(
            "`owners.num_objects` does not match `objects.size`"))
    end

    # Ownership structure in each step of the mechanism
    current_possessions = zeros(Int, agents.size)
    current_owners = zeros(Int, objects.size)
    for o in 1:objects.size
        for a in 1:agents.size
            if owners.owners[a, o]
                current_owners[o] = a
                current_possessions[a] = o
            end
        end
    end

    # IDs representing unmatched
    agent_unmatched = 0
    unowned = 0

    # Numbers of agents'/objects' vacant slots
    nums_agents_vacant = copy(agents.caps)
    nums_objects_vacant = copy(objects.caps)

    # Lengths of preferences
    len_agent_prefs = [size(p, 1) for p in agents.prefs]

    # Next objects/agents pointing to
    next_object_ranks = ones(Int, agents.size)
    next_objects = Vector{Int}(agents.size)

    total_size = agents.size + objects.size
    adj_mat = Matrix{Bool}(total_size, total_size)

    # Main loop
    for prior_agent in priority.enum
        adj_mat .= false

        # set objects that agents point to
        for a in 1:agents.size
            if nums_agents_vacant[a] > 0
                while true
                    if next_object_ranks[a] > len_agent_prefs[a]
                        next_objects[a] = agent_unmatched
                        nums_agents_vacant[a] = 0
                        break
                    end
                    obj = agents.prefs[a][next_object_ranks[a]]
                    # point herself
                    if obj == agent_unmatched
                        next_objects[a] = agent_unmatched
                        nums_agents_vacant[a] = 0
                        break
                    end
                    # point to an object
                    if nums_objects_vacant[obj] > 0
                        next_objects[a] = obj
                        break
                    end
                    next_object_ranks[a] += 1
                end

                next_obj = next_objects[a]
                if next_obj != agent_unmatched
                    adj_mat[a, agents.size+next_obj] = true
                end
            end
        end

        # set agents that objects point to
        for o in 1:objects.size
            if nums_objects_vacant[o] > 0
                owner = current_owners[o]
                if owner == unowned
                    adj_mat[agents.size+o, prior_agent] = true
                else
                    adj_mat[agents.size+o, owner] = true
                end
            end
        end

        # detect cycles
        cycles = simplecycles(DiGraph(adj_mat))
        for c in cycles
            # reorder a cycle so that odd elements are agents
            if c[1] > agents.size
                first_obj = shift!(c)
                Base.push!(c, first_obj)
            end
            for i in 1:(size(c, 1) >> 1)
                agent = c[2*i-1]
                object = c[2*i] - agents.size
                cup = current_possessions[agent]
                if cup != agent_unmatched && current_owners[cup] == agent
                    current_owners[cup] = unowned
                end
                current_possessions[agent] = object
                current_owners[object] = agent
                #next_object_ranks[agent] += 1
                nums_agents_vacant[agent] -= 1
                nums_objects_vacant[object] -= 1
            end
        end
    end

    # matching
    matching = Matching(agents.size, objects.size)
    for a in 1:agents.size
        o = current_possessions[a]
        if o != agent_unmatched
            matching[o, a] = true
        end
    end

    return matching
end


"""
    top_trading_cycles(market, priority)

Top Trading Cycles algorithm for a non-existing tenants market. 

# Arguments

* `market::OneSidedMatchingMarket` : The structure of the market that 
  contains agents and objects.
* `priority::Priority` : The priority of agents.

# Returns

* `matching::Matching` : The resulting matching of the TTC algorithm.
"""
function top_trading_cycles(market::OneSidedMatchingMarket, 
    priority::Priority)
    return top_trading_cycles(market, priority, 
        Owners(market.agents.size, market.objects.size))
end
