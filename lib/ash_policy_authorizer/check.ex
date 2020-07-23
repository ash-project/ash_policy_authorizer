defmodule AshPolicyAuthorizer.Check do
  @moduledoc """
  A behaviour for declaring checks, which can be used to easily construct
  authorization rules.
  """

  @type options :: Keyword.t()
  @type authorizer :: AshPolicyAuthorizer.Authorizer.t()
  @type check_type :: :simple | :filter | :manual

  @callback strict_check(Ash.actor(), authorizer(), options) :: {:ok, boolean | :unknown}
  @callback auto_filter(Ash.actor(), authorizer(), options()) :: Keyword.t()
  @callback check(Ash.actor(), list(Ash.record()), map, options) ::
              {:ok, list(Ash.record()) | boolean} | {:error, Ash.error()}
  @callback describe(options()) :: String.t()
  @callback type() :: check_type()
  @optional_callbacks check: 4, auto_filter: 3

  def defines_check?(module) do
    :erlang.function_exported(module, :check, 4)
  end

  def defines_auto_filter?(module) do
    :erlang.function_exported(module, :auto_filter, 3)
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour AshPolicyAuthorizer.Check

      def type, do: :manual
    end
  end
end
