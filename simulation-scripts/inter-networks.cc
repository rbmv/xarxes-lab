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

#include "ns3/core-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/network-module.h"
#include "ns3/applications-module.h"
#include "ns3/mobility-module.h"
#include "ns3/csma-module.h"
#include "ns3/internet-module.h"
#include "ns3/yans-wifi-helper.h"
#include "ns3/tap-bridge-module.h"
#include "ns3/ssid.h"

// Default Network Topology
//
//   Wifi 10.1.1.0        AP/Router 
//                  ---     r1    --- n1   n2   n3   n4
//  *    *    *    *                  |    |    |    |
//  |    |    |    |                  ================ 
// n5   n6   n7   n8                  LAN 192.168.1.0
//                     
//                     
//     Network 2                          Network 1

using namespace ns3;

NS_LOG_COMPONENT_DEFINE ("InterNetworks");


void PrintAddrInfo(Ptr<Node> node)
{
  for (uint16_t i=0; i < (node->GetNDevices()); i++)
  {
        Ptr<NetDevice> dev=node->GetDevice(i);
        std::cout  << " DevType: " << dev->GetInstanceTypeId()  << " - Mtu: " << dev->GetMtu()
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
  std::string csmaLinkDataRate    = "100Mbps";
  std::string csmaLinkDelay       = "500ns";
  bool tapMode = false;
  
  uint16_t 	mtu_n1 = 1000;
  uint16_t 	mtu_n2 = 500;
  uint16_t 	packetSize = 800;
  uint32_t 	seed=1;
  

  std::string protocolNumber = "4"; // ICMP
  
  CommandLine cmd (__FILE__);  
  cmd.AddValue ("tapMode", "Enable tap interface in simulation", tapMode);
  cmd.AddValue ("seed", "seed", seed);
  cmd.Parse (argc,argv);

  if (seed != 1)
  {

    SeedManager::SetSeed (seed);

    Ptr<UniformRandomVariable> x = CreateObject<UniformRandomVariable> ();
    x->SetAttribute ("Min", DoubleValue (1.0));
    x->SetAttribute ("Max", DoubleValue (3.0));

    uint16_t  multiplier = x->GetInteger();
    mtu_n2     = multiplier* mtu_n2;
    packetSize = packetSize * (1 + multiplier%2);

  }

  Config::SetDefault ("ns3::CsmaNetDevice::Mtu", UintegerValue (mtu_n1));
  Config::SetDefault ("ns3::WifiNetDevice::Mtu", UintegerValue (mtu_n2));

  if (tapMode)
  {
     GlobalValue::Bind ("SimulatorImplementationType", StringValue ("ns3::RealtimeSimulatorImpl"));
     GlobalValue::Bind ("ChecksumEnabled", BooleanValue (true));
  }


  std::cout << "Wifi MTU:"     << mtu_n2 << std::endl
            << "Ethernet MTU:" << mtu_n1 << std::endl
            << "Packet Size: " << packetSize << std::endl;

  // ======================================================================
  // Create the nodes & links required for the topology shown in comments above.
  // ----------------------------------------------------------------------
  NS_LOG_INFO ("INFO: Create nodes.");    // - - - - - - - - - - - - - - - -
                                          // Node IP     : Description
                                          // - - - - - - - - - - - - - - - -
  Ptr<Node> n1  = CreateObject<Node> ();  // 192.168.1.2 : 
  Ptr<Node> n2  = CreateObject<Node> ();  // 192.168.1.3 : 
  Ptr<Node> n3  = CreateObject<Node> ();  // 192.168.1.4 : 
  Ptr<Node> n4  = CreateObject<Node> ();  // 192.168.1.5 : 
  
  Ptr<Node> r1 = CreateObject<Node> ();   //                   : This node has two network interfaces and acts as the Router between network 1 with network 2
                                          // IF01: 192.168.1.1 : IP of interface in Network 1
                                          // IF02: 10.0.1.1    : IP of interface in Network 2
                                                
  Ptr<Node> n5 = CreateObject<Node> ();   // 10.0.1.2 : 
  Ptr<Node> n6 = CreateObject<Node> ();   // 10.0.1.3 :                                         
  Ptr<Node> n7 = CreateObject<Node> ();   // 10.0.1.4 : 
  Ptr<Node> n8 = CreateObject<Node> ();   // 10.0.1.5 :   
 
  
  Names::Add ("Router",  r1);  
  
  Names::Add ("Node1",  n1);
  Names::Add ("Node2",  n2);
  Names::Add ("Node3",  n3);
  Names::Add ("Node4",  n4);    
  Names::Add ("Node5",  n5);
  Names::Add ("Node6",  n6);
  Names::Add ("Node7",  n7);
  Names::Add ("Node8",  n8);    

  NodeContainer wiredNodes;  
  wiredNodes.Add(n1);
  wiredNodes.Add(n2);
  wiredNodes.Add(n3);
  wiredNodes.Add(n4);
  
  NodeContainer wifiStaNodes;  
  wifiStaNodes.Add(n5);
  wifiStaNodes.Add(n6);
  wifiStaNodes.Add(n7);
  wifiStaNodes.Add(n8);  
   
  NodeContainer allNodes;
  allNodes.Add(wiredNodes);
  allNodes.Add(wifiStaNodes);   
  allNodes.Add(r1);
  
  // ======================================================================
  // Layer 2 - Network 1: Wired
  // ----------------------------------------------------------------------
  NS_LOG_INFO ("Build Topology.");
  CsmaHelper csma;
  csma.SetChannelAttribute ("DataRate", DataRateValue (DataRate (5000000)));
  csma.SetChannelAttribute ("Delay", TimeValue (MilliSeconds (2)));
  
  NodeContainer csmaNodes;
  csmaNodes.Add(r1);
  csmaNodes.Add(wiredNodes);
  NetDeviceContainer NodesPhyDev = csma.Install (csmaNodes);  
     
  // ======================================================================
  // Layer 2 - Network 1: Wireless
  // ----------------------------------------------------------------------

  NodeContainer wifiApNode;
  wifiApNode.Add( r1 );
    
  YansWifiChannelHelper channel = YansWifiChannelHelper::Default ();
  YansWifiPhyHelper phy = YansWifiPhyHelper::Default ();
  phy.SetChannel (channel.Create ());

  WifiHelper wifi;
  wifi.SetRemoteStationManager ("ns3::AarfWifiManager");

  WifiMacHelper mac;
  Ssid ssid = Ssid ("xarxes-ssid");
  mac.SetType ("ns3::StaWifiMac",
               "Ssid", SsidValue (ssid),
               "ActiveProbing", BooleanValue (false));

  NetDeviceContainer staDevices;
  staDevices = wifi.Install (phy, mac, wifiStaNodes);

  mac.SetType ("ns3::ApWifiMac",
               "Ssid", SsidValue (ssid));

  NetDeviceContainer apDevices;
  apDevices = wifi.Install (phy, mac, wifiApNode);

  MobilityHelper mobility;

  mobility.SetPositionAllocator ("ns3::GridPositionAllocator",
                                 "MinX", DoubleValue (0.0),
                                 "MinY", DoubleValue (0.0),
                                 "DeltaX", DoubleValue (5.0),
                                 "DeltaY", DoubleValue (10.0),
                                 "GridWidth", UintegerValue (3),
                                 "LayoutType", StringValue ("RowFirst"));

  mobility.SetMobilityModel ("ns3::RandomWalk2dMobilityModel",
                             "Bounds", RectangleValue (Rectangle (-50, 50, -50, 50)));
  mobility.Install (wifiStaNodes);

  mobility.SetMobilityModel ("ns3::ConstantPositionMobilityModel");
  mobility.Install (wifiApNode);
  
  // ======================================================================
  // Layer 3 : Installation
  // ======================================================================
  
  // Install Ip Stack to nodes
  NS_LOG_INFO ("Add ip stack.");
  InternetStackHelper ipStack;
  ipStack.Install (allNodes);
    
  // Assign ip addresses to network 1  
  NS_LOG_INFO ("Assign ip addresses to network 1.");
  Ipv4AddressHelper addressNet1;
  addressNet1.SetBase ("192.168.1.0", "255.255.255.0");
  //addressNet1.Assign (SwitchPhyDev);  
  addressNet1.Assign (NodesPhyDev);
  
  // Assign ip addresses to network 2
  Ipv4AddressHelper addressNet2;
  NS_LOG_INFO ("Assign ip addresses to network 1.");
  addressNet2.SetBase ("10.1.1.0", "255.255.255.0");
  addressNet2.Assign (apDevices);
  addressNet2.Assign (staDevices);
  
  Ipv4GlobalRoutingHelper::PopulateRoutingTables ();
  
  // ======================================================================
  // Layer 4/5 : Applications over transport protocol
  // ======================================================================

  if (tapMode)
  {
    NS_LOG_INFO ("Enable tap mode in Node 1");

    std::string mode = "ConfigureLocal";
    std::string tapName = "thetap";

    TapBridgeHelper tapBridge;
    tapBridge.SetAttribute ("Mode", StringValue (mode));
    tapBridge.SetAttribute ("DeviceName", StringValue (tapName));
    tapBridge.Install (n1, NodesPhyDev.Get(1));

    Simulator::Stop (Seconds (60.));
  }
  else
  {
    NS_LOG_INFO ("Create Traffic Source.");
    Config::SetDefault ("ns3::Ipv4RawSocketImpl::Protocol", StringValue (protocolNumber.c_str()));
    ApplicationContainer sourceApps;

    OnOffHelper onoff = OnOffHelper ("ns3::Ipv4RawSocketFactory", InetSocketAddress(n7->GetObject<Ipv4>()->GetAddress(1,0).GetLocal()) );
    onoff.SetConstantRate (DataRate (15000));
    onoff.SetAttribute ("PacketSize", UintegerValue (packetSize));
    sourceApps.Add(onoff.Install (n1));

    sourceApps.Start (Seconds (1.0));
    sourceApps.Stop (Seconds (2.0));

    NS_LOG_INFO ("Create Sinks.");
    ApplicationContainer sinkApps;
    PacketSinkHelper sink1 = PacketSinkHelper ("ns3::Ipv4RawSocketFactory", InetSocketAddress(n7->GetObject<Ipv4>()->GetAddress(1,0).GetLocal()) );
    sinkApps.Add(sink1.Install (n7));

    sinkApps.Start (Seconds (0.0));
    sinkApps.Stop (Seconds (20.0));

    Simulator::Stop (Seconds (20.0));
  }

  PrintInfo(allNodes);

  phy.EnablePcap ("wifi-net", apDevices.Get (0));        
  phy.EnablePcap ("wifi-net", staDevices);        
  csma.EnablePcapAll ("wired-net", false);

  NS_LOG_UNCOND ("Run simulation.");
  Simulator::Run ();
  Simulator::Destroy ();
  NS_LOG_INFO ("Done.");
  return 0;
}
