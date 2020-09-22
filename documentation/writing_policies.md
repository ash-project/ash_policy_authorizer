# Writing Policies

Policies determine what actions on a resource are permitted for a given actor.

You can specify an actor using the code api via the `actor` option, like so:

```elixir
MyApp.MyApi.read(MyResource, actor: current_user)
```

## Important!

Before we jump into the guide, it is critical to understand that the policy code doesn't actually
_do_ anything in the classic sense. It simply builds up a set of policies that are stored for use later.
The checker that reads those policies and authorizes requests may run all, some of, or none of your checks,
depending on the details of the request being authorized.

## Guide

To see what checks are built-in, see `AshPolicyAuthorizer.Check.BuiltInChecks`

### The Simplest Policy

Lets start with the simplest policy set:

```elixir
policies do
  policy always() do
    authorize_if always()
  end
end
```

Here, we have a single policy. The first argument to `policy` is the "condition". If the condition is true,
then the policy appolies to the request. If a given policy applies, then one of the checks inside the policy must authorize that policy. _Every policy that applies_ to a given request must each be authorized for a request to be authorized.

Within this policy we have a single check, declared with `authorize_if`. Checks logically apply from top to bottom, based on their check type. In this case, we'd read the policy as "this policy always applies, and authorizes always".

There are four check types, all of which do what they sound like they do:

- `authorize_if` - if the check is true, the policy is authorized.
- `authorize_unless` - if the check is false, the policy is authorized.
- `forbid_if` - if the check is true, the policy is forbidden.
- `forbid_unless` - if the check is false, the policy is forbidden.

In each case, if the policy is not authorized or forbidden, the flow moves to the next check.

### A realistic policy

In this example, we use some of the provided built in checks.

```elixir
policies do
  # Anything you can use in a condition, you can use in a check, and vice-versa
  # This policy applies if the actor is a super_user
  # Addtionally, this policy is declared as a `bypass`. That means that this check is allowed to fail without
  # failing the whole request, and that if this check *passes*, the entire request passes.
  bypass actor_attribute_equals(:super_user, true) do
    authorize_if always()
  end

  # This will likely be a common occurrence. Specifically, policies that apply to all read actions
  policy action_type(:read) do
    # unless the actor is an active user, forbid their request
    forbid_unless actor_attribute_equals(:active, true)
    # if the record is marked as public, authorize the request
    authorize_if attribute(:public, true)
    # if the actor is related to the data via that data's `owner` relationship, authorize the request
    authorize_if relates_to_actor_via(:owner)
  end
end
```

### Custom checks

See `AshPolicyAuthorizer.Check` for more inforamtion on writing custom checks, which you will likely need at some point when the built in checks are insufficient

### More

More will need to be written, as questions arise.
