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

  def execute(%__MODULE__{status: :executed}) do
    {:error, :already_executed}
  end

  def execute(%__MODULE__{request: r, adapter: a, adapter_options: o} = conn) do
    url = prepare_url(r.url, r.params)
    adapter = get_adapter(a)
    Logger.debug("Adapter set to #{inspect adapter}")
    Logger.debug("Preparing #{inspect r.method} request to #{url}")
    case adapter.execute_request(r.method, url, r.body, r.headers, o) do
      {:ok, {status_code, headers, body}} ->
        r = %Response{status_code: status_code, headers: headers, body: body}

        conn = %{conn | status: :executed, response: r}

        {:ok, conn}
      {:error, reason} ->
        {:error, reason}
    end
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

  @spec put_adapter_options(t, Keyword.t) :: t
  def put_adapter_options(%__MODULE__{} = conn, options) do
    %{conn | adapter_options: options}
  end

  @spec put_req_method(t, Request.http_method) :: t
  def put_req_method(%__MODULE__{request: request} = conn, method) do
    %__MODULE__{conn | request: Request.put_method(request, method)}
  end

  @spec put_req_url(t, String.t) :: t
  def put_req_url(%__MODULE__{request: request} = conn, url) do
    %__MODULE__{ conn | request: Request.put_url(request, url)}
  end

  @spec put_req_headers(t, Request.headers) :: t
  def put_req_headers(%__MODULE__{request: request} = conn, headers) do
    %__MODULE__{ conn | request: Request.put_headers(request, headers)}
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

    append_params(base_url, p)
  end

  defp append_params(url, ""), do: url
  defp append_params(url, params), do: "#{url}?#{params}"
end
