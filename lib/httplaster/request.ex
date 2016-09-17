defmodule HTTPlaster.Request do
  @moduledoc ~S"""
  An HTTP request that will be sent to the server

  Note: The functions in this module will typically take an `HTTPlaster.Request` struct
  as their first parameter and return an updated struct. Under most circumstances,
  you will want to use the functions defined in `HTTPlaster.Conn` which take `Conn`
  structs and update internal `Request` structs.
  """

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

  @typdoc ~S"""
  """
  @type url :: String.t

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
  
  For more information, see the documentation for `put_header/4`.
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
  %HTTPlaster.Request{}
  |> Request.put_header("Accept-Encoding", "gzip")
  |> Request.put_header("Accept-Encoding", "deflate")
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
  @spec put_header(t, String.t, String.t, duplicate_options) :: t
  def put_header(request, header_name, header_value, duplication_option \\ :duplicates_ok)

  def put_header(request, header_name, header_value, :duplicates_ok) do
    name = String.downcase(header_name)
    headers = request.headers
              |> Map.update(name, header_value, fn existing ->
                "#{existing}, #{header_value}"
              end)

    %__MODULE__{request | headers: headers}
  end

  def put_header(request, header_name, header_value, :prefer_existing) do
    name = String.downcase(header_name)
    headers = request.headers
              |> Map.put_new(name, header_value)

    %__MODULE__{ request | headers: headers}
  end

  def put_header(request, header_name, header_value, :replace_existing) do
    name = String.downcase(header_name)
    headers = request.headers
              |> Map.put(name, header_value)

    %__MODULE__{ request | headers: headers}
  end

  @spec put_headers(t, headers) :: t
  def put_headers(request, headers) do
    %__MODULE__{ request | headers: headers}
  end

  @spec put_method(t, http_method) :: t
  def put_method(request, method) do
    %__MODULE__{ request | method: method}
  end

  @spec put_param(t, String.t, String.t, duplicate_options) :: t
  def put_param(request, param_name, value, duplication_option \\ :replace_existing)

  def put_param(request, param_name, value, :replace_existing) do
    params = request.params
             |> Map.put(param_name, value)

    %__MODULE__{ request | params: params}
  end

  @spec put_authentication_basic(t, String.t, String.t) :: t
  def put_authentication_basic(request, username, password) do
    credentials =
      "#{username}:#{password}"
      |> Base.url_encode64(case: :lower)
    
    put_header(request, "Authorization", "Basic #{credentials}", :replace_existing)
  end
  
  @spec put_body(t, body) :: t
  def put_body(request, body) do
    %__MODULE__{ request | body: body }
  end

  @spec prepare_url(url, params) :: String.t
  def prepare_url(base_url, params) do
    p = Enum.flat_map(params, fn
          {key, values} when is_list(values) -> Enum.map(values, &({key, &1}))
          val -> [val]
        end)
        |> URI.encode_query()

    append_params(base_url, p)
  end

  @spec append_params(url, String.t | params) :: String.t
  defp append_params(url, ""), do: url
  defp append_params(url, params), do: "#{url}?#{params}"

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
    %__MODULE__{ request | url: url}
  end

  defimpl Inspect do
    import Inspect.Algebra
    import HTTPlaster.InspectionHelpers

    @spec inspect(HTTPlaster.Request, Inspect.Opts.t) :: Inspect.Algebra.t
    def inspect(request, opts) do
      headers = inspect_headers(request.headers)
      method = inspect_method(request.method)
      url = inspect_url(request.url, opts)
      full_url = inspect_full_url(request.url, request.params, opts)
      params = inspect_params(request.params, opts)
      body = inspect_body(request.body, opts)

      concat [
        "Request",
        method,
        url,
        full_url,
        headers,
        params,
        body
      ]
    end
  end
end
