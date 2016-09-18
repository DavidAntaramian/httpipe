defmodule HTTPlaster.Conn do
  @moduledoc """
  An HTTP connection encapsulating the request and response.


  """

  import Kernel, except: [inspect: 1]

  alias HTTPlaster.{Adapter, Request, Response, InspectionHelpers}
  alias __MODULE__.{AlreadyExecutedError}
  require Logger

  @type status :: :unexecuted | :executed | :failed

  @type t :: %__MODULE__{
               status: status,
               error: exception | nil,
               request: Request.t,
               response: Response.t,
               options: options,
               adapter: atom,
               adapter_options: Keyword.t
             }

  @type options :: %{}

  @type exception :: Adapter.exception

  defstruct status: :unexecuted,
            error: nil,
            request: %Request{},
            response: %Response{},
            options: %{
              defer_body_processing: false
            },
            adapter: :default,
            adapter_options: []


  @doc """
  """
  @spec execute(t) :: {:ok, t} | {:error, t}

  def execute(%__MODULE__{status: :unexecuted, request: r, adapter: a} = conn) do
    defer_body = defer_body_processing?(conn)
    adapter = get_adapter(a)

    result =
      with {:ok, url} <- Request.prepare_url(r.url, r.params),
           {:ok, body} <- Request.prepare_body(r.body, defer_body),
        do: execute_prepared_conn(conn, adapter, url, body)

    handle_adapter_resp(conn, result)
  end

  def execute(%__MODULE__{status: :executed}) do
    error = AlreadyExecutedError.exception(nil)
    {:error, error}
  end

  @spec execute_prepared_conn(t, module, Request.url, Request.body)
          :: Adapter.success | Adapter.failure
  defp execute_prepared_conn(%__MODULE__{request: r, adapter_options: o}, adapter, url, body) do
    adapter.execute_request(r.method, url, body, r.headers, o)
  end

  @spec handle_adapter_resp(t, Adapter.success | Adapter.failure) :: {:ok, t} | {:error, t}
  defp handle_adapter_resp(conn, {:ok, {status_code, headers, body}}) do
    r = %Response{status_code: status_code, headers: headers, body: body}

    conn = %{conn | status: :executed, response: r}

    {:ok, conn}
  end

  defp handle_adapter_resp(conn, {:error, reason}) do
    conn = %{conn | status: :failed, error: reason}
    {:error, conn}
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
      {:error, %__MODULE__{status: :failed, error: exception}} ->
        raise exception
    end
  end

  @spec put_adapter_options(t, Keyword.t) :: t
  def put_adapter_options(%__MODULE__{} = conn, options) do
    %__MODULE__{conn | adapter_options: options}
  end

  @spec put_req_method(t, Request.http_method) :: t
  def put_req_method(%__MODULE__{request: request} = conn, method) do
    new_request = Request.put_method(request, method)
    %__MODULE__{conn | request: new_request}
  end

  @spec put_req_url(t, String.t) :: t
  def put_req_url(%__MODULE__{request: request} = conn, url) do
    new_request = Request.put_url(request, url)
    %__MODULE__{conn | request: new_request}
  end

  @spec put_req_body(t, Request.body) :: t
  def put_req_body(%__MODULE__{request: request} = conn, body) do
    new_request = Request.put_body(request, body)
    %__MODULE__{conn | request: new_request}
  end

  @spec put_req_header(t, String.t, String.t, Request.duplicate_options) :: t
  def put_req_header(%__MODULE__{request: request} = conn, header_name, header_value, duplication_option \\ :duplicates_ok) do
    new_request = Request.put_header(request, header_name, header_value, duplication_option)
    %__MODULE__{conn | request: new_request}
  end

  @spec clear_req_headers(t) :: t
  def clear_req_headers(%__MODULE__{request: request} = conn) do
    new_request = Request.clear_headers(request)
    %__MODULE__{conn | request: new_request}
  end

  @spec merge_req_headers(t, Request.headers) :: t
  def merge_req_headers(%__MODULE__{request: request} = conn, headers) do
    new_request = Request.merge_headers(request, headers)
    %__MODULE__{conn | request: new_request}
  end

  @spec put_req_authentication_basic(t, String.t, String.t) :: t
  def put_req_authentication_basic(%__MODULE__{request: request} = conn, username, password) do
    new_request = Request.put_authentication_basic(request, username, password)
    %__MODULE__{conn | request: new_request}
  end

  @spec put_req_param(t, String.t, String.t, Request.duplicate_options) :: t
  def put_req_param(%__MODULE__{request: request} = conn, param_name, value, duplication_option \\ :replace_existing) do
    new_request = Request.put_param(request, param_name, value, duplication_option)
    %__MODULE__{conn | request: new_request}
  end

  @spec get_adapter(:default | module) :: module
  defp get_adapter(:default) do
    Application.get_env(:httplaster, :adapter, HTTPlaster.Adapters.Unimplemented)
  end

  defp get_adapter(adapter), do: adapter

  @spec put_adapter(t, module) :: t
  def put_adapter(%__MODULE__{} = conn, adapter) do
    %__MODULE__{conn | adapter: adapter}
  end

  @spec defer_body_processing(t, boolean) :: t
  def defer_body_processing(%__MODULE__{options: options} = conn, defer? \\ true) do
    new_options = %{options | defer_body_processing: defer?}
    %__MODULE__{conn | options: new_options}
  end

  @spec defer_body_processing?(t) :: boolean
  defp defer_body_processing?(conn) do
    local_preference = conn.options.defer_body_processing
    general_preference = Application.get_env(:httplaster, :defer_body_processing, false)

    local_preference || general_preference
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

    InspectionHelpers.inspect_conn(conn, opts)
    |> Inspect.Algebra.format(:infinity)
    |> IO.puts()

    conn
  end
end
