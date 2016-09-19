defmodule HTTPlasterTest do
  use ExUnit.Case, async: false

  @lint {Credo.Check.Design.AliasUsage, false}

  setup do
    default_adapter = Application.get_env(:httplaster, :adapter)

    Application.put_env(:httplaster, :adapter, HTTPlaster.Adapters.HTTPC)

    on_exit(fn ->
      Application.put_env(:httplaster, :adapter, default_adapter)
    end)

    :ok
  end

  describe "HTTPlaster.delete/3" do
    test "sends DELETE to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      Bypass.expect(server, fn conn ->
        assert conn.method == "DELETE"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, r_conn} = HTTPlaster.delete(server_address)

      assert r_conn.status == :executed
    end
  end

  describe "HTTPlaster.delete!/3" do
    test "raises when it cannot connect to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"
      Bypass.down(server)

      assert_raise HTTPlaster.Adapters.HTTPC.ConnectionFailedError, fn ->
        HTTPlaster.delete!(server_address)
      end
    end
  end

  describe "HTTPlaster.get/3" do
    test "sends GET to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      Bypass.expect(server, fn conn ->
        assert conn.method == "GET"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.get(server_address)
    end
  end

  describe "HTTPlaster.get!/3" do
    test "raises when it cannot connect to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"
      Bypass.down(server)

      assert_raise HTTPlaster.Adapters.HTTPC.ConnectionFailedError, fn ->
        HTTPlaster.get!(server_address)
      end
    end
  end

  describe "HTTPlaster.head/3" do
    test "sends HEAD to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      Bypass.expect(server, fn conn ->
        assert conn.method == "HEAD"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.head(server_address)
    end
  end

  describe "HTTPlaster.head!/3" do
    test "raises when it cannot connect to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"
      Bypass.down(server)

      assert_raise HTTPlaster.Adapters.HTTPC.ConnectionFailedError, fn ->
        HTTPlaster.head!(server_address)
      end
    end
  end

  describe "HTTPlaster.options/3" do
    test "sends OPTIONS to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      Bypass.expect(server, fn conn ->
        assert conn.method == "OPTIONS"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.options(server_address)
    end
  end

  describe "HTTPlaster.options!/3" do
    test "raises when it cannot connect to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"
      Bypass.down(server)

      assert_raise HTTPlaster.Adapters.HTTPC.ConnectionFailedError, fn ->
        HTTPlaster.options!(server_address)
      end
    end
  end

  describe "HTTPlaster.patch/4" do
    test "sends PATCH to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      Bypass.expect(server, fn conn ->
        assert conn.method == "PATCH"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.patch(server_address, "")
    end
  end

  describe "HTTPlaster.patch!/4" do
    test "raises when it cannot connect to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"
      Bypass.down(server)

      assert_raise HTTPlaster.Adapters.HTTPC.ConnectionFailedError, fn ->
        HTTPlaster.patch!(server_address, "")
      end
    end
  end

  describe "HTTPlaster.post/4" do
    test "sends POST to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      Bypass.expect(server, fn conn ->
        assert conn.method == "POST"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.post(server_address, "")
    end
  end

  describe "HTTPlaster.post!/4" do
    test "raises when it cannot connect to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"
      Bypass.down(server)

      assert_raise HTTPlaster.Adapters.HTTPC.ConnectionFailedError, fn ->
        HTTPlaster.post!(server_address, "")
      end
    end
  end

  describe "HTTPlaster.put/4" do
    test "sends PUT to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      Bypass.expect(server, fn conn ->
        assert conn.method == "PUT"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.put(server_address, "")
    end
  end

  describe "HTTPlaster.put!/4" do
    test "raises when it cannot connect to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"
      Bypass.down(server)

      assert_raise HTTPlaster.Adapters.HTTPC.ConnectionFailedError, fn ->
        HTTPlaster.put!(server_address, "")
      end
    end
  end

  describe "HTTPlaster.request/5" do
    test "sends headers to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      accept_header = {"accept", "application/json"}

      headers = Map.new([accept_header])

      Bypass.expect(server, fn conn ->
        assert conn.method == "GET"
        assert accept_header in conn.req_headers

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.request(:get, server_address, nil, headers, [])
    end

    test "sends params to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      params = [q: "string theory"]

      Bypass.expect(server, fn conn ->
        assert conn.method == "GET"
        assert conn.query_string == "q=string+theory"


        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.request(:get, server_address, nil, %{}, [params: params])
    end

    test "sends params with duplicates to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      params = [q: "string theory", v: "1", v: "2"]

      Bypass.expect(server, fn conn ->
        assert conn.method == "GET"
        assert conn.query_string == "q=string+theory&v=2&v=1"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.request(:get, server_address, nil, %{}, [params: params])
    end

    test "sends TRACE to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"

      Bypass.expect(server, fn conn ->
        assert conn.method == "TRACE"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      {:ok, _} = HTTPlaster.request(:trace, server_address, nil, %{}, [])
    end
  end

  describe "HTTPlaster.request!/5" do
    test "raises when it cannot connect to server" do
      server = Bypass.open()
      server_address = "http://localhost:#{server.port}"
      Bypass.down(server)

      assert_raise HTTPlaster.Adapters.HTTPC.ConnectionFailedError, fn ->
        HTTPlaster.request!(:get, server_address, "", %{}, [])
      end
    end
  end
end
