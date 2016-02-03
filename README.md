# Absinthe.Relay

Support for the [Relay framework](https://facebook.github.io/relay/)
from Elixir, using the [Absinthe](https://hex.pm/packages/absinthe)
package.

**IN INITIAL BUILD-OUT; NOT YET READY FOR USE**

## Specifications

http://facebook.github.io/relay/docs/graphql-relay-specification.html

## Usage

### Object Identification

Relay [requires an interface](https://facebook.github.io/relay/docs/graphql-object-identification.html), `node`, be defined in your schema to provide a simple way to fetch objects using a global ID scheme. This is designed to match the [Relay Global Object Identification Specification](http://facebook.github.io/relay/graphql/objectidentification.htm).

To enable the `node` interface in your schema, use `Absinthe.Relay.Schema`
_instead of_ `Absinthe.Schema`:

```elixir
use Absinthe.Relay.Schema
```

This will automatically add the `:node` interface type and mark your schema as
conforming to the `Absithe.Relay.Schema` behaviour.

Now, add the `node` field to your schema, providing a resolver function for
each planned node type:

```elixir
def query do
  %Type.Object{
    fields: fields(
      node: Absinthe.Relay.Node.field(fn
        %{type: :person, id: id}, _ ->
          {:ok, Map.get(@people, id)}
        %{type: :business, id: id}, _ ->
          {:ok, Map.get(@businesses, id)}
      end)
    )
  }
end
```

Next, add a `node_type_resolver/1` function that, given a resolved object,
returns the type identifier for the object (this is used to generate
global IDs):

```elixir
def node_type_resolver(%{ships: _}), do: :faction
def node_type_resolver(_), do: :ship
```

In your node types, you need to do two things:

* Add `:node` to your interfaces list
* Add the required `:id` field using the global ID scheme

Here's an example:

```elixir
@absinthe :type
def person do
  %Type.Object{
    fields: fields(
      id: Absinthe.Relay.Node.global_id_field(:person),
      name: [type: :string],
      age: [type: :integer]
    ),
    interfaces: [:node]
  }
end
```

Note that `global_id_field` is given the name of the prefix to use. It's
best to make this the same as the identifier for your type, as we did
here with `:person`.

### Connection

Relay uses [Connection](http://facebook.github.io/relay/docs/graphql-connections.html) (and other related) types to provide a
standardized way of slicing and paginating a one-to-many relationship.

Support in this package is designed to match the [Relay Cursor Connection Specification](http://facebook.github.io/relay/graphql/connections.htm).



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
