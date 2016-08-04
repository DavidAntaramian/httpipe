defmodule HTTPlaster.Request do
  @moduledoc """
  
  """

  @typedoc """
  A specifier for the HTTP method

  The standard `GET`, `POST`, `PUT`, `DELETE`, HEAD`, `OPTIONS`, and `PATCH` methods
  should always be supported by HTTPlaster adapters. The specification also
  allows for non-standard methods to be passed as atoms, and it is advantageous
  for adapters to support these non-standard methods should clients need to connect
  to servers that use them.
  """
  @type http_method :: :get | :post | :put | :delete | :head | :options | :patch | atom

  @typedoc """
  Specifies a version of HTTP to use. The version should be specified as a t:String.t/0.

  Currently, HTTPlaster only knows how to support HTTP 1.1 transactions, however,
  HTTP 2 is planned.
  """
  @type http_version :: "1.1" 

  @typedoc """
  The body of a request must always be given as a t:String.t/0, `nil`, or
  t:body_encoding/0.


  In the event that the body is `nil`, the adapter _should not_ send a
  body payload. An empty string (`""`) should not be treated the same
  as `nil`.
  """
  @type body :: nil | String.t | body_encoding

  @type body_encoding :: {:file, String.t} | {:form, Keyword.t}

  @type headers :: Keyword.t

  @type duplicate_options :: :replace_existing | :prefer_existing | :duplicates_ok

  defstruct method: :get,
            body: nil,
            headers: [],
            http_version: "1.1" 
            
  @spec add_header(t, String.t, String.t, duplicate_options) :: t

  def add_header(request, header, value, duplication_option \\ :duplicates_ok)
end
