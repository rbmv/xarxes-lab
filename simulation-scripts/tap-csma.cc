/* -*- Mode:C++; c-file-style:"gnu"; indent-tabs-mode:nil; -*- */
/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation;
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

// Network topology
//
// Packets sent to the device "thetap" on the Linux host will be sent to the
// tap bridge on node zero and then emitted onto the ns-3 simulated CSMA
// network.  ARP will be used on the CSMA network to resolve MAC addresses.
// Packets destined for the CSMA device on node zero will be sent to the
// device "thetap" on the linux Host.
//
//  +----------+
//  | external |
//  |  Linux   |
//  |   Host   |
//  |          |
//  | "thetap" |
//  +----------+
//       |           n1            n2            n3            n4
//       |       +--------+    +--------+    +--------+    +--------+
//       +-------|  tap   |    |        |    |        |    |        |
//               | bridge |    |        |    |        |    |        |
//               +--------+    +--------+    +--------+    +--------+
//               |  CSMA  |    |  CSMA  |    |  CSMA  |    |  CSMA  |
//               +--------+    +--------+    +--------+    +--------+
//                   |             |             |             |
//                   |             |             |             |
//                   |             |             |             |
//                   ===========================================
//                                 CSMA LAN 10.1.1
//
// The CSMA device on node zero is:  10.1.1.1
// The CSMA device on node one is:   10.1.1.2
// The CSMA device on node two is:   10.1.1.3
// The CSMA device on node three is: 10.1.1.4
//
// Some simple things to do:
//
// 1) Ping one of the simulated nodes
//
//    ./waf --run tap-csma&
//    ping 10.1.1.2
//
#include <iostream>
#include <fstream>

#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/wifi-module.h"
#include "ns3/csma-module.h"
#include "ns3/internet-module.h"
#include "ns3/ipv4-global-routing-helper.h"
#include "ns3/tap-bridge-module.h"

using namespace ns3;

NS_LOG_COMPONENT_DEFINE ("TapCsmaExample");

void PrintAddrInfo(Ptr<Node> node)
{
  for (uint16_t i=0; i < (node->GetNDevices()); i++)
  {
        Ptr<NetDevice> dev=node->GetDevice(i);
        std::cout  << " DevType: " << dev->GetInstanceTypeId()
        << " - MAC Addr: " << Mac48Address::ConvertFrom(dev->GetAddress());

        Ptr<Ipv4> ipProto = node->GetObject<Ipv4>();

        if (ipProto)
        {
            int16_t ifnum = ipProto->GetInterfaceForDevice(dev);
            for (uint16_t j=0; (ifnum>0) && j < ipProto->GetNAddresses(ifnum); j++)
                std::cout << " - Ip Addr(" << j << "):" << ipProto->GetAddress(ifnum,j).GetLocal();
        }
        std::cout << std::endl;
  }
}

void PrintNodeInfo(NodeContainer &c)
{
    for (uint16_t i=0; i < c.GetN(); i++)
    {
        Ptr<Node> node = c.Get(i);
        std::cout
        << Names::FindName(node) << " : " << std::endl;
        PrintAddrInfo(node);
        std::cout << std::endl;
    }
}

void PrintInfo(NodeContainer &c)
{
    std::cout << "======================" << std::endl;
    std::cout << " Scenario Information: " << std::endl;
    std::cout << "======================" << std::endl;
    PrintNodeInfo(c);
    std::cout << "======================" << std::endl;
}

int 
main (int argc, char *argv[])
{
  std::string mode = "ConfigureLocal";
  std::string tapName = "thetap";

  CommandLine cmd (__FILE__);
  cmd.AddValue ("mode", "Mode setting of TapBridge", mode);
  cmd.AddValue ("tapName", "Name of the OS tap device", tapName);
  cmd.Parse (argc, argv);

  GlobalValue::Bind ("SimulatorImplementationType", StringValue ("ns3::RealtimeSimulatorImpl"));
  GlobalValue::Bind ("ChecksumEnabled", BooleanValue (true));

  Ptr<Node> n1 = CreateObject<Node> ();
  Ptr<Node> n2 = CreateObject<Node> ();
  Ptr<Node> n3 = CreateObject<Node> ();
  Ptr<Node> n4 = CreateObject<Node> ();

  Names::Add ("Node1",  n1);
  Names::Add ("Node2",  n2);
  Names::Add ("Node3",  n3);
  Names::Add ("Node4",  n4);

  // Group them for easy install
  NodeContainer nodes;
  nodes.Add(n1);
  nodes.Add(n2);
  nodes.Add(n3);
  nodes.Add(n4);

  CsmaHelper csma;
  csma.SetChannelAttribute ("DataRate", DataRateValue (5000000));
  csma.SetChannelAttribute ("Delay", TimeValue (MilliSeconds (2)));

  NetDeviceContainer devices = csma.Install (nodes);

  InternetStackHelper stack;
  stack.Install (nodes);

  Ipv4AddressHelper addresses;
  addresses.SetBase ("10.1.1.0", "255.255.255.0");
  Ipv4InterfaceContainer interfaces = addresses.Assign (devices);

  TapBridgeHelper tapBridge;
  tapBridge.SetAttribute ("Mode", StringValue (mode));
  tapBridge.SetAttribute ("DeviceName", StringValue (tapName));
  tapBridge.Install (nodes.Get (0), devices.Get (0));

  csma.EnablePcapAll ("tap-csma", true);
  Ipv4GlobalRoutingHelper::PopulateRoutingTables ();

  PrintInfo(nodes);

  Simulator::Stop (Seconds (60.));
  Simulator::Run ();
  Simulator::Destroy ();
}
