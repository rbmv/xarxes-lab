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
#include "ns3/ssid.h"

// Default Network Topology
//
//   Wifi 10.1.1.0
//         AP       
//         |
//  ^    ^    ^    ^
//  ^    ^    ^    ^    Wireless Channel
//  *    *    *    *
//  |    |    |    |    
// n4   n5   n6   n7
//                 
//                                   
//                                   

using namespace ns3;

NS_LOG_COMPONENT_DEFINE ("wifi-scenario");

int 
main (int argc, char *argv[])
{
  bool verbose = true;  
  bool tracing = true;
  uint16_t 	mtu = 1500;
   
  CommandLine cmd (__FILE__);  
  cmd.AddValue ("mtu", "Netdevice MTU", mtu);
  cmd.AddValue ("verbose", "Tell echo applications to log if true", verbose);
  cmd.AddValue ("tracing", "Enable pcap tracing", tracing);

  cmd.Parse (argc,argv);
  
  Config::SetDefault ("ns3::WifiNetDevice::Mtu", UintegerValue (mtu));  
  
  // Here, we will explicitly create four nodes.
  NS_LOG_INFO ("Create nodes.");
    
  Ptr<Node> n5 = CreateObject<Node> (); 
  Ptr<Node> n6 = CreateObject<Node> ();                                           
  Ptr<Node> n7 = CreateObject<Node> ();  
  Ptr<Node> n8 = CreateObject<Node> ();    
  Ptr<Node> AP = CreateObject<Node> ();  
  
  Names::Add ("AccesPoint",  AP);  
  Names::Add ("Node5",  n5);
  Names::Add ("Node6",  n6);
  Names::Add ("Node7",  n7);
  Names::Add ("Node8",  n8);    

  NodeContainer wifiStaNodes;  
  wifiStaNodes.Add(n5);
  wifiStaNodes.Add(n6);
  wifiStaNodes.Add(n7);
  wifiStaNodes.Add(n8);
   
  NodeContainer wifiApNode;
  wifiApNode.Add( AP );
    
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

  InternetStackHelper stack;  
  stack.Install (wifiApNode);
  stack.Install (wifiStaNodes);

  Ipv4AddressHelper address;

  address.SetBase ("10.1.1.0", "255.255.255.0");
  address.Assign (staDevices);
  address.Assign (apDevices);
  
  Ipv4GlobalRoutingHelper::PopulateRoutingTables ();
  
  
  NS_LOG_INFO ("Creating Sources");    
  Config::SetDefault ("ns3::Ipv4RawSocketImpl::Protocol", StringValue ("2"));  
  ApplicationContainer sourceApps;
  
  OnOffHelper onoff = OnOffHelper ("ns3::Ipv4RawSocketFactory", InetSocketAddress(n7->GetObject<Ipv4>()->GetAddress(1,0).GetLocal()) );
  onoff.SetConstantRate (DataRate (15000));
  onoff.SetAttribute ("PacketSize", UintegerValue (1200));     
  sourceApps.Add(onoff.Install (n5));      
  
  onoff.SetAttribute("Remote", AddressValue(InetSocketAddress(n8->GetObject<Ipv4>()->GetAddress(1,0).GetLocal())));
  sourceApps.Add(onoff.Install (n6));      
  
  sourceApps.Start (Seconds (1.0));
  sourceApps.Stop (Seconds (5.0));  
  
  NS_LOG_INFO ("Create Sinks.");  
  ApplicationContainer sinkApps;      
  PacketSinkHelper sink1 = PacketSinkHelper ("ns3::Ipv4RawSocketFactory", InetSocketAddress(n7->GetObject<Ipv4>()->GetAddress(1,0).GetLocal()) );
  sinkApps.Add(sink1.Install (n7)); 
  PacketSinkHelper sink2 = PacketSinkHelper ("ns3::Ipv4RawSocketFactory", InetSocketAddress(n8->GetObject<Ipv4>()->GetAddress(1,0).GetLocal()) );
  sinkApps.Add(sink2.Install (n8));
  
  sinkApps.Start (Seconds (0.0));
  sinkApps.Stop (Seconds (6.0));    
  

  Simulator::Stop (Seconds (10.0));

  if (tracing == true)
    {      
      phy.EnablePcap ("wifi-scenario", apDevices.Get (0));      
    }

  Simulator::Run ();
  Simulator::Destroy ();
  return 0;
}
