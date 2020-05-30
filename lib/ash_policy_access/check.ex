defmodule AshPolicyAccess.Check do
  @moduledoc """
  A behaviour for declaring checks, which can be used to easily construct
  authorization rules.
  """

  @type options :: Keyword.t()
  @type authorizer :: AshPolicyAccess.Authorizer.t()

  @callback strict_check(Ash.actor(), authorizer(), options) :: boolean | :unknown
  @callback auto_filter(Ash.actor(), authorizer(), options()) :: Keyword.t()
  @callback check(Ash.actor(), list(Ash.record()), map, options) ::
              {:ok, list(Ash.record()) | boolean} | {:error, Ash.error()}
  @callback describe(options()) :: String.t()
  @callback type() :: :atom

  @optional_callbacks check: 4, auto_filter: 3

  def defines_check?(module) do
    :erlang.function_exported(module, :check, 4)
  end

  def defines_auto_filter?(module) do
    :erlang.function_exported(module, :auto_filter, 3)
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour AshPolicyAccess.Check

      def type(), do: :manual
    end
  end

  defmacro import_default_checks(opts) do
    quote do
      import AshPolicyAccess.Check.Static, only: [always: 0, never: 0]
      import AshPolicyAccess.Check.RelatedToUserVia, only: [related_to_user_via: 1]
      import AshPolicyAccess.Check.SettingAttribute, only: [setting_attribute: 2]

      import AshPolicyAccess.Check.UserAttributeMatchesRecord,
        only: [user_attribute_matches_record: 2]

      import AshPolicyAccess.Check.UserAttribute, only: [user_attribute: 2]

      if unquote(opts[:attributes]) do
        import AshPolicyAccess.Check.SettingAttribute,
          only: [setting_attribute: 2, setting_attribute: 1]
      else
        import AshPolicyAccess.Check.AttributeEquals, only: [attribute_equals: 2]
      end
    end
  end

  defmacro unimport_checks() do
    quote do
      import AshPolicyAccess.Check.Static, only: []
      import AshPolicyAccess.Check.RelatedToUserVia, only: []
      import AshPolicyAccess.Check.SettingAttribute, only: []
      import AshPolicyAccess.Check.UserAttributeMatchesRecord, only: []
      import AshPolicyAccess.Check.UserAttribute, only: []
      import AshPolicyAccess.Check.SettingAttribute, only: []
    end
  end
end
