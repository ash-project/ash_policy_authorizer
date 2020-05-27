defmodule AshPolicyAccess.Filter do
  @doc """
  Returns true if the second argument is a strict subset (always returns the same or less data) of the first
  """
  def strict_subset_of(nil, _), do: true

  def strict_subset_of(_, nil), do: false

  def strict_subset_of(%{resource: resource}, %{resource: other_resource})
      when resource != other_resource,
      do: false

  def strict_subset_of(filter, candidate) do
    if Ash.Filter.empty_filter?(filter) do
      true
    else
      if Ash.Filter.empty_filter?(candidate) do
        false
      else
        {filter, candidate} = cosimplify(filter, candidate)
        AshPolicyAccess.SatSolver.strict_filter_subset(filter, candidate)
      end
    end
  end

  def strict_subset_of?(filter, candidate) do
    strict_subset_of(filter, candidate) == true
  end

  def primary_key_filter?(nil), do: false

  def primary_key_filter?(filter) do
    cleared_pkey_filter =
      filter.resource
      |> Ash.primary_key()
      |> Enum.map(fn key -> {key, nil} end)

    case cleared_pkey_filter do
      [] ->
        false

      cleared_pkey_filter ->
        parsed_cleared_pkey_filter =
          Ash.Filter.parse(filter.resource, cleared_pkey_filter, filter.api)

        cleared_candidate_filter = clear_equality_values(filter)

        strict_subset_of?(parsed_cleared_pkey_filter, cleared_candidate_filter)
    end
  end

  def get_pkeys(%{query: nil, resource: resource}, api, %_{} = item) do
    pkey_filter =
      item
      |> Map.take(Ash.primary_key(resource))
      |> Map.to_list()

    api
    |> Ash.Query.new(resource)
    |> Ash.Query.filter(pkey_filter)
  end

  def get_pkeys(%{query: query}, _, %resource{} = item) do
    pkey_filter =
      item
      |> Map.take(Ash.primary_key(resource))
      |> Map.to_list()

    Ash.Query.filter(query, pkey_filter)
  end

  # The story here:
  # we don't really need to fully simplify every value statement, e.g `in: [1, 2, 3]` -> `== 1 or == 2 or == 3`
  # We could instead just simplify *only as much as we need to*, for instance if the filter contains
  # `in: [1, 2, 3]` and `in: [2, 3, 4]`, we could translate the first to `in: [2, 3] or == 1` and the
  # second one to `in: [2, 3] or == 4`. We should then be able to go about expressing the fact that none
  # of `== 1` and `== 2` are mutually exclusive terms by exchanging them for `== 1 and != 2` and `== 2 and != 1`
  # respectively. This is the methodology behind translating a *value* based filter into a boolean expression.
  #
  # However for now for simplicity's sake, I'm turning all `in: [1, 2]` into `== 1 or == 2` and all `not_in: [1, 2]`
  # into `!= 1 and !=2` for the sole reason that its not worth figuring it out right now. Cosimplification is, at the
  # and of the day, really just an optimization to keep the expression simple. Its not so important with lists and equality
  # but when we add substring filters/greater than filters, we're going to need to improve this logic
  def cosimplify(left, right) do
    {new_left, new_right} = simplify_lists(left, right)

    express_mutual_exclusion(new_left, new_right)
  end

  defp simplify_lists(left, right) do
    values = get_all_values(left, get_all_values(right, %{}))

    substitutions =
      Enum.reduce(values, %{}, fn {key, values}, substitutions ->
        value_substitutions =
          Enum.reduce(values, %{}, fn value, substitutions ->
            case do_simplify_list(value) do
              {:ok, substitution} ->
                Map.put(substitutions, value, substitution)

              :error ->
                substitutions
            end
          end)

        Map.put(substitutions, key, value_substitutions)
      end)

    {replace_values(left, substitutions), replace_values(right, substitutions)}
  end

  defp do_simplify_list(%Ash.Filter.In{values: []}), do: :error

  defp do_simplify_list(%Ash.Filter.In{values: [value]}) do
    {:ok, %Ash.Filter.Eq{value: value}}
  end

  defp do_simplify_list(%Ash.Filter.In{values: [value | rest]}) do
    {:ok,
     Enum.reduce(rest, %Ash.Filter.Eq{value: value}, fn value, other_values ->
       Ash.Filter.Or.prebuilt_new(%Ash.Filter.Eq{value: value}, other_values)
     end)}
  end

  defp do_simplify_list(%Ash.Filter.NotIn{values: []}), do: :error

  defp do_simplify_list(%Ash.Filter.NotIn{values: [value]}) do
    {:ok, %Ash.Filter.NotEq{value: value}}
  end

  defp do_simplify_list(%Ash.Filter.NotIn{values: [value | rest]}) do
    {:ok,
     Enum.reduce(rest, %Ash.Filter.Eq{value: value}, fn value, other_values ->
       Ash.Filter.And.prebuilt_new(%Ash.Filter.NotEq{value: value}, other_values)
     end)}
  end

  defp do_simplify_list(_), do: :error

  defp express_mutual_exclusion(left, right) do
    values = get_all_values(left, get_all_values(right, %{}))

    substitutions =
      Enum.reduce(values, %{}, fn {key, values}, substitutions ->
        value_substitutions =
          Enum.reduce(values, %{}, fn value, substitutions ->
            case do_express_mutual_exclusion(value, values) do
              {:ok, substitution} ->
                Map.put(substitutions, value, substitution)

              :error ->
                substitutions
            end
          end)

        Map.put(substitutions, key, value_substitutions)
      end)

    {replace_values(left, substitutions), replace_values(right, substitutions)}
  end

  defp do_express_mutual_exclusion(%Ash.Filter.Eq{value: value} = eq_filter, values) do
    values
    |> Enum.filter(fn
      %Ash.Filter.Eq{value: other_value} -> value != other_value
      _ -> false
    end)
    |> case do
      [] ->
        :error

      [%{value: other_value}] ->
        {:ok, Ash.Filter.And.prebuilt_new(eq_filter, %Ash.Filter.NotEq{value: other_value})}

      values ->
        {:ok,
         Enum.reduce(values, eq_filter, fn %{value: other_value}, expr ->
           Ash.Filter.And.prebuilt_new(expr, %Ash.Filter.NotEq{value: other_value})
         end)}
    end
  end

  defp do_express_mutual_exclusion(_, _), do: :error

  defp get_all_values(filter, state) do
    state =
      filter.attributes
      # TODO
      |> Enum.reduce(state, fn {field, value}, state ->
        state
        |> Map.put_new([filter.path, field], [])
        |> Map.update!([filter.path, field], fn values ->
          value
          |> do_get_values()
          |> Enum.reduce(values, fn value, values ->
            if value in values do
              values
            else
              [value | values]
            end
          end)
        end)
      end)

    state =
      Enum.reduce(filter.relationships, state, fn {_, relationship_filter}, new_state ->
        get_all_values(relationship_filter, new_state)
      end)

    state =
      if filter.not do
        get_all_values(filter, state)
      else
        state
      end

    state =
      Enum.reduce(filter.ors, state, fn or_filter, new_state ->
        get_all_values(or_filter, new_state)
      end)

    Enum.reduce(filter.ands, state, fn and_filter, new_state ->
      get_all_values(and_filter, new_state)
    end)
  end

  defp do_get_values(%struct{left: left, right: right})
       when struct in [Ash.Filter.And, Ash.Filter.Or] do
    do_get_values(left) ++ do_get_values(right)
  end

  defp do_get_values(other), do: [other]

  defp replace_values(filter, substitutions) do
    new_attrs =
      Enum.reduce(filter.attributes, %{}, fn {field, value}, attributes ->
        substitutions = Map.get(substitutions, [filter.path, field]) || %{}

        Map.put(attributes, field, do_replace_value(value, substitutions))
      end)

    new_relationships =
      Enum.reduce(filter.relationships, %{}, fn {relationship, related_filter}, relationships ->
        new_relationship_filter = replace_values(related_filter, substitutions)

        Map.put(relationships, relationship, new_relationship_filter)
      end)

    new_not =
      if filter.not do
        replace_values(filter, substitutions)
      else
        filter.not
      end

    new_ors =
      Enum.reduce(filter.ors, [], fn or_filter, ors ->
        new_or = replace_values(or_filter, substitutions)

        [new_or | ors]
      end)

    new_ands =
      Enum.reduce(filter.ands, [], fn and_filter, ands ->
        new_and = replace_values(and_filter, substitutions)

        [new_and | ands]
      end)

    %{
      filter
      | attributes: new_attrs,
        relationships: new_relationships,
        not: new_not,
        ors: Enum.reverse(new_ors),
        ands: Enum.reverse(new_ands)
    }
  end

  defp do_replace_value(%struct{left: left, right: right} = compound, substitutions)
       when struct in [Ash.Filter.And, Ash.Filter.Or] do
    %{
      compound
      | left: do_replace_value(left, substitutions),
        right: do_replace_value(right, substitutions)
    }
  end

  defp do_replace_value(value, substitutions) do
    case Map.fetch(substitutions, value) do
      {:ok, new_value} ->
        new_value

      _ ->
        value
    end
  end

  defp clear_equality_values(filter) do
    new_attrs =
      Enum.reduce(filter.attributes, %{}, fn {field, value}, attributes ->
        Map.put(attributes, field, do_clear_equality_value(value))
      end)

    new_relationships =
      Enum.reduce(filter.relationships, %{}, fn {relationship, related_filter}, relationships ->
        new_relationship_filter = clear_equality_values(related_filter)

        Map.put(relationships, relationship, new_relationship_filter)
      end)

    new_not =
      if filter.not do
        clear_equality_values(filter)
      else
        filter.not
      end

    new_ors =
      Enum.reduce(filter.ors, [], fn or_filter, ors ->
        new_or = clear_equality_values(or_filter)

        [new_or | ors]
      end)

    new_ands =
      Enum.reduce(filter.ands, [], fn and_filter, ands ->
        new_and = clear_equality_values(and_filter)

        [new_and | ands]
      end)

    %{
      filter
      | attributes: new_attrs,
        relationships: new_relationships,
        not: new_not,
        ors: Enum.reverse(new_ors),
        ands: Enum.reverse(new_ands)
    }
  end

  defp do_clear_equality_value(%struct{left: left, right: right} = compound)
       when struct in [Ash.Filter.And, Ash.Filter.Or] do
    %{
      compound
      | left: do_clear_equality_value(left),
        right: do_clear_equality_value(right)
    }
  end

  defp do_clear_equality_value(%Ash.Filter.Eq{value: _} = filter), do: %{filter | value: nil}
  defp do_clear_equality_value(%Ash.Filter.In{values: _}), do: %Ash.Filter.Eq{value: nil}
  defp do_clear_equality_value(other), do: other
end
