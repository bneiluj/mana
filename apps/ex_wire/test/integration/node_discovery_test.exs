defmodule ExWire.NodeDiscoveryTest do
  use ExUnit.Case, async: true
  alias ExWire.NodeDiscoverySupervisor
  alias ExWire.Message.Ping
  alias ExWire.Struct.Endpoint
  alias ExWire.{Config, Network}
  alias ExWire.Adapter.UDP
  alias ExWire.Kademlia
  alias ExWire.Kademlia.{Node, RoutingTable}

  @moduletag integration: true
  @moduletag network: true

  @remote_address System.get_env("REMOTE_TEST_PEER") || ExWire.Config.chain().nodes |> List.last()

  setup_all do
    kademlia_process_name = KademliaNodeDiscoveryTest
    udp_name = UdpNodeDiscoveryTest
    network_adapter = {UDP, udp_name}
    supervisor_name = NodeDiscoveryTest
    port = 11_117

    start_supervised!({
      NodeDiscoverySupervisor,
      [
        kademlia_process_name: kademlia_process_name,
        network_adapter: network_adapter,
        supervisor_name: supervisor_name,
        port: port
      ]
    })

    {:ok,
     %{
       kademlia_name: kademlia_process_name,
       udp_name: udp_name,
       supervisor_name: supervisor_name
     }}
  end

  test "receives pong from remote node and adds it to local routing table", %{
    kademlia_name: kademlia_name,
    udp_name: udp_name
  } do
    remote_endpoint = remote_endpoint()
    current_endpoint = current_endpoint()
    ping = Ping.new(current_endpoint, remote_endpoint)

    Network.send(ping, udp_name, remote_endpoint)
    Process.sleep(1000)

    routing_table = Kademlia.routing_table(process_name: kademlia_name)
    assert RoutingTable.member?(routing_table, expected_node())
  end

  defp remote_endpoint do
    %URI{
      scheme: _scheme,
      userinfo: _remote_id,
      host: remote_host,
      port: remote_peer_port
    } = remote_uri()

    remote_ip =
      with {:ok, remote_ip} <- :inet.ip(remote_host |> String.to_charlist()) do
        remote_ip |> Tuple.to_list()
      end

    %Endpoint{
      ip: remote_ip,
      udp_port: remote_peer_port
    }
  end

  defp current_endpoint do
    public_ip = Config.public_ip()

    %Endpoint{ip: public_ip, udp_port: 11_116, tcp_port: 11_115}
  end

  defp expected_node do
    %URI{
      scheme: _scheme,
      userinfo: remote_id,
      host: _remote_host,
      port: _remote_peer_port
    } = remote_uri()

    public_key = ExthCrypto.Math.hex_to_bin(remote_id)

    Node.new(public_key, remote_endpoint())
  end

  defp remote_uri do
    %URI{
      scheme: "enode",
      userinfo: _remote_id,
      host: _remote_host,
      port: _remote_peer_port
    } = uri = URI.parse(@remote_address)

    uri
  end
end
