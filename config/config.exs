use Mix.Config

config :httplaster, adapter: HTTPlaster.Adapters.Unimplemented

if File.exists?("config/#{Mix.env}.exs") do
  import_config "#{Mix.env}.exs"
end
