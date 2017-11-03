defmodule Absinthe.Relay.Node.IDTranslator do
    
    @callback to_global_id(type_name :: binary, source_id :: binary | integer, schema :: any) :: {:ok, binary} | {:error, binary}
    
    @callback from_global_id(global_id :: binary, schema :: any) :: {:ok, binary, binary} | {:error, binary}

end