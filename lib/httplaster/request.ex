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

  @typedoc """
  The body of a request must always be given as a `String.t`, `nil`, or
  `body_encoding`.


  In the event that the body is `nil`, the adapter _should not_ send a
  body payload. An empty string (`""`) should not be treated the same
  as `nil`.
  """
  @type body :: nil | String.t | body_encoding

  @type body_encoding :: {:file, String.t} | {:form, Keyword.t}

  @type headers :: map()

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

  @spec put_header(Conn.t, String.t, String.t, duplicate_options) :: Conn.t
  def put_header(conn, header, value, duplication_option \\ :duplicates_ok)

  def put_header(conn, header, value, :replace_existing) do
    headers = conn.request.headers
              |> Map.put(header, value)

    %Conn{conn | request: %__MODULE__{ conn.request | headers: headers}}
  end

  @spec put_method(Conn.t, http_method) :: Conn.t
  def put_method(conn, method) do
    %Conn{conn | request: %__MODULE__{ method: method}}
  end

  @spec put_param(Conn.t, String.t, String.t, duplicate_options) :: Conn.t
  def put_param(conn, param_name, value, duplication_option \\ :replace_existing)

  def put_param(conn, param_name, value, :replace_existing) do
    params = conn.request.params
             |> Map.put(param_name, value)

    %Conn{conn | request: %__MODULE__{ conn.request | params: params}}
  end

  @spec put_url(Conn.t, String.t) :: Conn.t
  def put_url(conn, url) do
    %Conn{conn | request: %__MODULE__{ conn.request | url: url}}
  end
end
