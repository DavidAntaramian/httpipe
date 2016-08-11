defmodule HTTPlaster.Conn do
  @moduledoc """
  An HTTP connection encapsulating the request and response.


  """

  alias HTTPlaster.{Request, Response}
  require Logger

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
  def execute(%__MODULE__{request: r, adapter: a, adapter_options: o}) do
    url = prepare_url(r.url, r.params)
    adapter = get_adapter(a)
    Logger.debug("Adapter set to #{inspect adapter}")
    Logger.debug("Preparing #{inspect r.method} request to #{url}")
    adapter.execute_request(r.method, url, r.body, r.headers, o)
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

  defp get_adapter(:default) do
    Application.get_env(:httplaster, :adapter, HTTPlaster.Adapters.Unimplemented)
  end

  defp get_adapter(adapter), do: adapter

  @spec prepare_url(Request.url, Request.params) :: String.t
  def prepare_url(base_url, params) do
    p = Enum.flat_map(params, fn 
          {key, values} when is_list(values) -> Enum.map(values, &({key, &1}))
          val -> [val]
        end)
        |> URI.encode_query()

    "#{base_url}?#{p}"
  end
end
