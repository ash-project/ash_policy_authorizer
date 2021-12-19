defmodule AshPolicyAuthorizer.Test.Api do
  @moduledoc false
  use Ash.Api

  resources do
    registry(AshPolicyAuthorizer.Test.Registry)
  end
end
