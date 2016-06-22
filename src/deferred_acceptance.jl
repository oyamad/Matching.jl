#=
Deferred Acceptance (DA) algorithm

Author: Daisuke Oyama

=#

# deferred_acceptance

"""
    deferred_acceptance(prop_prefs, resp_prefs)

Compute a stable matching by the deferred acceptance (Gale-Shapley) algorithm.

# Arguments

- `prop_prefs::Matrix` : Array of shape (n+1, m) containing the proposers'
preference orders as columns, where m is the number of proposers and n is that
of the respondants. `prop_prefs[j, i]` is the `j`-th preferred respondant for
the `i`-th proposer, where "respondant `0`" represents "being single".
- `resp_prefs::Matrix` : Array of shape (m+1, n) containing the respondants'
preference orders as columns. `resp_prefs[i, j]` is the `i`-th preferred
proposer for the `j`-th respondant, where "proposer `0`" represents "being
single".

# Returns

- `prop_matches::Vector{Int}` : Vector of length m representing the matches for
the proposers, where `prop_matches[i]` is the repondant who proposer `i` is
matched with.
- `resp_matches::Vector{Int}` : Vector of length n representing the matches for
the respondants, where `resp_matches[j]` is the proposer who repondant `j` is
matched with.
"""
function deferred_acceptance{T<:Integer}(prop_prefs::Matrix{T},
                                         resp_prefs::Matrix{T})
    num_props, num_resps = size(prop_prefs, 2), size(resp_prefs, 2)

    resp_ranks = _prefs2ranks(resp_prefs)

    # IDs representing unmatched
    prop_unmatched, resp_unmatched = 0, 0

    # Index representing unmatched
    resp_unmatched_idx = num_props + 1

    is_single_prop = ones(Bool, num_props)

    # Next resp to propose to
    next_resp = ones(Int, num_props)

    # Props currently matched
    current_props = fill(resp_unmatched_idx, num_resps)

    # Numbers of occupied seats
    nums_occupied = zeros(Int, num_resps)

    # Main loop
    while sum(is_single_prop) > 0
        for p in 1:num_props
            if is_single_prop[p]
                r = prop_prefs[next_resp[p], p]  # p proposes r

                # Prefers to be unmatched
                if r == prop_unmatched
                    is_single_prop[p] = false

                # Unacceptable for r
                elseif resp_ranks[p, r] > resp_ranks[resp_unmatched_idx, r]
                    # pass

                #Some seats vacant
                elseif nums_occupied[r] < 1
                    current_props[r] = p
                    is_single_prop[p] = false
                    nums_occupied[r] += 1

                else
                    current_matched = current_props[r]
                    if resp_ranks[p, r] < resp_ranks[current_matched, r]
                        current_props[r] = p
                        is_single_prop[p] = false
                        is_single_prop[current_matched] = true
                    end
                end
                next_resp[p] += 1
            end
        end
    end

    prop_matches = Array(Int, num_props)
    for p in 1:num_props
        prop_matches[p] = prop_prefs[next_resp[p]-1, p]
    end
    resp_matches = current_props
    resp_matches[resp_matches.==resp_unmatched_idx] = resp_unmatched

    return prop_matches, resp_matches
end


function _prefs2ranks{T<:Integer}(prefs::Matrix{T})
    unmatched = 0
    ranks = similar(prefs)
    m, n = size(prefs)
    for j in 1:n
        for i in 1:m
            k = prefs[i, j]
            if k == unmatched
                ranks[end, j] = i
            else
                ranks[k, j] = i
            end
        end
    end
    return ranks
end
