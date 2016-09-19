defmodule HTTPlaster.Request do
  @moduledoc ~S"""
  An HTTP request that will be sent to the server

  Note: The functions in this module will typically take an `HTTPlaster.Request` struct
  as their first parameter and return an updated struct. Under most circumstances,
  you will want to use the functions defined in `HTTPlaster.Conn` which take `Conn`
  structs and update internal `Request` structs.
  """

  alias HTTPlaster.InspectionHelpers
  alias __MODULE__.{NilURLError}

  @typedoc """
  A specifier for the HTTP method

  The standard `GET`, `POST`, `PUT`, `DELETE`, `HEAD`, `OPTIONS`, and `PATCH` methods
  should always be supported by HTTPlaster adapters. The specification also
  allows for non-standard methods to be passed as atoms, and it is advantageous
  for adapters to support these non-standard methods should clients need to connect
  to servers that use them.

  That being said, not all adapters will support non-standard methods. For example,
  the :httpc module which is distributed with Erlang does not support anything outside
  the "standard" method plus "TRACE".
  """
  @type http_method :: :get | :post | :put | :delete | :head | :options | :patch | atom

  @typedoc ~S"""
  Specifies a version of HTTP to use. The version should be specified as a `String.t`.

  Currently, HTTPlaster only knows how to support HTTP 1.1 transactions, however,
  HTTP 2 is a future possibility.
  """
  @type http_version :: String.t

  @typdoc ~S"""
  Specifies a resource to access

  The URL should include the scheme, domain, and request path.
  It is possible for the URL to be `nil`, but this will cause an error
  when attempting to execute the request.
  """
  @type url :: String.t | nil

  @typedoc ~S"""
  The body of a request must always be given as a `String.t`, `nil`, or
  `body_encoding`.

  A `nil` body is shorthand for an empty string (`""`) which will be sent
  when the connection is executed.
  """
  @type body :: nil | String.t | body_encoding

  @typedoc ~S"""
  The body encoding specifies a specific way to encode the body
  prior to sending it to the server.

  It is still the responsibility of the consumer to set the appropriate
  `Content-Type` header.

  ## Sending Files

  The `{:file, filename}` option  will cause the file located at `:file` to
  be sent as the body of the request. Note that this is not the same as
  sending a file with `mutlipart/form-data`. In this case, the file's contents
  will be the payload of the request.

  ## Form-Encoding

  The `{:form, parameters}` option will cause the parameters (encoded as keyword lists)
  to be sent to be transformed into a `form-urlencoded` value before being
  sent as the body of the request.
  """
  @type body_encoding :: {:file, String.t} | {:form, Keyword.t}

  @typedoc ~S"""
  Headers are stored in a map of header names (in lower case)
  to their values.

  The names and values are always of the type `String.t`.

  For example:

  ~~~
  %{
    "accept" => "application/json",
    "content-type" => "application/json"
  }
  ~~~

  For more information, see the documentation for `put_header/4`.
  """
  @type headers :: %{required(String.t) => String.t}

  @typedoc ~S"""
  Query params are stored as a map of keys as strings to a _list_
  of string values.

  Because it is possible for query parameters to be repeated in
  a query string, values are stored in a list.

  For example:

  ~~~
  %{
    "q" => ["Elixir HTTPlaster"],
    "tbas" => [0, 1]
  }
  ~~~

  will be encoded as:

  ~~~txt
  q=Elixir+HTTPlaster&tbas=0&tbas=1
  ~~~

  Unlike headers, query parameters are stored in the case they are provided
  in. For more information, see the documentation for `put_param/4`.
  """
  @type params :: %{required(String.t) => [String.t]}

  @typedoc """
  Duplication options for setting headers and query params

  #### :duplicates_ok

  If a value already exists, the new value will be merged with the
  current value

  #### :prefer_existing

  If a value already exists, the new value will be discarded

  #### :replace_existing

  If a value already exists, the new value will overwrite the existing
  value
  """
  @type duplicate_options :: :replace_existing | :prefer_existing | :duplicates_ok

  @typedoc """
  Encapsulates an HTTP request

  #### :method

  The HTTP method to use for the request. See the `http_method` type.

  #### :http_version

  The HTTP version to use for the request. See the `http_version` type.

  #### :url

  The URL to make the request against. By default, this is `nil`. See the `url` type.

  #### :headers
  
  The headers for the request. By default, this is an empty map. See the `headers` type.

  #### :params
  
  The query params for the request. By default, this is an empty map. See the `params` type.

  #### :body
  
  The body for the request. By default, this is `nil`. See the `body` type.
  """
  @type t :: %__MODULE__{
               method: http_method,
               http_version: http_version,
               url: url,
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

  Following the guidance of
  [RFC 2612 4.2](https://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.2),
  duplicate headers are accomodated by flattening them into a comma-separated
  list. This is the default behavior. For example,

  ~~~
  %HTTPlaster.Request{}
  |> Request.put_header("Accept-Encoding", "gzip")
  |> Request.put_header("Accept-Encoding", "deflate")
  ~~~

  will be flattened to the following header:

  ~~~txt
  accept-encoding: gzip, deflate
  ~~~

  However, this behavior can be changed by specifying a different behavior
  for duplicates as the final parameter. If `replace_existing` is passed,
  the new value will always replace the existing value. If `prefer_existing`
  is passed, the header will only be updated if there is no existing value.
  """
  @spec put_header(t, String.t, String.t, duplicate_options) :: t
  def put_header(request, header_name, header_value, duplication_option \\ :duplicates_ok)

  def put_header(request, header_name, header_value, :duplicates_ok) do
    name = String.downcase(header_name)
    headers =
      request.headers
      |> Map.update(name, header_value, fn existing ->
        "#{existing}, #{header_value}"
      end)

    %__MODULE__{request | headers: headers}
  end

  def put_header(request, header_name, header_value, :prefer_existing) do
    name = String.downcase(header_name)

    headers =
      request.headers
      |> Map.put_new(name, header_value)

    %__MODULE__{request | headers: headers}
  end

  def put_header(request, header_name, header_value, :replace_existing) do
    name = String.downcase(header_name)

    headers =
      request.headers
      |> Map.put(name, header_value)

    %__MODULE__{request | headers: headers}
  end

  @doc """
  Clears the existing request headers

  This will reset the internal store of request headers to an empty map.
  However, certain default request headers determined by the adapter
  will still be sent even if the headers map is empty.
  """
  @spec clear_headers(t) :: t
  def clear_headers(request) do
    %__MODULE__{request | headers: %{}}
  end

  @doc """
  Merges a map of headers into the existing headers

  ## Example

  ~~~
  headers_to_merge = %{
    "accept" => "application/json",
    "accept-encoding" => "deflate",
    "connection" => "keep-alive"
  }

  %Request{}
  |> Request.put_header("Accept", "application/xml")
  |> Request.put_header("Content-Type", "application/json")
  |> Request.put_header("Accept-Encoding", "gzip")
  |> Request.merge_headers(headers_to_merge)
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
  """
  @spec merge_headers(t, headers) :: t
  def merge_headers(request, headers) do
    Enum.reduce(headers, request, fn {k, v}, acc_req ->
      put_header(acc_req, k, v, :replace_existing)
    end)
  end

  @doc """
  Sets the method to be used with the request
  """
  @spec put_method(t, http_method) :: t
  def put_method(request, method) do
    %__MODULE__{request | method: method}
  end

  @doc """
  Adds a query parameter to the request

  ## Example
  For example, this request:

  ~~~
  %Request{}
  |> Request.put_url("https://google.com/#")
  |> Request.put_param(:q, "httplaster elixir")
  ~~~

  will generate the following URL when the connection is executed:

  ~~~txt
  https://google.com/#?q=httplaster+elixir
  ~~~
  """
  @spec put_param(t, String.t | atom, String.t, duplicate_options) :: t
  def put_param(request, param_name, value, duplication_option \\ :replace_existing)

  def put_param(request, param_name, value, :replace_existing) do
    param_name = param_to_string(param_name)

    params =
      request.params
      |> Map.put(param_name, [value])

    %__MODULE__{request | params: params}
  end

  def put_param(request, param_name, value, :duplicates_ok) do
    param_name = param_to_string(param_name)

    params =
      request.params
      |> Map.update(param_name, [value], fn existing ->
        [value | existing]
      end)

    %__MODULE__{request | params: params}
  end

  def put_param(request, param_name, value, :prefer_existing) do
    param_name = param_to_string(param_name)

    params =
      request.params
      |> Map.put_new(param_name, [value])

    %__MODULE__{request | params: params}
  end

  # Ensures the param name is a string
  @spec param_to_string(String.t | atom) :: String.t
  defp param_to_string(a) when is_atom(a) do
    Atom.to_string(a)
  end

  defp param_to_string(s) when is_binary(s) do
    s
  end

  @doc """
  Sets an "Authorization" header with the appropriate value for Basic authentication.
  """
  @spec put_authentication_basic(t, String.t, String.t) :: t
  def put_authentication_basic(request, username, password) do
    credentials =
      "#{username}:#{password}"
      |> Base.url_encode64(case: :lower)

    put_header(request, "Authorization", "Basic #{credentials}", :replace_existing)
  end

  @doc """
  Sets the request body

  The body can be any valid type detailed in the `body` type.
  """
  @spec put_body(t, body) :: t
  def put_body(request, body) do
    %__MODULE__{request | body: body}
  end

  @doc """
  Combines the given URL with the query params

  If the URL is `nil`, this will return an `{:error, NilURLError}`
  """
  @spec prepare_url(url, params) :: {:ok, String.t} | {:error, Exception.t}
  def prepare_url(nil, _) do
    error = NilURLError.exception([])

    {:error, error}
  end

  def prepare_url(base_url, params) do
    p =
      Enum.flat_map(params, fn {key, values} ->
        Enum.map(values, fn v -> {key, v} end)
      end)
      |> URI.encode_query()

    {:ok, append_params(base_url, p)}
  end

  # Helper function to append the query params string
  # to the URL, returning the URL itself if the query params
  # string is empty
  @spec append_params(url, String.t | params) :: String.t
  defp append_params(url, "") do
    url
  end

  defp append_params(url, params) do
    "#{url}?#{params}"
  end

  @doc """
  Encodes the body using `encode_body/1`, if `defer_body_processing` is `true`,
  otherwise returns the body as-is.
  """
  @spec prepare_body(body, boolean) :: {:ok, String.t | body} | {:error, Exception.t}
  def prepare_body(body, defer_body_processing)

  def prepare_body(body, true) do
    {:ok, body}
  end

  def prepare_body(body, false) do
    encode_body(body)
  end

  @doc """
  Encodes the body to a string. Accepts special forms of tuples as described
  by `body_encoding`.

  Due to the special forms this function supports, it can encounter a wide array
  of error. If you call this function, make sure to match on the return value.
  """
  @spec encode_body(body) :: {:ok, String.t} | {:error, Exception.t}
  def encode_body(body)

  def encode_body(body) when is_binary(body) do
    {:ok, body}
  end

  def encode_body(nil) do
    {:ok, ""}
  end

  def encode_body({:form, form_data}) do
    {:ok, URI.encode_query(form_data)}
  end

  def encode_body({:file, filepath}) do
    case File.read(filepath) do
      {:ok, binary} ->
        {:ok, binary}
      {:error, reason} ->
        error = File.Error.exception(reason: reason, action: "read file", path: filepath)
        {:error, error}
    end
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
  @spec put_url(t, String.t) :: t
  def put_url(request, url) do
    %__MODULE__{request | url: url}
  end

  @doc """
  Inspects the structure of the Request struct passed in the same
  way `IO.inspect/1` might, returning the Request struct so that it
  can be used easily with pipes.

  Typically, `Kernel.inspect/1`, `IO.inspect/1`, and their companions are
  implemented using the `Inspect` protocol. However, the presentation used
  here can get extremely intrusive when experimenting using IEx, so it's
  relegated to this function. Corresponding functions can be found at
  `HTTPlaster.Conn.inspect/2` and `HTTPlaster.Response.inspect/2`.

  See `HTTPlaster.InspectionHelpers` for more information
  """
  @spec inspect(t, Keyword.t) :: t
  def inspect(req, opts \\ []) do
    opts = struct(Inspect.Opts, opts)

    InspectionHelpers.inspect_request(req, opts)
    |> Inspect.Algebra.format(:infinity)
    |> IO.puts()

    req
  end
end
