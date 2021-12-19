defmodule AshPolicyAuthorizer.Test.Simple.CarUser do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  actions do
    create(:create)
    read(:read)
    update(:update)
    destroy(:destroy)
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to(:user, AshPolicyAuthorizer.Test.Simple.User)
    belongs_to(:car, AshPolicyAuthorizer.Test.Simple.Car)
  end
end
