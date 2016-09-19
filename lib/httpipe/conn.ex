defmodule HTTPipe.Conn do
  @moduledoc """
  An HTTP connection encapsulating the request and response, taking inspiration
  from the [Plug](https://hex.pm/packages/plug) package.

  This module provides a way to easily compose an HTTP request.
  """

  # inspect/1 and Kernel.inspect/1 conflict, so Kernel.inspect/1 is
  # not imported inside this module and should be called fully-qualified
  import Kernel, except: [inspect: 1]

  alias HTTPipe.{Adapter, Request, Response, InspectionHelpers}
  alias __MODULE__.{AlreadyExecutedError}

  @typedoc """
  Status of the connection

  The connection will always start off in the `:unexecuted` status.
  After the connection is executed using `execute/1` or `execute!/1`,
  it will have a status of either `:executed` or `:failed`.

  #### :unexecuted

  The connection has not been executed yet and is still being composed.
  It can be executed by calling `execute/1` or `execute!/1`.

  #### :executed

  The connection was executed, and the adapter was able to complete
  the request. This does not imply that the returned status code
  from the host was inside the "successful" range (200-299). It
  is the responsibility of the consumer to check the response's status
  code and take appropriate action.

  #### :failed

  The connection was executed, but something went wrong. The
  `:error` key will contain the error detailing why the connection
  failed.

  The connection may fail before even reaching the adapter if,
  for example, the URL to connect to is `nil` or the body
  cannot be encoded properly.
  """
  @type status :: :unexecuted | :executed | :failed

  @typedoc """
  Encapsulates an HTTP request/response cycle

  #### :status

  The status of the connection. See the `status` type.

  #### :error

  By default, this will be `nil`. If the connection encounters
  an error during execution, this will hold the error that caused
  the failure.

  #### :request

  The request to be execute (see `HTTPipe.Request`).

  #### :response

  By default this will be `nil` until the connection is
  executed without failure. Then it will contain the response
  from the host (see `HTTPipe.Response`).

  #### :options

  The options for the connection. See the `options`
  type.

  #### :adapter

  The adapter to be used for this connection. By default, this
  will be `:default`, meaning it will use the value stored
  in the Application environment for `:httpipe` under the
  key `:adapter`. This allows you to configure the default
  adapter globally.

  #### :adapter_options

  Options to be passed to the adapter. By default, this is
  an empty list `[]`. Each adapter takes different options,
  so you will need to see the documentation for the specific
  module to determine what values are appropriate here.
  """
  @type t :: %__MODULE__{
               status: status,
               error: exception | nil,
               request: Request.t,
               response: Response.t | nil,
               options: options,
               adapter: module,
               adapter_options: Keyword.t
             }

  @typedoc """
  Options for the connection

  #### :defer_body_processing

  When false (default), the request's body value will be encoded to a string
  value by HTTPipe.

  When true, the request's body value will be sent to the adapter
  as-is.

  See `defer_body_processing/2` for more information.
  """
  @type options :: %{
                     defer_body_processing: boolean
                   }

  @typedoc """
  An exception that causes the connection status to be marked `:failed`

  The exception must be a `Exception.t` compliant struct as `!`-style
  functions will attempt to raise the exception.
  """
  @type exception :: Exception.t | Adapter.exception

  defstruct status: :unexecuted,
            error: nil,
            request: %Request{},
            response: nil,
            options: %{
              defer_body_processing: false
            },
            adapter: :default,
            adapter_options: []


  @doc """
  Executes a connection

  Executing a connection is the process of actually sending the request to the designated
  host and receiving a response. A new `HTTPipe.Conn` struct will be returned with the
  response and a `:status` of `:executed`. If an error was encountered, the `:status` will
  instead be `:failed` and the error will be available under `:error`.

  Because the entire connection is encapsulated in a struct, you can compose the connection
  and pass it around in your application as-needed, choosing when to execute it.

  Execution of the connection will first put together the URL and the body to be used
  for the request. If the URL is `nil` or the body cannot be properly processed, this
  will result in an immediate error before the adapter is even reached. If body processing
  was deferred, the body will be kept as-is.

  Assuming the URL and body were prepared without issue, the chosen adapter for this
  connection is then sent the necessary pieces it needs to execute the request. At this
  time, further errors will only be encountered by the adapter.

  __Note__: A connection can only be executed _once_. Attempting to execute a connection
  again will change the `:status` to `:failed` with an error of the type
  `HTTPipe.Conn.AlreadyExecutedError`.

  ## Examples

  ~~~
  {:ok, conn} =
    Conn.new()
    |> Conn.put_req_url("https://httpbin.org/get")
    |> Conn.execute()

  conn.status # :executed
  conn.response.status_code # 200
  ~~~
  """
  @spec execute(t) :: {:ok, t} | {:error, t}
  def execute(%__MODULE__{status: :unexecuted, request: r, adapter: a} = conn) do
    defer_body = defer_body_processing?(conn)
    adapter = get_adapter(a)

    result =
      with {:ok, url} <- Request.prepare_url(r.url, r.params),
           {:ok, body} <- Request.prepare_body(r.body, defer_body),
        do: execute_prepared_conn(conn, adapter, url, body)

    handle_execution_resp(conn, result)
  end

  def execute(%__MODULE__{status: s} = conn) when s in [:executed, :failed] do
    error = AlreadyExecutedError.exception(nil)
    conn = %{conn | status: :failed, error: error}
    {:error, conn}
  end

  @spec execute_prepared_conn(t, module, Request.url, Request.body)
          :: Adapter.success | Adapter.failure
  defp execute_prepared_conn(%__MODULE__{request: r, adapter_options: o}, adapter, url, body) do
    adapter.execute_request(r.method, url, body, r.headers, o)
  end

  # Handles the result from the execution/1 function for the success
  # and failure cases. Failure may occur before the adapter is ever
  # reached, so this function handle that case as well
  @spec handle_execution_resp(t, Adapter.success | exception) :: {:ok, t} | {:error, t}
  # success case
  defp handle_execution_resp(conn, {:ok, {status_code, headers, body}}) do
    r = %Response{status_code: status_code, headers: headers, body: body}

    conn = %{conn | status: :executed, response: r}

    {:ok, conn}
  end

  # failure case
  defp handle_execution_resp(conn, {:error, reason}) do
    conn = %{conn | status: :failed, error: reason}
    {:error, conn}
  end

  @doc """
  Identical to `execute/1` except that it will raise an exception if the
  request could not be completed successfully.

  This will only raise an exception if the connection could not be
  made successfully. This occurs because the URL was `nil`, the body could
  not be processed properly, or the adapter encountered some other error.
  It is important to note that an HTTP status code outside the
  successfull range (200-299) will _not_ cause an error. Status code handling
  is left to the consumer.
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

  @doc """
  Sets the adapter options

  Adapter options are set as a keyword list containing different options
  for the connection. The options are passed to the adapter as-is. Each
  adapter has specific options available, so please see the documentation
  for the adapter you are using for more information.
  """
  @spec put_adapter_options(t, Keyword.t) :: t
  def put_adapter_options(%__MODULE__{} = conn, options) do
    %__MODULE__{conn | adapter_options: options}
  end

  @doc """
  Sets the request method

  See `HTTPipe.Request.put_method/2` and `HTTPipe.Request.http_method`
  for more information.
  """
  @spec put_req_method(t, Request.http_method) :: t
  def put_req_method(%__MODULE__{request: request} = conn, method) do
    new_request = Request.put_method(request, method)
    %__MODULE__{conn | request: new_request}
  end

  @doc ~S"""
  Sets the request URL

  The request URL is the end resource that should be accessed by the HTTP
  request including the scheme and request path. It should not include any query
  parameters. Instead you should consider using `put_req_param/4` for that. If
  this does not handle your use case, please file a bug report.

  ## Examples
  
  The following sets the URL to `https://google.com/`:

  ~~~
  conn =
    Conn.new()
    |> Conn.put_req_url("https://google.com/")
  ~~~

  Typically, you will be accessing more complex resources, though:

  ~~~
  base_url = "https://api.everyoneapi.com/v1"
  phone_number = "5555555678"
  account_sid = "abc123"
  auth_token = "321cba"

  conn =
    Conn.new()
    |> Conn.put_method(:get)
    |> Conn.put_req_url("#{base_url}/phone/+#{phonenumber}")
    |> Conn.put_req_param("account_sid", account_sid)
    |> Conn.put_req_param("auth_token", auth_token)
  ~~~

  will result in the following url:

  ~~~txt
  https://api.everyoneapi.com/v1/phone/+5555555678?account_sid=abc123&auth_token=321cba
  ~~~
  
  See `HTTPipe.Request.put_url/2` for more information.
  """
  @spec put_req_url(t, String.t) :: t
  def put_req_url(%__MODULE__{request: request} = conn, url) do
    new_request = Request.put_url(request, url)
    %__MODULE__{conn | request: new_request}
  end

  @doc """
  Sets the request body, overwriting any existing body

  ## Examples
  
  You can set any `String.t` value as the body:

  ~~~
  conn =
    Conn.new()
    |> Conn.add_req_body("Hello!")
  ~~~

  and this will be sent to the server as-is. If you set the body to `nil`
  (which is its default value), this will be encoded as a blank string: `""`.
  You can also use the special body forms like `{:form, data}`:

  ~~~
  conn =
    Conn.new()
    |> Conn.add_req_body({:form, [name: "HTTPipe", language: "Elixir"]})
  ~~~

  which will be encoded before sending to the server as the following:

  ~~~txt
  name=HTTPipe&language=Elixir
  ~~~

  Note that HTTPipe does not currently attempt to do any content type
  recognition. You are responsible for setting the `Content-Type` header
  appropriately based on the type of body you are sending.
  See `HTTPipe.Request.put_body/2` and `HTTPipe.Request.body` for more
  information. Also see `defer_body_processing/2`.
  """
  @spec put_req_body(t, Request.body) :: t
  def put_req_body(%__MODULE__{request: request} = conn, body) do
    new_request = Request.put_body(request, body)
    %__MODULE__{conn | request: new_request}
  end

  @doc """
  Sets the given request header, merging existing values by default

  ## Examples
  
  The following connection composition:

  ~~~
  conn =
    Conn.new()
    |> Conn.put_req_header("Accept-Encoding", "gzip")
    |> Conn.put_req_header("Accept-Encoding", "deflate")
    |> Conn.put_req_header("Content-Type", "application/json")
  ~~~

  will result in the following headers:

  ~~~txt
  accept-encoding: gzip, deflate
  content-type: application/json
  ~~~

  By default, if you have already set a header, setting it again with this function
  will append the new value to the old value using a comma to separate them. You
  can pass a `HTTPipe.Request.duplicate_options` atom as the final parameter
  to change this. See `HTTPipe.Request.put_header/4` and
  `HTTPipe.Request.headers` for more information.
  """
  @spec put_req_header(t, String.t, String.t, Request.duplicate_options) :: t
  def put_req_header(%__MODULE__{request: request} = conn, header_name, header_value, duplication_option \\ :duplicates_ok) do
    new_request = Request.put_header(request, header_name, header_value, duplication_option)
    %__MODULE__{conn | request: new_request}
  end

  @doc """
  Deletes the specified request header

  ## Examples
  
  The following connection composition:

  ~~~
  conn =
    Conn.new()
    |> Conn.put_req_header("Accept-Encoding", "gzip")
    |> Conn.put_req_header("Accept-Encoding", "deflate")
    |> Conn.put_req_header("Content-Type", "application/json")
    |> Conn.delete_req_header("Accept-Encoding")
  ~~~

  will result in the following headers:

  ~~~txt
  content-type: application/json
  ~~~
  """
  @spec delete_req_header(t, String.t) :: t
  def delete_req_header(%__MODULE__{request: request} = conn, header_name) do
    new_request = Request.delete_header(request, header_name)
    %__MODULE__{conn | request: new_request}
  end

  @doc """
  Clears the existing request headers

  ## Example

  ~~~
  conn =
    Conn.new()
    |> Conn.put_req_header("Accept", "application/xml")
    |> Conn.put_req_header("Content-Type", "application/json")
    |> Conn.put_req_header("Accept-Encoding", "gzip")
    |> Conn.clear_req_headers()
  ~~~

  will result in an empty set of request headers.

  Note that even if you clear the request headers, certain request headers
  will be set out of necessity when the connection is executed.

  See `HTTPipe.Request.clear_headers/1` for more information.
  """
  @spec clear_req_headers(t) :: t
  def clear_req_headers(%__MODULE__{request: request} = conn) do
    new_request = Request.clear_headers(request)
    %__MODULE__{conn | request: new_request}
  end

  @doc """
  Merges a map of headers into the existing request headers

  ## Example

  ~~~
  headers_to_merge = %{
    "accept" => "application/json",
    "accept-encoding" => "deflate",
    "connection" => "keep-alive"
  }

  conn =
    Conn.new()
    |> Conn.put_req_header("Accept", "application/xml")
    |> Conn.put_req_header("Content-Type", "application/json")
    |> Conn.put_req_header("Accept-Encoding", "gzip")
    |> Conn.merge_req_headers(headers_to_merge)
  ~~~

  will result in the following header list:

  ~~~txt
  accept-encoding: deflate
  accept: applicaiton/json
  connection: keep-alive
  content-type: application/json
  ~~~

  This function will replace any existing headers with the same name (regardless
  of casing).

  See `HTTPipe.Request.merge_headers/2` for more information.
  """
  @spec merge_req_headers(t, Request.headers) :: t
  def merge_req_headers(%__MODULE__{request: request} = conn, headers) do
    new_request = Request.merge_headers(request, headers)
    %__MODULE__{conn | request: new_request}
  end

  @doc """
  Sets an "Authorization" header with the appropriate value for Basic authentication.

  For example, to perform Basic authentication with the username `"username"` and password
  `"password"`:

  ~~~
  conn =
    Conn.new()
    |> Conn.put_req_url("https://httpbin.org/basic-auth/username/password")
    |> Conn.put_authentication_basic("username", "password")
  ~~~

  _This will replace any existing authentication header._

  See `HTTPipe.Request.put_authentication_basic/3` for more information.
  """
  @spec put_req_authentication_basic(t, String.t, String.t) :: t
  def put_req_authentication_basic(%__MODULE__{request: request} = conn, username, password) do
    new_request = Request.put_authentication_basic(request, username, password)
    %__MODULE__{conn | request: new_request}
  end

  @doc """
  Adds a request query parameter

  For example, this request:

  ~~~
  conn =
    Conn.new()
    |> Conn.put_req_url("https://google.com/#")
    |> Conn.put_req_param(:q, "httpipe elixir")
  ~~~

  will generate the following URL when the connection is executed:

  ~~~txt
  https://google.com/#?q=httpipe+elixir
  ~~~

  By default, if you have already set a parameter, setting it again with this function will
  overwrite the old value. You can pass a `Request.duplicate_options` atom as the final parameter
  to change this. See `HTTPipe.Request.put_param/4` for more information.
  """
  @spec put_req_param(t, String.t, String.t, Request.duplicate_options) :: t
  def put_req_param(%__MODULE__{request: request} = conn, param_name, value, duplication_option \\ :replace_existing) do
    new_request = Request.put_param(request, param_name, value, duplication_option)
    %__MODULE__{conn | request: new_request}
  end

  @doc """
  Deletes the named query parameter

  ## Example
  
  ~~~
  conn =
    Conn.new()
    |> Conn.put_req_url("https://google.com/#")
    |> Conn.put_req_param(:q, "httpipe elixir")
    |> Conn.put_req_param(:tbas, "0")
    |> Conn.delete_req_param(:q)
  ~~~

  will generate the following URL when the connection is executed:

  ~~~txt
  https://google.com/#?q=httpipe+elixir
  ~~~
  """
  @spec delete_req_param(t, String.t | atom) :: t
  def delete_req_param(%__MODULE__{request: request} = conn, param_name) do
    new_request = Request.delete_param(request, param_name)
    %__MODULE__{conn | request: new_request}
  end

  @doc """
  Returns the value of the response header, returning the default value
  if the header does not exist
  """
  @spec get_resp_header(t, String.t, any) :: String.t | any
  def get_resp_header(%__MODULE__{response: r}, header, default \\ nil) do
    Response.get_header(r, header, default)
  end

  # Retrieves the adapter which should be a module that implements
  # the HTTPipe.Adapter behaviour
  @spec get_adapter(:default | module) :: module
  defp get_adapter(:default) do
    Application.get_env(:httpipe, :adapter, HTTPipe.Adapters.Unimplemented)
  end

  defp get_adapter(adapter) do
    adapter
  end

  @doc """
  Sets the adapter to be used for this specific connection

  Adapters can be set on a per-connection basis. If you want to
  switch back to the default adapter, simply pass `:default` as
  the adapter name.

  For example, to use the Hackney adapter for a specific connection:

  ~~~
  conn =
    Conn.new()
    |> Conn.put_adapter(HTTPipe.Adapters.Hackney)
  ~~~
  """
  @spec put_adapter(t, :default | module) :: t
  def put_adapter(%__MODULE__{} = conn, adapter) do
    %__MODULE__{conn | adapter: adapter}
  end

  @doc """
  Defers the processing of the body to the adapter (or disables deferment)

  By default, deferment is turned off (`false`), and when the conn is executed
  the request body will be processed according the rules for `Request.encoded_body/1`.
  For example, in the following snippet:

  ~~~
  conn =
    Conn.new()
    |> Conn.add_req_body({:form, [name: "HTTPipe", language: "Elixir"]})
  ~~~

  when `Conn.execute(conn)` is called, the adapter will receive the following value for
  the body:

  ~~~txt
  name=HTTPipe&language=Elixir
  ~~~

  This is not always what you want. Some adapters have special handling for body
  values.
  If you would rather HTTPipe not process the body like this, you can turn
  deferment on (_i.e._, the body's processing is deferred to the adapter for handling):

  ~~~
  conn =
    Conn.new()
    |> Conn.add_req_body({:form, [name: "HTTPipe", language: "Elixir"]})
    |> Conn.defer_body_processing()
  ~~~

  The adapter will now receive the body as you set it:

  ~~~
  {:form, [name: "HTTPipe", language: "Elixir"]}
  ~~~

  If you have previously turned deferment on, or you want to ensure that it is off,
  you can pass `false` as the second argument to ensure that HTTPipe processes
  the body.
  """
  @spec defer_body_processing(t, boolean) :: t
  def defer_body_processing(%__MODULE__{options: options} = conn, defer? \\ true) do
    new_options = %{options | defer_body_processing: defer?}
    %__MODULE__{conn | options: new_options}
  end

  # Checks whether the body should be processed immediately or deferred to the adapter
  #
  #   true -> Do not process the request body; send it as-is to the adapter
  #   false -> Process the request body according to Request.encode_body/1
  #
  @spec defer_body_processing?(t) :: boolean
  defp defer_body_processing?(conn) do
    local_preference = conn.options.defer_body_processing
    general_preference = Application.get_env(:httpipe, :defer_body_processing, false)

    local_preference || general_preference
  end

  @doc """
  Returns a new `HTTPipe.Conn` struct

  This is currently the same as `%Conn{}`, but it provides a convenience function for those
  who prefer instantiating in this manner.
  """
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
  `HTTPipe.Request.inspect/2` and `HTTPipe.Response.inspect/2`.

  See `HTTPipe.InspectionHelpers` for more information
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
