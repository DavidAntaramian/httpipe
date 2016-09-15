defmodule HTTPlaster.Request do
  @moduledoc ~S"""
  An HTTP request that will be sent to the server

  Note: The functions in this module will typically take an `HTTPlaster.Conn`
  as their first parameter and operate on the request struct located under the
  `:request` key of the conn. It will then return a `HTTPlaster.Conn` with
  an updated `:request` key.
  """

  alias HTTPlaster.Conn

  @typedoc """
  A specifier for the HTTP method

  The standard `GET`, `POST`, `PUT`, `DELETE`, `HEAD`, `OPTIONS`, and `PATCH` methods
  should always be supported by HTTPlaster adapters. The specification also
  allows for non-standard methods to be passed as atoms, and it is advantageous
  for adapters to support these non-standard methods should clients need to connect
  to servers that use them.
  """
  @type http_method :: :get | :post | :put | :delete | :head | :options | :patch | atom

  @typedoc ~S"""
  Specifies a version of HTTP to use. The version should be specified as a `String.t`.

  Currently, HTTPlaster only knows how to support HTTP 1.1 transactions, however,
  HTTP 2 is a future possibility.
  """
  @type http_version :: String.t

  @typedoc ~S"""
  The body of a request must always be given as a `String.t`, `nil`, or
  `body_encoding`.

  In the event that the body is `nil`, the adapter _should not_ send a
  body payload. An empty string (`""`) should not be treated the same
  as `nil`.
  """
  @type body :: nil | String.t | body_encoding

  @typedoc ~S"""
  The body encoding specifies a specific way to encode the body
  prior to sending it to the server.

  ## Sending Files
  
  The `{:file, filename}` option  will cause the file located at `:file` to
  be sent as the body of the request.

  ## Form-Encoding
  
  The `{:form, parameters}` option will cause the parameters (encoded as keyword lists)
  to be sent to be transformed into a `form-urlencoded` value before being
  sent as the body of the request.
  """
  @type body_encoding :: {:file, String.t} | {:form, Keyword.t}

  @typedoc ~S"""
  Headers are stored in a map array of header name (in lower case)
  as a binary to the value as a binary.
  
  For more information, see the documentation for `add_header/4`.
  """
  @type headers :: %{required(String.t) => String.t}

  @type params :: map()

  @type duplicate_options :: :replace_existing | :prefer_existing | :duplicates_ok

  @type t :: %__MODULE__{
               method: http_method,
               http_version: http_version,
               url: String.t,
               headers: headers,
               params: params,
               body: body,
             }

  defstruct method: :get,
            url: nil,
            http_version: "1.1",
            headers: %{},
            params: %{},
            body: nil

  @doc """
  Adds a header to the request

  ## Casing

  Header names are case-insensitive: they may be passed to this function in any
  case; however, in order to aid in de-duplication, header names will be stored
  in lower case.

  ## Duplicate Headers

  Following the guidance of [RFC 2612 4.2](https://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.2),
  duplicate headers are accomodated by flattening them into a comma-separated
  list. This is the default behavior. For example,

  ```elixir
  %HTTPlaster.Conn{}
  |> HTTPlaster.Request.add_header("Accept-Encoding", "gzip")
  |> HTTPlaster.Request.add_header("Accept-Encoding", "deflate")
  ```

  will be flattened to the following header:

  ```text
  Accept-Encoding: gzip, deflate
  ```

  However, this behavior can be changed by specifying a different behavior
  for duplicates as the final parameter. If `replace_existing` is passed,
  the new value will always replace the existing value. If `prefer_existing`
  is passed, the header will only be updated if there is no existing value.
  """
  @spec add_header(Conn.t, String.t, String.t, duplicate_options) :: Conn.t
  def add_header(conn, header_name, header_value, duplication_option \\ :duplicates_ok)

  def add_header(conn, header_name, header_value, :duplicates_ok) do
    name = String.downcase(header_name)
    headers = conn.request.headers
              |> Map.get_and_update(name, fn
                 nil -> header_value
                 existing -> "#{existing}, #{header_value}"
              end)

    %Conn{conn | request: %__MODULE__{ conn.request | headers: headers}}
  end

  def add_header(conn, header_name, header_value, :prefer_existing) do
    name = String.downcase(header_name)
    headers = conn.request.headers
              |> Map.put_new(name, header_value)

    %Conn{conn | request: %__MODULE__{ conn.request | headers: headers}}
  end

  def add_header(conn, header_name, header_value, :replace_existing) do
    name = String.downcase(header_name)
    headers = conn.request.headers
              |> Map.put(name, header_value)

    %Conn{conn | request: %__MODULE__{ conn.request | headers: headers}}
  end

  @spec put_headers(Conn.t, headers) :: Conn.t
  def put_headers(conn, headers) do
    %Conn{conn | request: %__MODULE__{ conn.request | headers: headers}}
  end

  @spec put_method(Conn.t, http_method) :: Conn.t
  def put_method(conn, method) do
    %Conn{conn | request: %__MODULE__{ method: method}}
  end

  @spec add_param(Conn.t, String.t, String.t, duplicate_options) :: Conn.t
  def add_param(conn, param_name, value, duplication_option \\ :replace_existing)

  def add_param(conn, param_name, value, :replace_existing) do
    params = conn.request.params
             |> Map.put(param_name, value)

    %Conn{conn | request: %__MODULE__{ conn.request | params: params}}
  end

  @doc """
  """
  @spec put_authentication_basic(Conn.t, String.t, String.t) :: Conn.t
  def put_authentication_basic(conn, username, password) do
    "#{username}:#{password}"
    |> Base.encode64(case: :lower)

  end

  @doc """
  Sets the URL for the resource to operate on.

  The URL should include the scheme (`http://` or `https://`) as well
  as the fully qualified domain name, and the request path for the
  resource. If necessary, also include the port.

  ## Basic Authentication
  
  If you need to use HTTP Basic authentication, *do not* include the
  username and password as part of the URL. Instead, please use the
  `put_authentication_basic/3` function.
  """
  @spec put_url(Conn.t, String.t) :: Conn.t
  def put_url(conn, url) do
    %Conn{conn | request: %__MODULE__{ conn.request | url: url}}
  end
end
