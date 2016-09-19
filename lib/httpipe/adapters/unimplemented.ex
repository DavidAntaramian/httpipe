defmodule HTTPipe.Adapters.Unimplemented do
  @moduledoc """
  Special adapter that does nothing but return an error.

  This adapter is the default adapter that ships with HTTPipe
  and is completely useless except to show the general structure
  of an adapter.
  """

  @behaviour HTTPipe.Adapter

  alias HTTPipe.{Request, Adapter}
  alias HTTPipe.Adapters.UnimplementedError

  @spec execute_request(Request.http_method, Request.url, Request.body, Request.headers, Adapter.options) ::
    Adapter.success | Adapter.failure
  def execute_request(_, _, _, _, _) do
    exception = UnimplementedError.exception(nil)
    {:error, exception}
  end
end
