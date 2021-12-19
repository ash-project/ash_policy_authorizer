defmodule AshPolicyAuthorizer.Test.Simple.Trip do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [
      AshPolicyAuthorizer.Authorizer
    ]

  ets do
    private?(true)
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(car.users.id == ^actor(:id))
    end
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
    belongs_to(:car, AshPolicyAuthorizer.Test.Simple.Car)
  end
end
