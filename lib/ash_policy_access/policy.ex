defmodule AshPolicyAccess.Policy do
  defstruct [:wheres, :type, :check_module, :check_opts, access_type: :strict]

  def new(wheres, type, access_type, check_module, check_opts) do
    %__MODULE__{
      wheres: wheres,
      type: type,
      check_module: check_module,
      check_opts: check_opts,
      access_type: access_type
    }
  end
end
