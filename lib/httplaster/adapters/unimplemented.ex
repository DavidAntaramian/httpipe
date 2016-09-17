defmodule HTTPlaster.Adapters.Unimplemented do
  @moduledoc """
  """

  @behaviour HTTPlaster.Adapter

  alias HTTPlaster.{Request, Adapter}
  alias HTTPlaster.Adapters.UnimplementedException

  @spec execute_request(Request.http_method, Request.url, Request.body, Request.headers, Adapter.options) ::
    Adapter.success | Adapter.failure
  def execute_request(_, _, _, _, _) do
    exception = UnimplementedException.exception(nil)
    {:error, exception}
  end
end
