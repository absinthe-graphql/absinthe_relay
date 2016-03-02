# Absinthe.Relay

Support for the [Relay framework](https://facebook.github.io/relay/)
from Elixir, using the [Absinthe](https://github.com/absinthe-graphql/absinthe)
package.

**IN INITIAL BUILD-OUT; NOT YET READY FOR USE**

## Installation

Install from [Hex.pm](https://hex.pm/packages/absinthe_relay):

```elixir
def deps do
  [{:absinthe_relay, "~> 0.0.1"}]
end
```

Add it to your `applications` configuration in `mix.exs`, too:

```elixir
def application do
  [applications: [:absinthe_relay]]
end
```

Note: Absinthe requires Elixir 1.2 or higher.

## Upgrading

See [CHANGELOG](./CHANGELOG.md) for upgrade steps between versions.

## Documentation

See "Usage," below, for basic usage information.

- For the tutorial, guides, and general information about Absinthe-related
  projects, see [http://absinthe-graphql.org](http://absinthe-graphql.org).
- Links to the API documentation are available in the [project list](http://absinthe-graphql.org/projects).

### Roadmap

See the Roadmap on [absinthe-graphql.org](http://absinthe-graphql.org/roadmap).

## Related Projects

See the Project List on [absinthe-graphql.org](http://absinthe-graphql.org/projects).

## Roadmap & Contributions

For a list of specific planned features and version targets, see the
[milestone list](https://github.com/CargoSense/absinthe_relay/milestones).

We welcome issues and pull requests; please see [CONTRIBUTING](./CONTRIBUTING.md).

## Usage

### Node Interface

Relay [requires an interface](https://facebook.github.io/relay/docs/graphql-object-identification.html), `node`, be defined in your schema to provide a simple way to fetch objects using a global ID scheme.

To enable the `node` interface in your schema, use `Absinthe.Relay.Schema`
_instead of_ `Absinthe.Schema`:

```elixir
use Absinthe.Relay.Schema
```

This will give you access to three new macros:

- `node_interface` - To define the node interface
- `node_field` - To define the field used to lookup a node by a global ID
- `node_object` - To define objects that represent nodes

First, add the node interface to your schema, providing a a type resolver that,
given a resolved object, returns the type identifier for the object (this is
used to generate global IDs):

```elixir
node_interface do
  resolve_type fn
     %{age: _}, _ ->
       :person
     %{employee_count: _}, _ ->
       :business
     _, _ ->
       nil
  end
end
```

Now, add the `node` field to your schema, providing a `resolve` function used to
lookup a node, given a type identifier and an ID:

```elixir
query do

  node_field do
    resolve fn
      %{type: :person, id: id}, _ ->
        {:ok, Map.get(@people, id)}
      %{type: :business, id: id}, _ ->
        {:ok, Map.get(@businesses, id)}
    end
  end

end
```

Now, for your node types, use the `node_object` macro. This will automatically handle:

* Adding `:node` to the object's interfaces list
* Adding the required `:id` field using the global ID scheme

Here's an example:

```elixir
node_object :person do
  field :name, :string
  field :age, :integer
end
```

## License

BSD License

Copyright (c) CargoSense, Inc.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

 * Neither the name Facebook nor the names of its contributors may be used to
   endorse or promote products derived from this software without specific
   prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
