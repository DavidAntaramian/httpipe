defmodule HTTPipe.ConnTest do
  use ExUnit.Case, async: true

  alias HTTPipe.{Conn, Request, Response}
  alias HTTPipe.Adapters.UnimplementedError
  alias HTTPipe.Request.NilURLError

  alias Plug.Conn, as: Server

  setup tags do
    default_adapter = Application.get_env(:httpipe, :adapter)

    if tags[:httpc_adapter] do
      Application.put_env(:httpipe, :adapter, HTTPipe.Adapters.HTTPC)
    end

    on_exit(fn ->
      Application.put_env(:httpipe, :adapter, default_adapter)
    end)

    :ok
  end

  describe "HTTPipe.Conn.clear_req_headers/1" do
    test "clears request headers" do
      conn =
        %Conn{request: %Request{headers: %{"accept": "application/json"}}}
        |> Conn.clear_req_headers()

      assert map_size(conn.request.headers) == 0
    end

    @tag :httpc_adapter
    test "does not send existing headers to server" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        refute {"accept", "application/json"} in server_conn.req_headers

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{request: %Request{headers: %{"accept": "application/json"}}}
        |> Conn.put_req_url(url)
        |> Conn.clear_req_headers()
        |> Conn.execute()
    end
  end

  describe "HTTPipe.Conn.defer_body_processing" do
    test "by default will set defer to true" do
      conn =
        Conn.new()
        |> Conn.defer_body_processing()

      assert conn.options.defer_body_processing == true
    end

    test "will set defer to false" do
      conn =
        Conn.new()
        |> Conn.defer_body_processing(false)

      assert conn.options.defer_body_processing == false
    end
  end

  describe "HTTPipe.Conn.execute/1" do
    test "defers body processing" do
      req_body = {:json, %{"project" => %{"name" => "HTTPipe"}}}

      defmodule TestAdapter do
        @moduledoc false
        @behaviour HTTPipe.Adapter

        def execute_request(_, _, exec_body, _, _) do
          assert exec_body == {:json, %{"project" => %{"name" => "HTTPipe"}}}
          {:ok, {204, %{}, ""}}
        end
      end

      {:ok, _conn} =
        Conn.new()
        |> Conn.defer_body_processing()
        |> Conn.put_adapter(TestAdapter)
        |> Conn.put_req_url("http://localhost/")
        |> Conn.put_req_body(req_body)
        |> Conn.execute()
    end
  end

  describe "HTTPipe.Conn.execute!/1" do
    test "raises UnimplementedError" do
      assert_raise UnimplementedError, fn ->
        Conn.new()
        |> Conn.put_req_url("https://google.com/")
        |> Conn.execute!()
      end
    end

    test "raises NilURLError when URL is nil" do
      assert_raise NilURLError, fn ->
        Conn.new()
        |> Conn.execute!()
      end
    end
  end

  describe "HTTPipe.Conn.merge_req_headers/2" do
    @tag :httpc_adapter
    test "sends existing headers to server merged with new ones" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      existing_req_accept_header = {"accept", "application/json"}

      existing_req_headers =
        [existing_req_accept_header]
        |> Enum.into(%{})

      req_accept_header = {"accept", "application/xml"}
      req_content_type_header = {"content-type", "application/json"}

      req_headers =
        [req_accept_header, req_content_type_header]
        |> Enum.into(%{})

      Bypass.expect(server, fn server_conn ->
        refute existing_req_accept_header in server_conn.req_headers
        assert req_accept_header in server_conn.req_headers
        assert req_content_type_header in server_conn.req_headers

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{request: %Request{headers: existing_req_headers}}
        |> Conn.merge_req_headers(req_headers)
        |> Conn.put_req_url(url)
        |> Conn.execute()
    end
  end

  describe "HTTPipe.Conn.new/0" do
    test "returns a new Conn struct" do
      conn = Conn.new()

      assert conn.__struct__ == Conn
    end
  end

  describe "HTTPipe.Conn.put_adapter/2" do
    test "changes the adapter used" do
      conn =
        Conn.new()
        |> Conn.put_adapter(Unimplemented)

      assert conn.adapter == Unimplemented
    end
  end

  describe "HTTPipe.Conn.put_adapter_options/2" do
    test "adds adapter option" do
      conn =
        Conn.new()
        |> Conn.put_adapter_options([pool: :httpipe])

      assert {:pool, :httpipe} in conn.adapter_options
    end
  end

  describe "HTTPipe.Conn.put_req_authentication_basic/3" do
    @tag :httpc_adapter
    test "encodes authorization header" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      expected_value = "Basic dXNlcm5hbWU6cGFzc3dvcmQ="

      Bypass.expect(server, fn server_conn ->
        assert {"authorization", expected_value} in server_conn.req_headers

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.put_req_authentication_basic("username", "password")
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "authenticates against httpbin" do
      username = "username"
      password = "password"
      url = "https://httpbin.org/basic-auth/#{username}/#{password}"

      {:ok, client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.put_req_authentication_basic("username", "password")
        |> Conn.execute()

      assert client_conn.status == :executed
      assert client_conn.response.status_code == 200
    end
  end

  describe "HTTPipe.Conn.put_req_body/2" do
    @tag :httpc_adapter
    test "puts the request body" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      req_body = "Hello"

      Bypass.expect(server, fn server_conn ->
        {:ok, server_body, server_conn} = Plug.Conn.read_body(server_conn)

        assert server_body == req_body

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.put_req_method(:post)
        |> Conn.put_req_body(req_body)
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "puts a form body" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      req_body = {:form, [q: "plataformatec Elixir", tbas: 0]}

      Bypass.expect(server, fn server_conn ->
        {:ok, server_body, server_conn} = Plug.Conn.read_body(server_conn)

        assert server_body == "q=plataformatec+Elixir&tbas=0"

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.put_req_header("content-type", "application/x-www-form-urlencoded")
        |> Conn.put_req_method(:post)
        |> Conn.put_req_body(req_body)
        |> Conn.execute()
    end
  end

  describe "HTTPipe.Conn.put_req_header/4" do
    @tag :httpc_adapter
    test "with default duplication option will flatten values" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert {"accept-encoding", "gzip, deflate"} in server_conn.req_headers

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.put_req_header("Accept-Encoding", "gzip")
        |> Conn.put_req_header("Accept-Encoding", "deflate")
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "with :duplicates_ok will flatten values" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert {"accept-encoding", "gzip, deflate"} in server_conn.req_headers

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.put_req_header("Accept-Encoding", "gzip", :duplicates_ok)
        |> Conn.put_req_header("Accept-Encoding", "deflate", :duplicates_ok)
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "with :prefer_existing will not replace existing values" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
      assert {"accept-encoding", "gzip"} in server_conn.req_headers

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.put_req_header("Accept-Encoding", "gzip", :prefer_existing)
        |> Conn.put_req_header("Accept-Encoding", "deflate", :prefer_existing)
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "with :replace_existing will replace existing values" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert {"accept-encoding", "deflate"} in server_conn.req_headers

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.put_req_header("Accept-Encoding", "gzip", :replace_existing)
        |> Conn.put_req_header("Accept-Encoding", "deflate", :replace_existing)
        |> Conn.execute()
    end
  end

  describe "HTTPipe.Conn.delete_req_header/2" do
    @tag :httpc_adapter
    test "deletes the header" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        header_names = Enum.map(server_conn.req_headers, fn {name, _} -> name end)

        refute "accept-encoding" in header_names

        Server.send_resp(server_conn, 204, "")
      end)

      headers = %{"accept-encoding" => "gzip"}

      {:ok, _client_conn} =
        %Conn{request: %Request{headers: headers}}
        |> Conn.put_req_url(url)
        |> Conn.delete_req_header("Accept-Encoding")
        |> Conn.execute()
    end
  end

  describe "HTTPipe.Conn.put_req_method/2" do
    @tag :httpc_adapter
    test "sends GET method to server" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.method == "GET"
        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.put_req_method(:get)
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "replaces existing method" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.method == "POST"
        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{request: %Request{method: :get}}
        |> Conn.put_req_url(url)
        |> Conn.put_req_method(:post)
        |> Conn.execute()
    end
  end

  describe "HTTPipe.Conn.put_req_param/4" do
    @tag :httpc_adapter
    test "with default duplication option will replace existing params" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.query_string == "q=plataformatec+Elixir&tbas=1"
        Server.send_resp(server_conn, 204, "")
      end)

      params = %{"q" => ["plataformatec Elixir"], "tbas" => [0]}

      {:ok, _client_conn} =
        %Conn{request: %Request{params: params}}
        |> Conn.put_req_url(url)
        |> Conn.put_req_param(:tbas, 1)
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "with :duplicates_ok will prepend to the list of values" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.query_string == "q=plataformatec+Elixir&tbas=1&tbas=0"
        Server.send_resp(server_conn, 204, "")
      end)

      params = %{"q" => ["plataformatec Elixir"], "tbas" => [0]}

      {:ok, _client_conn} =
        %Conn{request: %Request{params: params}}
        |> Conn.put_req_url(url)
        |> Conn.put_req_param(:tbas, 1, :duplicates_ok)
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "with :prefer_existing will leave values as-is" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.query_string == "q=plataformatec+Elixir&tbas=0"
        Server.send_resp(server_conn, 204, "")
      end)

      params = %{"q" => ["plataformatec Elixir"], "tbas" => [0]}

      {:ok, _client_conn} =
        %Conn{request: %Request{params: params}}
        |> Conn.put_req_url(url)
        |> Conn.put_req_param(:tbas, 1, :prefer_existing)
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "with :replace_existing will replace existing values" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.query_string == "q=plataformatec+Elixir&tbas=1"
        Server.send_resp(server_conn, 204, "")
      end)

      params = %{"q" => ["plataformatec Elixir"], "tbas" => [0]}

      {:ok, _client_conn} =
        %Conn{request: %Request{params: params}}
        |> Conn.put_req_url(url)
        |> Conn.put_req_param(:tbas, 1, :replace_existing)
        |> Conn.execute()
    end
  end

  describe "HTTPipe.Conn.delete_req_param/2" do
    @tag :httpc_adapter
    test "deletes the name parameter (string)" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.query_string == "q=plataformatec+Elixir"
        Server.send_resp(server_conn, 204, "")
      end)

      params = %{"q" => ["plataformatec Elixir"], "tbas" => [0]}

      {:ok, _client_conn} =
        %Conn{request: %Request{params: params}}
        |> Conn.put_req_url(url)
        |> Conn.delete_req_param("tbas")
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "deletes the name parameter (atom)" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.query_string == "q=plataformatec+Elixir"
        Server.send_resp(server_conn, 204, "")
      end)

      params = %{"q" => ["plataformatec Elixir"], "tbas" => [0]}

      {:ok, _client_conn} =
        %Conn{request: %Request{params: params}}
        |> Conn.put_req_url(url)
        |> Conn.delete_req_param(:tbas)
        |> Conn.execute()
    end
  end

  describe "HTTPipe.Conn.get_resp_header/3" do
    test "returns the value of the header" do
      headers = %{"content-type" => "test/html"}
      response = %Response{headers: headers}
      conn = %Conn{response: response}

      value = Conn.get_resp_header(conn, "content-type")

      assert value == "test/html"
    end

    test "returns the nil when the header does not exist" do
      headers = %{}
      response = %Response{headers: headers}
      conn = %Conn{response: response}

      value = Conn.get_resp_header(conn, "content-type")

      assert value == nil
    end
    
    test "returns the specified default value when the header does not exist" do
      headers = %{}
      response = %Response{headers: headers}
      conn = %Conn{response: response}

      value = Conn.get_resp_header(conn, "content-type", "text/html")

      assert value == "text/html"
    end
  end

  describe "HTTPipe.Conn.put_req_url/2" do
    test "sets the URL of the request" do
      conn =
        %Conn{}
        |> Conn.put_req_url("https://google.com/")

      assert conn.request.url == "https://google.com/"
    end

    @tag :httpc_adapter
    test "sends the correct URL to the server" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.host == "localhost"
        assert server_conn.port == server.port

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{}
        |> Conn.put_req_url(url)
        |> Conn.execute()
    end

    @tag :httpc_adapter
    test "replaces existing URL" do
      server = Bypass.open()
      url = "http://localhost:#{server.port}/"

      Bypass.expect(server, fn server_conn ->
        assert server_conn.host == "localhost"
        assert server_conn.port == server.port

        Server.send_resp(server_conn, 204, "")
      end)

      {:ok, _client_conn} =
        %Conn{request: %Request{url: "https://google.com/"}}
        |> Conn.put_req_url(url)
        |> Conn.execute()
    end
  end
end
