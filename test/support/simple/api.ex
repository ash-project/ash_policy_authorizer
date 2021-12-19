defmodule AshPolicyAuthorizer.Test.Simple.Api do
  @moduledoc false
  use Ash.Api

  resources do
    registry(AshPolicyAuthorizer.Test.Simple.Registry)
  end
end
