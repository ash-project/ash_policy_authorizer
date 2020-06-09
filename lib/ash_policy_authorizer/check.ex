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

  defmacro import_default_checks(opts) do
    quote do
      import AshPolicyAuthorizer.Check.Static, only: [always: 0, never: 0]
      import AshPolicyAuthorizer.Check.RelatedToUserVia, only: [related_to_user_via: 1]
      import AshPolicyAuthorizer.Check.SettingAttribute, only: [setting_attribute: 2]

      import AshPolicyAuthorizer.Check.UserAttributeMatchesRecord,
        only: [user_attribute_matches_record: 2]

      import AshPolicyAuthorizer.Check.UserAttribute, only: [user_attribute: 2]

      if unquote(opts[:attributes]) do
        import AshPolicyAuthorizer.Check.SettingAttribute,
          only: [setting_attribute: 2, setting_attribute: 1]
      else
        import AshPolicyAuthorizer.Check.AttributeEquals, only: [attribute_equals: 2]
      end
    end
  end

  defmacro unimport_checks do
    quote do
      import AshPolicyAuthorizer.Check.Static, only: []
      import AshPolicyAuthorizer.Check.RelatedToUserVia, only: []
      import AshPolicyAuthorizer.Check.SettingAttribute, only: []
      import AshPolicyAuthorizer.Check.UserAttributeMatchesRecord, only: []
      import AshPolicyAuthorizer.Check.UserAttribute, only: []
      import AshPolicyAuthorizer.Check.SettingAttribute, only: []
    end
  end
end
