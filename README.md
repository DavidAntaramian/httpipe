# HTTPlaster [![ISC License](https://img.shields.io/badge/license-ISC-ff69b4.svg)](LICENSE)

HTTPlaster is an adapter-driven HTTP library for Elixir that provides a way
to build composable HTTP requests.

Inspired by the Plug library, HTTPlaster provides a similar system by which
an HTTPlaster.Conn struct is built and dispatched; though unlike Plug it
maintains the request and response under two separate keys.

HTTPlaster does not actually handle the data-interchange, instead it relies
on a adapter library specified by the user. The adapter must conform to
the HTTPlaster.Adapter behaviour. Specification of the adapter is done
globally with the `httplaster.adapter_module` configuration value, but
HTTPlaster also allows adapters to be specified on a per-request basis.
This can be helpful for testing scenarios when you need to use a mocked
adapter for a test.

## Interoperability with HTTPoison/HTTPotion

HTTPlaster is designed to be roughly interoperable with the basic functions
from HTTPoison and HTTPotion. It provides the `get/3`, `post/4`, `put/4`,
`delete/3`, `head/3`, `patch/4`, `options/3`, and `request/5` (and their
`bang!` style equivalents) to get you out the door. These will be converted
to `HTTPlaster.Conn` structs and executed immediately.

Unlike HTTPoison/HTTPotion, HTTPlaster returns an `HTTPlaster.Conn` struct
which will not conform to any existing pattern matching you may do on
`Response` structs from other libraries. Typically, you will have to rearrange
your pattern matching to be on the internal `:response` key of the `Conn`
struct.

