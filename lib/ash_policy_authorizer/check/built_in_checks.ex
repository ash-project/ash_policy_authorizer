defmodule AshPolicyAuthorizer.Check.BuiltInChecks do
  @moduledoc "The global authorization checks built into ash"

  def always do
    {AshPolicyAuthorizer.Check.Static, [result: true]}
  end

  def never do
    {AshPolicyAuthorizer.Check.Static, [result: false]}
  end

  def action_type(action_type) do
    {AshPolicyAuthorizer.Check.ActionType, [type: action_type]}
  end

  def action(action) do
    {AshPolicyAuthorizer.Check.Action, [action: action]}
  end

  def actor_attribute_matches_record(actor_field, record_field) do
    {AshPolicyAuthorizer.Check.ActorAttributeMatchesRecord,
     actor_field: actor_field, record_field: record_field}
  end
end
