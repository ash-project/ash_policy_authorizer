defmodule AshPolicyAccess do
  @moduledoc """
  Authorization in Ash is done via declaring `rules` for actions,
  and in the case of stateful actions, via declaring `authoriation_steps` on attributes
  and relationships.


  # TODO: consider this coverage metric when building the test framework
  https://en.wikipedia.org/wiki/Modified_condition/decision_coverage
  """

  @callback ash_policies() :: [AshPolicyAccess.Policy.t()]
  @callback ash_policy_access_type() :: :strict | :filter | :runtime

  @type request :: Ash.Engine.Request.t()
  @type side_load :: {:side_load, Keyword.t()}
  @type prepare_instruction :: side_load

  defmacro __using__(_) do
    quote do
      import AshPolicyAccess.Dsl, only: [policies: 1, policies: 2]
      Module.register_attribute(__MODULE__, :ash_policies, accumulate: true)
      @extensions AshPolicyAccess
      @authorizers AshPolicyAccess.Authorizer
      @behaviour AshPolicyAccess
      require AshPolicyAccess
    end
  end

  def policies(resource) do
    resource.ash_policies()
  end

  def access_type(resource) do
    resource.ash_policy_access_type()
  end

  def before_compile_hook(_env) do
    quote do
      def ash_policies() do
        @ash_policies
      end

      def ash_policy_access_type() do
        @ash_policy_access_type
      end
    end
  end
end
