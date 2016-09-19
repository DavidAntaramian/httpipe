defmodule HTTPipe.Adapters.Unimplemented do
  @moduledoc """
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
