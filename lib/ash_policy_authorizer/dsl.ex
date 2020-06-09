defmodule AshPolicyAuthorizer.Dsl do
  @moduledoc "The dsl for ash policy authorizer"
  defmacro policies(access_type \\ :strict, do: body) do
    quote do
      Module.register_attribute(__MODULE__, :ash_policies, accumulate: true)
      @ash_policy_authorizer_type unquote(access_type)

      AshPolicyAuthorizer.Dsl.validate_access_type(@ash_policy_authorizer_type)

      import AshPolicyAuthorizer.Check.BuiltInChecks

      import AshPolicyAuthorizer.Dsl,
        only: [
          policy: 3
        ]

      unquote(body)

      import AshPolicyAuthorizer.Dsl, only: [policies: 1]
      import AshPolicyAuthorizer.Check.BuiltInChecks, only: []
    end
  end

  defmacro authorize_if(check) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAuthorizer.Policy.Check.new(
                      :authorize_if,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro authorize_unless(check) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAuthorizer.Policy.Check.new(
                      :authorize_unless,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro forbid_if(check) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAuthorizer.Policy.Check.new(
                      :forbid_if,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro forbid_unless(check) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAuthorizer.Policy.Check.new(
                      :forbid_unless,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro policy(condition, name, do: body) do
    quote do
      import AshPolicyAuthorizer.Dsl,
        only: [
          authorize_if: 1,
          forbid_if: 1,
          authorize_unless: 1,
          forbid_unless: 1
        ]

      case unquote(condition) do
        nil ->
          :ok

        {module, opts} ->
          if module.type != :simple do
            raise "Only simple checks can be used as policy conditions"
          end
      end

      existing_policies = @ash_policies

      Module.delete_attribute(__MODULE__, :ash_policies)
      Module.register_attribute(__MODULE__, :ash_policies, accumulate: true)
      unquote(body)

      policy = AshPolicyAuthorizer.Policy.new(unquote(condition), @ash_policies, unquote(name))

      Module.delete_attribute(__MODULE__, :ash_policies)
      Module.register_attribute(__MODULE__, :ash_policies, accumulate: true)
      Module.put_attribute(__MODULE__, :ash_policies, policy)

      existing_policies
      |> Enum.reverse()
      |> Enum.each(&Module.put_attribute(__MODULE__, :ash_policies, &1))
    end
  end

  def validate_access_type(type) when type in [:strict, :filter, :runtime] do
    :ok
  end

  def validate_access_type(type) do
    raise "#{type} is not a valid access type"
  end
end
