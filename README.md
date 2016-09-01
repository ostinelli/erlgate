# ErlGate

ErlGate is an alternative transport for Erlang messages across nodes, which uses parallel TCP connection pipes to send data.
This allows:

  * The reliable sending of messages across Erlang clusters (for example in a WAN).
  * A fine-grain management of nodes communication, since a full mesh is not necessary.
