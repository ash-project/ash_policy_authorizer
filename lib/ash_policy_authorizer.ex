defmodule AshPolicyAuthorizer do
  @moduledoc """
  Documentation forthcoming.
  """
  @type request :: Ash.Engine.Request.t()
  @type side_load :: {:side_load, Keyword.t()}
  @type prepare_instruction :: side_load

  alias Ash.Dsl.Extension

  def policies(resource) do
    Extension.get_entities(resource, [:policies])
  end

  def access_type(resource) do
    Extension.get_opt(resource, [:policies], :access_type, :strict, false)
  end
end
