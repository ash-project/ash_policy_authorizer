defmodule AshPolicyAuthorizer do
  @moduledoc """
  An authorization extension for ash resources.

  For more information, see `AshPolicyAuthorizer.Authorizer`
  """
  @type request :: Ash.Engine.Request.t()

  alias Ash.Dsl.Extension

  @doc "Whether or not ash policy authorizer is configured to show policy breakdowns in error messages"
  def show_policy_breakdowns? do
    Application.get_env(:ash_policy_authorizer, :show_policy_breakdowns?) || false
  end

  @doc "Whether or not ash policy authorizer is configured to show policy breakdowns in error messages"
  def log_policy_breakdowns do
    Application.get_env(:ash_policy_authorizer, :log_policy_breakdowns)
  end

  @doc """
  A utility to determine if a given query/changeset would pass authorization.

  *This is still experimental.*
  """
  def strict_check(_actor, %{action: nil}, _) do
    raise "Cannot use `strict_check/3` unless an action has been set on the query/changeset"
  end

  def strict_check(actor, %Ash.Query{} = query, api) do
    authorizer = %AshPolicyAuthorizer.Authorizer{
      actor: actor,
      resource: query.resource,
      action: query.action
    }

    case AshPolicyAuthorizer.Authorizer.strict_check(authorizer, %{
           api: api,
           query: query,
           changeset: nil
         }) do
      {:error, _error} ->
        false

      :authorized ->
        true

      {:filter, _, _} ->
        true

      _ ->
        :maybe
    end
  end

  def strict_check(actor, %Ash.Changeset{} = changeset, api) do
    authorizer = %AshPolicyAuthorizer.Authorizer{
      actor: actor,
      resource: changeset.resource,
      action: changeset.action
    }

    case AshPolicyAuthorizer.Authorizer.strict_check(authorizer, %{
           api: api,
           changeset: changeset,
           query: nil
         }) do
      {:error, _error} ->
        false

      :authorized ->
        true

      {:filter, _, _} ->
        :maybe

      _ ->
        :maybe
    end
  end

  def describe_resource(resource) do
    resource
    |> policies()
    |> describe_policies()
  end

  defp describe_policies(policies) do
    Enum.map_join(policies, "\n", fn policy ->
      case policy.condition do
        empty when empty in [nil, []] ->
          describe_checks(policy.policies)

        conditions ->
          "When:\n" <>
            indent(describe_conditions(conditions)) <>
            "\nThen:\n" <> indent(describe_checks(policy.policies))
      end
    end)
  end

  defp describe_checks(checks) do
    checks
    |> Enum.map_join("\n", fn
      %{type: type, check_module: check_module, check_opts: check_opts} ->
        "#{type}: #{check_module.describe(check_opts)}"
    end)
    |> Kernel.<>("\n")
  end

  defp describe_conditions(conditions) do
    Enum.map_join(conditions, " and ", fn
      {check_module, check_opts} ->
        check_module.describe(check_opts)
    end)
  end

  defp indent(string) do
    string
    |> String.split("\n")
    |> Enum.map_join("\n", fn line ->
      "  " <> line
    end)
  end

  def policies(resource) do
    resource
    |> Extension.get_entities([:policies])
    |> set_access_type(default_access_type(resource))
  end

  def default_access_type(resource) do
    Extension.get_opt(resource, [:policies], :default_access_type, :strict, false)
  end

  # This should be done at compile time
  defp set_access_type(policies, default) when is_list(policies) do
    Enum.map(policies, &set_access_type(&1, default))
  end

  defp set_access_type(
         %AshPolicyAuthorizer.Policy{
           policies: policies,
           condition: conditions,
           checks: checks,
           access_type: access_type
         } = policy,
         default
       ) do
    %{
      policy
      | policies: set_access_type(policies, default),
        condition: set_access_type(conditions, default),
        checks: set_access_type(checks, default),
        access_type: access_type || default
    }
  end

  defp set_access_type(%AshPolicyAuthorizer.Policy.Check{check_opts: check_opts} = check, default) do
    %{check | check_opts: Keyword.update(check_opts, :access_type, default, &(&1 || default))}
  end

  defp set_access_type(other, _), do: other
end
