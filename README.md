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

## Usage

### Node Interface

Relay
[requires an interface](https://facebook.github.io/relay/docs/graphql-object-identification.html),
`"Node"`, be defined in your schema to provide a simple way to fetch
objects using a global ID scheme.

Using `Absinthe.Relay`, this is how you can add node interface to your
schema, providing a type resolver that, given a resolved object,
returns the type identifier for the object type (this is used to generate
global IDs):

```elixir
node interface do
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

### Node Field

The node field provides a unified interface to query for an object in the
system using a global ID. The node field should be defined within your schema
`query` and should provide a resolver that, given a map containing the object
type identifier and internal, non-global ID (the incoming global ID will be
parsed into these values for you automatically) can resolve the correct value.

```elixir
query do

  node field do
    resolve fn
      %{type: :person, id: id}, _ ->
        {:ok, Map.get(@people, id)}
      %{type: :business, id: id}, _ ->
        {:ok, Map.get(@businesses, id)}
    end
  end

end
```

Here's how you easly create object types that can be looked up using this
field:

### Node Objects

To play nicely with the `:node` interface and field, explained above, any
object types need to implement the `:node` interface and generate a global
ID as the value of its `:id` field. Using the `node` macro, you can easily do
this while retaining the usual object type definition style.

```
node object :person do
  field :name, :string
  field :age, :string
end
```

This will create an object type, `:person`, as you might expect. An `:id`
field is created for you automatically, and this field generates a global ID;
a Base64 string that's built using the object type name and the raw, internal
identifier. All of this is handled for you automatically by prefixing your
object type definition with `"node "`.

The raw, internal value is retrieved using `default_id_fetcher/2` which just
pattern matches an `:id` field from the resolved object. If you need to
extract/build an internal ID via another method, just provide a function as
an `:id_fetcher` option.

For instance, assuming your raw internal IDs were stored as `:_id`, you could
configure your object like this:

```
node object :thing, id_fetcher: &my_custom_id_fetcher/2 do
  field :name, :string
end
```

### Connection

Relay uses
[Connection](http://facebook.github.io/relay/docs/graphql-connections.html)
(and other related) types to provide a standardized way of slicing and
paginating a one-to-many relationship.

Support in this package is designed to match the [Relay Cursor Connection Specification](http://facebook.github.io/relay/graphql/connections.htm).

TODO

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
