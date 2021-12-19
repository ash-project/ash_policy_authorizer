defmodule AshPolicyAuthorizer.Test.SimpleTest do
  @doc false
  use ExUnit.Case
  doctest AshPolicyAuthorizer

  alias AshPolicyAuthorizer.Test.Simple.{Api, Trip, Post, User}

  setup do
    [
      user: Api.create!(Ash.Changeset.new(User))
    ]
  end

  test "filter checks work on create/update/destroy actions", %{user: user} do
    user2 = Api.create!(Ash.Changeset.new(User))

    assert_raise Ash.Error.Forbidden, fn ->
      Api.update!(Ash.Changeset.new(user), actor: user2)
    end
  end

  test "filter checks work with related data", %{user: user} do
    assert Api.read!(Post, actor: user) == []
  end

  test "filter checks work via deeply related data", %{user: user} do
    assert Api.read!(Trip, actor: user) == []
  end
end
