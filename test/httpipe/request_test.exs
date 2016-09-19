defmodule HTTPipe.RequestTest do
  use ExUnit.Case

  alias HTTPipe.Request

  describe "HTTPipe.Request.encode_body/1" do
    test "encodes nil" do
      assert Request.encode_body(nil) == {:ok, ""}
    end

    test "encodes {:form, form_data}" do
      body = {:form, [q: "plataformatec Elixir", tbas: 0]}

      assert Request.encode_body(body) == {:ok, "q=plataformatec+Elixir&tbas=0"}
    end

    test "encodes {:file, filepath}" do
      body = {:file, "test/fixtures/test_file.txt"}

      {:ok, encoded_body} = Request.encode_body(body)

      assert :erlang.byte_size(encoded_body) == 255
    end

    test "returns {:error, File.Error.t} when filepath is invalid" do
      body = {:file, "test/fixtures/non_existent.txt"}

      {:error, %File.Error{}} = Request.encode_body(body)
    end
  end

  describe "HTTPipe.Request.prepare_body/2" do
    test "returns unencoded body when processing is deferred" do
      assert Request.prepare_body(nil, true) == {:ok, nil}
    end

    test "returns prepared body when processing isn't deferred" do
      assert Request.prepare_body(nil, false) == {:ok, ""}
    end
  end

  describe "HTTPipe.Request.prepare_url/2" do
    test "returns prepared url with no params" do
      url = "https://google.com/"

      assert Request.prepare_url(url, []) == {:ok, "https://google.com/"}
    end

    test "returns prepared url with params" do
      url = "https://google.com/"
      params = %{q: ["plataformatec Elixir"], tbas: [0]}

      expected_url = "https://google.com/?q=plataformatec+Elixir&tbas=0"

      assert Request.prepare_url(url, params) == {:ok, expected_url}
    end

    test "returns prepared url with multiple params of the same name" do
      url = "https://google.com/"
      params = %{q: ["plataformatec Elixir"], tbas: [0, 1]}

      expected_url = "https://google.com/?q=plataformatec+Elixir&tbas=0&tbas=1"

      assert Request.prepare_url(url, params) == {:ok, expected_url}
    end

    test "returns {:error, NilURLError.t} when URL is nil" do
      url = nil
      params = []

      assert Request.prepare_url(url, params) == {:error, %Request.NilURLError{}}
    end
  end

  describe "HTTPipe.Request.put_authentication_basic/3" do
    test "sets Authorization header" do
      expected_value = "Basic dXNlcm5hbWU6cGFzc3dvcmQ="

      request =
        %Request{}
        |> Request.put_authentication_basic("username", "password")

      assert {"authorization", expected_value} in request.headers
    end
  end

  describe "HTTPipe.Request.put_header/4" do
    test "with default duplication option will flatten values" do
      request =
        %Request{}
        |> Request.put_header("Accept-Encoding", "gzip")
        |> Request.put_header("Accept-Encoding", "deflate")

      assert {"accept-encoding", "gzip, deflate"} in request.headers
    end

    test "with :duplicates_ok will flatten values" do
      request =
        %Request{}
        |> Request.put_header("Accept-Encoding", "gzip", :duplicates_ok)
        |> Request.put_header("Accept-Encoding", "deflate", :duplicates_ok)

      assert {"accept-encoding", "gzip, deflate"} in request.headers
    end

    test "with :prefer_existing will not replace existing values" do
      request =
        %Request{}
        |> Request.put_header("Accept-Encoding", "gzip", :prefer_existing)
        |> Request.put_header("Accept-Encoding", "deflate", :prefer_existing)

      assert {"accept-encoding", "gzip"} in request.headers
    end

    test "with :replace_existing will replace existing values" do
      request =
        %Request{}
        |> Request.put_header("Accept-Encoding", "gzip", :replace_existing)
        |> Request.put_header("Accept-Encoding", "deflate", :replace_existing)

      assert {"accept-encoding", "deflate"} in request.headers
    end
  end

  describe "HTTPipe.Request.clear_headers/1" do
    test "clears existing headers" do
      request =
        %Request{headers: %{"accept-encoding" => "br"}}
        |> Request.clear_headers()

      refute {"accept-encoding", "br"} in request.headers
      assert map_size(request.headers) == 0
    end
  end

  describe "HTTPipe.Request.merge_headers/2" do
    test "puts the headers into the struct" do
      headers = %{
        "Accept-Encoding" => "gzip, deflate",
        "Content-Type" => "application/json; charset=utf8"
      }

      request =
        %Request{}
        |> Request.merge_headers(headers)

      assert {"accept-encoding", "gzip, deflate"} in request.headers
      assert {"content-type", "application/json; charset=utf8"} in request.headers
    end

    test "replaces existing headers in the struct" do
      headers = %{
        "Accept-Encoding" => "gzip, deflate",
        "Content-Type" => "application/json; charset=utf8"
      }

      request =
        %Request{headers: %{"accept-encoding" => "br"}}
        |> Request.merge_headers(headers)

      refute {"accept-encoding", "br"} in request.headers
      assert {"accept-encoding", "gzip, deflate"} in request.headers
      assert {"content-type", "application/json; charset=utf8"} in request.headers
    end
  end

  describe "HTTPipe.Request.put_method/2" do
    test "puts the method in the struct" do
      request =
        %Request{}
        |> Request.put_method(:get)

      assert request.method == :get
    end

    test "replaces existing method in the struct" do
      request =
        %Request{method: :get}
        |> Request.put_method(:patch)

      assert request.method == :patch
    end
  end

  describe "HTTPipe.Request.put_param/4" do
    test "with default duplication option will replace existing params" do
      request =
        %Request{params: %{"q" => ["plataformatec Elixir"], "tbas" => [0]}}
        |> Request.put_param(:tbas, 1)

      assert {"tbas", [1]} in request.params
    end

    test "with :duplicates_ok will prepend to the list of values" do
      request =
        %Request{params: %{"q" => ["plataformatec Elixir"], "tbas" => [0]}}
        |> Request.put_param(:tbas, 1, :duplicates_ok)

      assert {"tbas", [1, 0]} in request.params
    end

    test "with :prefer_existing will leave values as-is" do
      request =
        %Request{params: %{"q" => ["plataformatec Elixir"], "tbas" => [0]}}
        |> Request.put_param(:tbas, 1, :prefer_existing)

      assert {"tbas", [0]} in request.params
    end

    test "with :replace_existing will replace existing values" do
      request =
        %Request{params: %{"q" => ["plataformatec Elixir"], "tbas" => [0]}}
        |> Request.put_param(:tbas, 1, :replace_existing)

      assert {"tbas", [1]} in request.params
    end
  end

  describe "HTTPipe.Request.put_url/2" do
    test "puts the URL in the struct" do
      request =
        %Request{}
        |> Request.put_url("https://google.com/")

      assert request.url == "https://google.com/"
    end
  end
end
