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
#include "ns3/bridge-module.h"
#include "ns3/ssid.h"

// Default Network Topology
//
//   Wifi 10.1.1.0
//                  --- AP/Router --- n1   n2   n3   n4
//  *    *    *    *                  |    |    |    |
//  |    |    |    |                  ================ 
// n5   n6   n7   n8                  LAN 192.168.1.0
//                     
//                     
//     Network 2                          Network 1

using namespace ns3;

NS_LOG_COMPONENT_DEFINE ("ThirdScriptExample");

int 
main (int argc, char *argv[])
{
  bool verbose = true;  
  bool tracing = false;

  std::string csmaLinkDataRate    = "100Mbps";
  std::string csmaLinkDelay       = "500ns";
  
  CommandLine cmd (__FILE__);  
  cmd.AddValue ("verbose", "Tell echo applications to log if true", verbose);
  cmd.AddValue ("tracing", "Enable pcap tracing", tracing);

  cmd.Parse (argc,argv);

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
  
  Ptr<Node> r1 = CreateObject<Node> ();   //                   : This node has two interfaces one for each network and acts as the Router bridging network 1 with network 2
                                          // IF01: 192.168.1.1 : Switch in Network 1
                                          // IF02: 10.0.1.1    : AP in Network 2
                                          
          
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
 
  
  // ======================================================================
  // Create Network 1: Wired
  // ----------------------------------------------------------------------
  NS_LOG_INFO ("L2: Create a " <<  csmaLinkDataRate << " " <<    csmaLinkDelay << " CSMA link for csmaX for LANs.");  
  CsmaHelper csma;
  csma.SetChannelAttribute ("DataRate", StringValue (csmaLinkDataRate));
  csma.SetChannelAttribute ("Delay",    StringValue (csmaLinkDelay));
  
  NetDeviceContainer NodePhyDev;
  NetDeviceContainer SwitchPhyDev;

  // Pair each switch output with a corresponding node using a csma channel (wire)
  for (uint32_t i = 0; i < wiredNodes.GetN (); ++i)
  {
    
    NodeContainer nodes (r1, wiredNodes.Get (i));
    NetDeviceContainer nd = csma.Install (nodes);      
    SwitchPhyDev.Add(nd.Get(0));
    NodePhyDev.Add(nd.Get(1));
  } 
  
  // Install bridging code on switch to enable switching between different csma channels
  BridgeHelper bridge;  
  bridge.Install (r1, SwitchPhyDev);
 
    
  // ======================================================================
  // Create  Network 2: Wireless
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
  

  Simulator::Run ();
  Simulator::Destroy ();
  return 0;
}
