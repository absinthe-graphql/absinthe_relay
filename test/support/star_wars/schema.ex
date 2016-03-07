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

defmodule StarWars.Schema do

  alias StarWars.Database
  use Absinthe.Relay.Schema

  alias Absinthe.Relay.Connection

  query do

    field :rebels, :faction do
      resolve fn
        _, _ ->
          Database.get_rebels()
      end
    end

    field :empire, :faction do
      resolve fn
        _, _ ->
          Database.get_empire()
      end
    end

    node field do
      resolve fn
        %{type: node_type, id: id}, _ ->
          Database.get(node_type, id)
        _, _ ->
          {:ok, nil}
      end
    end

  end

  @desc "A ship in the Star Wars saga"
  node object :ship do

    @desc "The name of the ship."
    field :name, :string

  end

  node interface do
    resolve_type fn
      %{ships: _}, _ ->
        :faction
      _, _ ->
        :ship
    end
  end

  @desc "A faction in the Star Wars saga"
  node object :faction do

    @desc "The name of the faction"
    field :name, :string

    @desc "The ships used by the faction."
    connection field :ships, node_type: :ship do
      resolve fn
        resolve_args, %{source: faction} ->
          connection = Connection.from_list(
          Enum.map(faction.ships, fn
            id ->
              with {:ok, value} <- Database.get(:ship, id) do
              value
            end
          end),
          resolve_args
        )
        {:ok, connection}
      end
    end

  end

  # Default
  connection node_type: :ship

end
