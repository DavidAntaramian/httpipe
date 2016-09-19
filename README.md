# HTTPipe [![ISC License](https://img.shields.io/badge/license-ISC-ff69b4.svg)](LICENSE)

HTTPipe is an adapter-driven HTTP library for Elixir that provides a way
to build composable HTTP requests.

Inspired by the Plug library, HTTPipe provides a similar system by which
an HTTPipe.Conn struct is built and dispatched; though unlike Plug it
maintains the request and response under two separate keys.

HTTPipe does not actually handle the data-interchange, instead it relies
on a adapter library specified by the user. The adapter must conform to
the HTTPipe.Adapter behaviour. Specification of the adapter is done
globally with the `httpipe.adapter_module` configuration value, but
HTTPipe also allows adapters to be specified on a per-request basis.
This can be helpful for testing scenarios when you need to use a mocked
adapter for a test.

## Configuring an Adapter

To start using HTTPipe with you'll need an adapter. Adapters ship separate from HTTPipe,
so you can choose the one that best suits you. The easiest one to start with is the
[Hackney Adapter](https://hex.pm/packages/httpipe_adapters_hackney). We can configure
it in the `mix.exs` of a project like so:

```elixir
def deps do
  [
    {:httpipe_adapters_hackney, "~> 0.9"},
    {:httpipe, "~> 0.9}
  ]
end
```

Then call `mix deps.get`. Now in your `config/config.exs` file, set the Hackney Adapter
as the default:

```elixir
config :httpipe, :adapter, HTTPipe.Adapters.Hackney
```

## First Request

HTTPipe provides some quick-start functions in the `HTTPipe` module that we can immediately
test out. For example:

```elixir
{:ok, conn} = HTTPipe.get("https://httpbin.org/get")

conn.response.status_code # 200
```

You can also experiment with looking at `conn.response.body` and `conn.response.headers`.
This is simple stuff, though. Let's get into what HTTPipe is really about.

## Getting Composable

The composable suite of functions is kept in the `HTTPipe.Conn` module. We can make
the same request from the previous section using the composable functions:

```elixir
{:ok, conn} =
  HTTPipe.Conn.new()
  |> HTTPipe.Conn.put_req_url("https://httbin.org/get")
  |> HTTPipe.Conn.execute()

conn.response.status_code # 200
```

This is slightly more verbose, but the beauty of it comes in being able to break up the
composition of the `Conn`:

```elixir
def new_conn() do
  HTTPipe.Conn.new()
  |> HTTPipe.Conn.put_req_header("Accept", "application/json")
  |> HTTPipe.Conn.put_req_header("Accept-Charset", "utf-8")
  |> HTTPipe.Conn.put_req_header("Connection", "keep-alive")
  |> HTTPipe.Conn.put_req_header("Content-Type", "application/json; charset=utf8")
  |> HTTPipe.Conn.put_req_header("X-Api-Key", "81b31106741cad9d9f6e")
end

def get_user(user_id) do
  {:ok, conn} =
    new_conn()
    |> HTTPipe.Conn.put_req_url(@base_url <> "/users/#{user_id}")
    |> HTTPipe.Conn.put_req_param("include", "username,first_name,last_name")
    |> HTTPipe.Conn.put_req_method(:get)
    |> HTTPipe.Conn.execute()
end
```

For ease-of-use, you can of course `alias HTTPipe.Conn`, just be careful not to confuse it
with `Plug.Conn` if you are using both in the same project.

## Inspecting Your Connection

In an IEx console, try copying and pasting the following:

```elixir
conn = HTTPipe.Conn.new()
conn = HTTPipe.Conn.put_req_header(conn, "Accept", "application/json")
conn = HTTPipe.Conn.put_req_header(conn, "Accept-Charset", "utf-8")
conn = HTTPipe.Conn.put_req_header(conn, "Connection", "keep-alive")
conn = HTTPipe.Conn.put_req_header(conn, "Content-Type", "application/json; charset=utf8")
conn = HTTPipe.Conn.put_req_header(conn, "X-Api-Key", "81b31106741cad9d9f6e")
conn = HTTPipe.Conn.put_req_url(conn, "https://localhost/users/51")
conn = HTTPipe.Conn.put_req_param(conn, "include", "username,first_name,last_name")
conn = HTTPipe.Conn.put_req_method(conn, :get)
HTTPipe.Conn.inspect(conn)
```

## But what about...

There are plenty of existing HTTP libraries out there. Why another one? Part of the
inspiration came out of a discussion on the Elixir Slack about the usage of HTTPoison
versus using hackney directly. A few users mused that they would like an HTTP library
that was composable in much the same way Ecto and Plug are.

### HTTPoison

[HTTPoison](https://hex.pm/packages/httpoison) is a fantastic library by Eduardo Gurgel
that provides Elixir syntatic sugar for the Erlang [hackney](https://hex.pm/packages/hackney)
HTTP library. The two major features that HTTPipe provides over HTTPoison are *better
documentation* and *composable HTTP requests*.

### HTTPotion

[HTTPotion](https://hex.pm/packages/httpotion) is a libary that provides Elixir syntatic
sugar for the Erlang [ibrowse](https://hex.pm/packages/ibrowse) HTTP library. (HTTPotion
was the original; HTTPoison was created to provide a similar interface but for hackney).
HTTPotion is definitely not an option for users who don't like *ibrowse*, though. It also
doesn't have *composable HTTP requests*.

### Tesla

[Tesla](https://hex.pm/packages/tesla) is a recent package that provides an adapter-driven
HTTP library, but its attempts to use macros to build API wrappers doesn't feel right
in Elixir.

### hackney

[hackney](https://hex.pm/packages/hackney) is certainly one of the ranking Erlang packages.
It's well thought-out, has clear boundaries of responsibility, is well documented, and
is easy to use. It doesn't have *composable HTTP requests*, though. (Yes, there might be
a theme to this list.)

## Interoperability with HTTPoison & HTTPotion

HTTPipe is designed to be roughly interoperable with the basic functions
from HTTPoison and HTTPotion. It provides the `get/3`, `post/4`, `put/4`,
`delete/3`, `head/3`, `patch/4`, `options/3`, and `request/5` (and their
`bang!` style equivalents) to get you out the door. These will be converted
to `HTTPipe.Conn` structs and executed immediately.

Unlike HTTPoison/HTTPotion, HTTPipe returns an `HTTPipe.Conn` struct
which will not conform to any existing pattern matching you may do on
`Response` structs from other libraries. Typically, you will have to rearrange
your pattern matching to be on the internal `:response` key of the `Conn`
struct.

## Ongoing Improvements

For a list of improvements being considered, see the
[RFC issue list](https://github.com/DavidAntaramian/httpipe/issues?q=label%3ARFC).

## Copyright and License

Copyright (c) 2016 David Antaramian

Licensed under the [ISC License](LICENSE.md)
