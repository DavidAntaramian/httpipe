defmodule HTTPlaster.Conn do
  @moduledoc """
  An HTTP connection encapsulating the request and response.


  """

  @default_adapter Application.get_env(:httplaster, :adapter, HTTPlaster.Adapters.Unimplemented)

  alias HTTPlaster.{Request, Response}

  @type status :: :unexecuted | :executed

  @type t :: %__MODULE__{
               status: status,
               request: Request.t,
               response: Response.t,
               adapter: atom,
               adapter_options: Keyword.t
             }

  defstruct status: :unexecuted,
            request: %Request{},
            response: %Response{},
            adapter: :default,
            adapter_options: []


  @doc """
  """
  @spec execute(t) :: t
  def execute(%__MODULE__{request: r, adapter: :default, adapter_options: o}) do
    @default_adapter.execute_request(r.method, r.url, r.body, r.headers, o)
  end

  # If the adapter has changed from the default, use :erlang.apply instead
  # to fulfill the request
  def execute(%__MODULE__{request: r, adapter: m, adapter_options: o}) do
    :erlang.apply(m, :execute_request, [r.method, r.url, r.body, r.headers, o])
  end

  @doc """
  Identical to `execute/1` except that it will raise an exception if the
  request could not be completed successfully.
  """
  @spec execute(t) :: t | no_return
  def execute!(conn) do
    execute(conn)
    |> case do
      {:ok, r} -> {:ok, r}
      {:error, {exception, meta}} ->
        raise exception, meta
    end
  end
end
