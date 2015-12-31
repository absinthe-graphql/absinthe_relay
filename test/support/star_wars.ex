# Derived from the "Star Wars" Relay example as of this commit:
# https://github.com/facebook/relay/commit/841b169a192394c3650d5264cf95a230f89acb66
#
# This file provided by Facebook is for non-commercial testing and evaluation
# purposes only.  Facebook reserves all rights not expressly granted.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#
# Using our shorthand to describe type systems,
# the type system for our example will be the following:
#
# interface Node {
#   id: ID!
# }
#
# type Faction : Node {
#   id: ID!
#   name: String
#   ships: ShipConnection
# }
#
# type Ship : Node {
#   id: ID!
#   name: String
# }
#
# type ShipConnection {
#   edges: [ShipEdge]
#   pageInfo: PageInfo!
# }
#
# type ShipEdge {
#   cursor: String!
#   node: Ship
# }
#
# type PageInfo {
#   hasNextPage: Boolean!
#   hasPreviousPage: Boolean!
#   startCursor: String
#   endCursor: String
# }
#
# type Query {
#   rebels: Faction
#   empire: Faction
#   node(id: ID!): Node
# }
#
# input IntroduceShipInput {
#   clientMutationId: string!
#   shipName: string!
#   factionId: ID!
# }
#
# input IntroduceShipPayload {
#   clientMutationId: string!
#   ship: Ship
#   faction: Faction
# }
#
# type Mutation {
#   introduceShip(input IntroduceShipInput!): IntroduceShipPayload
# }

defmodule StarWars do

  alias StarWars.Database
  alias Absinthe.Relay.Node

  use Absinthe.Schema, type_modules: [Node]
  alias Absinthe.Type

  def query do
    %Type.Object{
      fields: fields(
        factions: [
          type: list_of(:faction),
          args: args(
            names: [type: list_of(:string)]
          ),
          resolve: fn
            %{names: names} ->
              Database.get_factions(names)
          end
        ],
        node: Absinthe.Relay.Node.field
      )
    }
  end

  defp node_field do
    Absinthe.Relay.node_field(fn
      %{id: raw_global_id}, execution ->
        case Absinthe.Relay.parse_global_id(raw_global_id) do
          {:ok, %{type: node_type, id: id}} ->
            Database.get(node_type, id)
          {:ok, _} ->
            {:ok, nil}
          {:error, _} = err ->
            err
        end
    end)
  end

  @absinthe :type
  def ship do
    %Type.Object{
      name: "Ship",
      description: "A ship in the Star Wars saga",
      fields: fields(
        id: Absinthe.Relay.Node.global_id_field(:ship),
        name: [type: :string, description: "The name of the ship."]
      ),
      interfaces: [:node]
    }
  end

  @absinthe :type
  def node do
    Absinthe.Relay.Node.interface(fn
      %{ships: _} -> :faction
      _ -> :ship
    end)
  end

  @absinthe :faction
  def faction do
    %Type.Object{
      name: "Faction",
      description: "A faction in the Star Wars saga",
      fields: fields(
        id: Node.global_id_field(:faction),
        name: [type: :string, description: "The name of the faction"],
        ships: [
          type: :ship_connection,
          description: "The ships used by the faction."
        ]
      )
    }
  end

end
