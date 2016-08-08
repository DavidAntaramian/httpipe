defmodule HTTPlaster.Adapters.Unimplemented do
  @moduledoc """
  """

  @behaviour HTTPlaster.Adapter

  alias HTTPlaster.{Request, Adapter}

  @spec execute_request(Request.http_method, String.t, Request.body, Request.headers, Adapter.options) ::
    Adapter.success | Adapter.failure
  def execute_request(_, _, _, _, _) do
    {:error, {HTTPlaster.Adapters.UnimplementedException, nil}}
  end
end
