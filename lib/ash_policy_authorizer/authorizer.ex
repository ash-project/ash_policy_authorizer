defmodule AshPolicyAuthorizer.Authorizer do
  @moduledoc false

  defstruct [
    :actor,
    :resource,
    :query,
    :changeset,
    :data,
    :action,
    :api,
    :verbose?,
    :scenarios,
    :check_scenarios,
    :real_scenarios,
    :access_type,
    policies: [],
    facts: %{true => true, false => false},
    data_facts: %{}
  ]

  @type t :: %__MODULE__{}

  alias Ash.Actions.PrimaryKeyHelpers
  alias AshPolicyAuthorizer.Checker

  @behaviour Ash.Engine.Authorizer

  @impl true
  def initial_state(actor, resource, action, verbose?) do
    %__MODULE__{
      resource: resource,
      actor: actor,
      action: action,
      verbose?: verbose?
    }
  end

  @impl true
  def strict_check_context(_authorizer) do
    [:query, :changeset, :api, :resource]
  end

  @impl true
  def check_context(_authorizer) do
    [:query, :changeset, :data, :api, :resource]
  end

  @impl true
  def check(authorizer, context) do
    check_result(%{authorizer | data: context.data})
  end

  @impl true
  def strict_check(authorizer, context) do
    access_type =
      case AshPolicyAuthorizer.access_type(authorizer.resource) do
        :strict ->
          if Ash.Filter.primary_key_filter?(context.query.filter) do
            :runtime
          else
            :strict
          end

        other ->
          other
      end

    %{
      authorizer
      | query: context.query,
        changeset: context.changeset,
        api: context.api,
        access_type: access_type
    }
    |> get_policies()
    |> do_strict_check_facts()
    |> strict_check_result()
  end

  defp strict_filter(authorizer) do
    {filterable, require_check} =
      authorizer.scenarios
      |> Enum.split_with(fn scenario ->
        Enum.all?(scenario, fn {{check_module, opts}, _value} ->
          AshPolicyAuthorizer.Policy.fetch_fact(authorizer.facts, {check_module, opts}) != :error ||
            check_module.type() == :filter
        end)
      end)

    filter = strict_filters(filterable, authorizer)

    case {filter, require_check} do
      {[], []} ->
        raise "unreachable"

      {_filters, []} ->
        case filter do
          [filter] -> {:filter, filter}
          filters -> {:filter, [or: filters]}
        end

      {_filters, _require_check} ->
        case global_filters(authorizer) do
          nil ->
            maybe_forbid_strict(authorizer)

          {[single_filter], scenarios_without_global} ->
            {:filter_and_continue, single_filter,
             %{authorizer | check_scenarios: scenarios_without_global}}

          {filters, scenarios_without_global} ->
            {:filter_and_continue, [and: filters],
             %{authorizer | check_scenarios: scenarios_without_global}}
        end
    end
  end

  defp strict_filters(filterable, authorizer) do
    filterable
    |> Enum.reduce([], fn scenario, or_filters ->
      and_filter =
        scenario
        |> Enum.filter(fn {check_module, _} ->
          check_module.type() == :filter
        end)
        |> Enum.map(fn
          {{check_module, check_opts}, true} ->
            check_module.auto_filter(authorizer.actor, authorizer, check_opts)

          {{check_module, check_opts}, false} ->
            [not: check_module.auto_filter(authorizer.actor, authorizer, check_opts)]
        end)

      [and_filter | or_filters]
    end)
  end

  defp maybe_forbid_strict(authorizer) do
    if authorizer.access_type == :runtime do
      {:continue, %{authorizer | check_scenarios: authorizer.scenarios}}
    else
      {:error, :forbidden}
    end
  end

  defp global_filters(authorizer, scenarios \\ nil, filter \\ []) do
    scenarios = scenarios || authorizer.scenarios

    global_check_value =
      Enum.find_value(scenarios, fn scenario ->
        Enum.find(scenario, fn {{check_module, _opts} = check, value} ->
          check_module.type == :filter &&
            Enum.all?(scenarios, &(Map.fetch(&1, check) == {:ok, value}))
        end)
      end)

    case global_check_value do
      nil ->
        case filter do
          [] -> nil
          filter -> {scenarios, filter}
        end

      {{check_module, check_opts}, value} ->
        required_status = check_opts[:__auto_filter__] && value

        additional_filter =
          if required_status do
            check_module.auto_filter(authorizer.actor, authorizer, check_opts)
          else
            [not: check_module.auto_filter(authorizer.actor, authorizer, check_opts)]
          end

        scenarios = remove_clause(authorizer.scenarios, {check_module, check_opts})
        new_facts = Map.put(authorizer.facts, {check_module, check_opts}, required_status)
        global_filters(%{authorizer | facts: new_facts}, scenarios, [additional_filter | filter])
    end
  end

  defp remove_clause(scenarios, clause) do
    Enum.map(scenarios, &Map.delete(&1, clause))
  end

  defp check_result(%{access_type: :filter} = authorizer) do
    case authorizer.check_scenarios do
      [] ->
        raise "unreachable"

      [scenario] ->
        case scenario_to_check_filter(scenario, authorizer) do
          {:ok, filter} ->
            {:filter, filter}

          {:error, error} ->
            {:error, error}
        end

      scenarios ->
        scenarios_to_filter(scenarios, authorizer)
    end
  end

  defp check_result(%{access_type: :runtime} = authorizer) do
    Enum.reduce_while(authorizer.data, {:ok, authorizer}, fn record, {:ok, authorizer} ->
      authorizer.scenarios
      |> Enum.reject(&scenario_impossible?(&1, authorizer, record))
      |> case do
        [] ->
          {:halt, {:error, :forbidden, authorizer}}

        scenarios ->
          scenarios
          |> AshPolicyAuthorizer.SatSolver.remove_irrelevant_clauses()
          |> do_check_result(authorizer, record)
      end
    end)
  end

  defp scenarios_to_filter(scenarios, authorizer) do
    result =
      Enum.reduce_while(scenarios, {:ok, []}, fn scenario, {:ok, filters} ->
        case scenario_to_check_filter(scenario, authorizer) do
          {:ok, filter} -> {:cont, {:ok, [filter | filters]}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)

    case result do
      {:ok, filters} -> {:filter, [or: filters]}
      {:error, error} -> {:error, error}
    end
  end

  defp do_check_result(cleaned_scenarios, authorizer, record) do
    if Enum.any?(cleaned_scenarios, &scenario_applies?(&1, authorizer, record)) do
      {:cont, {:ok, authorizer}}
    else
      check_facts_until_known(cleaned_scenarios, authorizer, record)
    end
  end

  defp scenario_applies?(scenario, authorizer, record) do
    Enum.all?(scenario, fn {clause, requirement} ->
      case Map.fetch(authorizer.facts, clause) do
        {:ok, ^requirement} ->
          true

        _ ->
          scenario_applies_to_record?(authorizer, clause, record)
      end
    end)
  end

  defp scenario_applies_to_record?(authorizer, clause, record) do
    case Map.fetch(authorizer.data_facts, clause) do
      {:ok, ids_that_match} ->
        pkey = Map.take(record, Ash.primary_key(authorizer.resource))

        MapSet.member?(ids_that_match, pkey)

      _ ->
        false
    end
  end

  defp scenario_impossible?(scenario, authorizer, record) do
    Enum.any?(scenario, fn {clause, requirement} ->
      case Map.fetch(authorizer.facts, clause) do
        {:ok, value} when value != requirement ->
          true

        _ ->
          scenario_impossible_by_data?(authorizer, clause, record)
      end
    end)
  end

  defp scenario_impossible_by_data?(authorizer, clause, record) do
    case Map.fetch(authorizer.data_facts, clause) do
      {:ok, ids_that_match} ->
        pkey = Map.take(record, Ash.primary_key(authorizer.resource))

        not MapSet.member?(ids_that_match, pkey)

      _ ->
        false
    end
  end

  defp check_facts_until_known(scenarios, authorizer, record) do
    new_authorizer =
      scenarios
      |> find_fact_to_check(authorizer)
      |> check_fact(authorizer)

    scenarios
    |> Enum.reject(&scenario_impossible?(&1, new_authorizer, record))
    |> case do
      [] ->
        {:halt, {:forbidden, authorizer}}

      scenarios ->
        cleaned_scenarios = AshPolicyAuthorizer.SatSolver.remove_irrelevant_clauses(scenarios)

        if Enum.any?(cleaned_scenarios, &scenario_applies?(&1, new_authorizer, record)) do
          {:cont, {:ok, new_authorizer}}
        else
          check_facts_until_known(scenarios, new_authorizer, record)
        end
    end
  end

  defp check_fact({check_module, check_opts}, authorizer) do
    if check_module.type() == :simple do
      raise "Assumption failed"
    else
      authorized_records =
        check_module.check(authorizer.actor, authorizer.data, authorizer, check_opts)

      pkey = Ash.primary_key(authorizer.resource)

      pkeys = MapSet.new(authorized_records, &Map.take(&1, pkey))

      %{
        authorizer
        | data_facts: Map.put(authorizer.data_facts, {check_module, check_opts}, pkeys)
      }
    end
  end

  defp find_fact_to_check(scenarios, authorizer) do
    scenarios
    |> Enum.concat()
    |> Enum.find(fn {key, _value} ->
      not Map.has_key?(authorizer.facts, key) and not Map.has_key?(authorizer.data_facts, key)
    end)
    |> case do
      nil -> raise "Assumption failed"
      {key, _value} -> key
    end
  end

  defp scenario_to_check_filter(scenario, authorizer) do
    filters =
      Enum.reduce_while(scenario, {:ok, []}, fn {{check_module, check_opts}, required_value},
                                                {:ok, filters} ->
        new_filter =
          case check_module.type() do
            :simple ->
              filter_for_simple_check(authorizer, check_module, check_opts, required_value)

            :filter ->
              {:ok, check_module.auto_filter(authorizer.actor, authorizer, check_opts)}

            :manual ->
              filter_for_manual_check(authorizer, check_module, check_opts)
          end

        case new_filter do
          {:ok, nil} -> {:cont, {:ok, filters}}
          {:ok, new_filter} -> {:cont, {:ok, [new_filter | filters]}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)

    case filters do
      {:ok, [filter]} -> {:ok, filter}
      {:ok, filters} -> {:ok, [and: filters]}
      {:error, error} -> {:error, error}
    end
  end

  defp filter_for_manual_check(authorizer, check_module, check_opts) do
    case check_module.check(authorizer.actor, authorizer.data, authorizer, check_opts) do
      {:ok, true} ->
        {:ok, nil}

      {:ok, records} ->
        primary_keys_to_filter(authorizer.resource, records)
    end
  end

  defp filter_for_simple_check(authorizer, check_module, check_opts, required_value) do
    case AshPolicyAuthorizer.Policy.fetch_fact(
           authorizer.facts,
           {check_module, check_opts}
         ) do
      :error ->
        raise "Assumption failed"

      {:ok, value} ->
        if value == required_value do
          {:ok, nil}
        else
          {:ok, impossible: true}
        end
    end
  end

  defp primary_keys_to_filter(resource, records) do
    case PrimaryKeyHelpers.values_to_primary_key_filters(
           resource,
           records
         ) do
      [single] -> single
      pkey_filters -> [or: pkey_filters]
    end
  end

  defp strict_check_result(authorizer) do
    case Checker.strict_check_scenarios(authorizer) do
      {:ok, scenarios} ->
        case Checker.find_real_scenarios(scenarios, authorizer.facts) do
          [] ->
            maybe_strict_filter(authorizer, scenarios)

          _real_scenarios ->
            :authorized
        end

      {:error, :unsatisfiable} ->
        {:error,
         AshPolicyAuthorizer.Forbidden.exception(
           verbose?: authorizer.verbose?,
           facts: authorizer.facts,
           scenarios: []
         )}
    end
  end

  defp maybe_strict_filter(authorizer, scenarios) do
    if authorizer.access_type == :strict do
      {:error,
       AshPolicyAuthorizer.Forbidden.exception(
         verbose?: authorizer.verbose?,
         facts: authorizer.facts,
         scenarios: scenarios
       )}
    else
      strict_filter(%{authorizer | scenarios: scenarios})
    end
  end

  defp do_strict_check_facts(authorizer) do
    new_facts = Checker.strict_check_facts(authorizer)

    %{authorizer | facts: new_facts}
  end

  defp get_policies(authorizer) do
    %{authorizer | policies: AshPolicyAuthorizer.policies(authorizer.resource)}
  end
end
