defmodule HTTPlaster.Conn do
  @moduledoc """
  An HTTP connection encapsulating the request and response.


  """

  import Kernel, except: [inspect: 1]

  alias HTTPlaster.{Adapter, Request, Response}
  require Logger

  @type status :: :unexecuted | :executed

  @type t :: %__MODULE__{
               status: status,
               request: Request.t,
               response: Response.t,
               adapter: atom,
               adapter_options: Keyword.t
             }

  @type exception :: Adapter.exception

  defstruct status: :unexecuted,
            request: %Request{},
            response: %Response{},
            adapter: :default,
            adapter_options: []


  @doc """
  """
  @spec execute(t) :: {:ok, t} | {:error, exception}

  def execute(%__MODULE__{status: :executed}) do
    {:error, :already_executed}
  end

  def execute(%__MODULE__{request: r, adapter: a, adapter_options: o} = conn) do
    url = Request.prepare_url(r.url, r.params)
    defer_body = defer_body_processing?(conn)
    body = Request.prepare_body(r.body, defer_body)
    adapter = get_adapter(a)
    Logger.debug("Adapter set to #{inspect adapter}")
    Logger.debug("Preparing #{inspect r.method} request to #{url}")
    case adapter.execute_request(r.method, url, body, r.headers, o) do
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

  This will not raise an exception if the HTTP status code is outside the
  successfull range, though. Status code handling is left to the consumer.
  """
  @spec execute!(t) :: t | no_return
  def execute!(conn) do
    execute(conn)
    |> case do
      {:ok, r} -> r
      {:error, exception} ->
        raise exception
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

  @spec put_req_body(t, Request.body) :: t
  def put_req_body(%__MODULE__{request: request} = conn, body) do
    %__MODULE__{ conn | request: Request.put_body(request, body)}
  end

  @spec put_req_header(t, String.t, String.t, Request.duplicate_options) :: t
  def put_req_header(%__MODULE__{request: request} = conn, header_name, header_value, duplication_option \\ :duplicates_ok) do
    %__MODULE__{ conn | request: Request.put_header(request, header_name, header_value, duplication_option) }
  end

  @spec put_req_headers(t, Request.headers) :: t
  def put_req_headers(%__MODULE__{request: request} = conn, headers) do
    %__MODULE__{ conn | request: Request.put_headers(request, headers)}
  end

  @spec put_req_authentication_basic(t, String.t, String.t) :: t
  def put_req_authentication_basic(%__MODULE__{request: request} = conn, username, password) do
    %__MODULE__{ conn | request: Request.put_authentication_basic(request, username, password)}
  end

  @spec put_req_param(t, String.t, String.t, Request.duplicate_options) :: t
  def put_req_param(%__MODULE__{request: request} = conn, param_name, value, duplication_option \\ :replace_existing) do
    %__MODULE__{ conn | request: Request.put_param(request, param_name, value, duplication_option)}
  end

  @spec get_adapter(:default | atom) :: module
  defp get_adapter(:default) do
    Application.get_env(:httplaster, :adapter, HTTPlaster.Adapters.Unimplemented)
  end

  defp get_adapter(adapter), do: adapter

  @spec defer_body_processing?(t) :: boolean
  def defer_body_processing?(conn) do
    adapter_preference = Keyword.get(conn.adapter_options, :defer_body_processing, false)
    general_preference = Application.get_env(:httplaster, :defer_body_processing, false)

    adapter_preference || general_preference
  end

  @spec new() :: t
  def new() do
    %__MODULE__{}
  end

  @doc """
  Inspects the structure of the Conn struct passed in the same
  way `IO.inspect/1` might, returning the Conn struct so that it
  can be used easily with pipes.

  Typically, `Kernel.inspect/1`, `IO.inspect/1`, and their companions are
  implemented using the `Inspect` protocol. However, the presentation used
  here can get extremely intrusive when experimenting using IEx, so it's
  relegated to this function. Corresponding functions can be found at
  `HTTPlaster.Request.inspect/2` and `HTTPlaster.Response.inspect/2`.

  See `HTTPlaster.InspectionHelpers` for more information
  """
  @spec inspect(t, Keyword.t) :: t
  def inspect(conn, opts \\ []) do
    opts = struct(Inspect.Opts, opts)

    HTTPlaster.InspectionHelpers.inspect_conn(conn, opts)
    |> Inspect.Algebra.format(:infinity)
    |> IO.puts()

    conn
  end
end
