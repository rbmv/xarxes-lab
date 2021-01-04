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
 *
 */

#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/csma-module.h"
#include "ns3/csma-star-helper.h"
#include "ns3/applications-module.h"
#include "ns3/internet-module.h"
#include "ns3/bridge-module.h"
#include "ns3/ipv6-address-generator.h"
#include <sstream>

// Network topology (default)
//
//            n1     +          +     n2          .
//             | ... |\        /| ... |           .
//             ======= \      / =======           .
//              CSMA    \    /   CSMA             .
//                       \  /                     .
//                        s1                      .
//                       /  \                     .
//                      /    \                    .
//                     /      \                   .
//                    /        \                  .
//            n3     +          +     n4          .
//             | ... |          | ... |           .
//             =======          =======           .
//              CSMA             CSMA             .
//

using namespace ns3;

NS_LOG_COMPONENT_DEFINE ("SwitchScenario");

int 
main (int argc, char *argv[])
{  
  std::string csmaLinkDataRate    = "100Mbps";
  std::string csmaLinkDelay       = "500ns";
  uint16_t 	mtu = 1500;
  
//   LogComponentEnable ("SwitchScenario", LOG_LEVEL_INFO);
//   LogComponentEnable ("OnOffApplication", LOG_LEVEL_INFO);
//   LogComponentEnable ("PacketSink", LOG_LEVEL_INFO);   
  
  CommandLine cmd (__FILE__);
  cmd.AddValue ("mtu", "Netdevice MTU", mtu);
  
  cmd.Parse (argc, argv);  
  
  Config::SetDefault ("ns3::CsmaNetDevice::Mtu", UintegerValue (mtu));  
  
  // ======================================================================
  // Create the nodes & links required for the topology shown in comments above.
  // ----------------------------------------------------------------------
  NS_LOG_INFO ("INFO: Create nodes.");    // - - - - - - - - - - - - - - - -
                                          // Node IP     : Description
                                          // - - - - - - - - - - - - - - - -
  Ptr<Node> n1  = CreateObject<Node> ();  // 192.168.1.1 : 
  Ptr<Node> n2  = CreateObject<Node> ();  // 192.168.1.2 : 
  Ptr<Node> n3  = CreateObject<Node> ();  // 192.168.1.3 : 
  Ptr<Node> n4  = CreateObject<Node> ();  // 192.168.1.4 : 
  
  Ptr<Node> s1 = CreateObject<Node> ();   // <no IP>     : switch #1 
  
  // Group them for convenience
  NodeContainer n;
  n.Add(n1);
  n.Add(n2);
  n.Add(n3);
  n.Add(n4);
  
  Names::Add ("Node1",  n1);
  Names::Add ("Node2",  n2);
  Names::Add ("Node3",  n3);
  Names::Add ("Node4",  n4);
  Names::Add ("Switch",  s1);    
  
   // ======================================================================
  // Create CSMA links to use for connecting LAN nodes together
  // ----------------------------------------------------------------------  
  CsmaHelper csma;
  csma.SetChannelAttribute ("DataRate", StringValue (csmaLinkDataRate));
  csma.SetChannelAttribute ("Delay",    StringValue (csmaLinkDelay));
  
  NetDeviceContainer NodePhyDev;
  NetDeviceContainer SwitchPhyDev;

  // Pair each switch output with a corresponding node using a csma channel (wire)
  for (uint32_t i = 0; i < n.GetN (); ++i)
  {
    
    NodeContainer nodes (s1, n.Get (i));
    NetDeviceContainer nd = csma.Install (nodes);      
    SwitchPhyDev.Add(nd.Get(0));
    NodePhyDev.Add(nd.Get(1));
  } 
  
  // Install bridging code on switch to enable forwarding between different channels
  BridgeHelper bridge;  
  bridge.Install (s1, SwitchPhyDev);
    
  // ======================================================================
  // Install the L3 internet stack  (TCP/IP)
  // ----------------------------------------------------------------------
  InternetStackHelper ns3IpStack;
  ns3IpStack.Install (n);
  
  NS_LOG_INFO ("Assign ip addresses.");
  Ipv4AddressHelper ip;
  ip.SetBase ("192.168.1.0", "255.255.255.0");
  Ipv4InterfaceContainer addresses = ip.Assign (NodePhyDev);
  
  
  NS_LOG_INFO ("Creating Sources");    
  Config::SetDefault ("ns3::Ipv4RawSocketImpl::Protocol", StringValue ("2"));  
  ApplicationContainer sourceApps;
  
  OnOffHelper onoff = OnOffHelper ("ns3::Ipv4RawSocketFactory", InetSocketAddress(n3->GetObject<Ipv4>()->GetAddress(1,0).GetLocal()) );
  onoff.SetConstantRate (DataRate (15000));
  onoff.SetAttribute ("PacketSize", UintegerValue (2000));     
  sourceApps.Add(onoff.Install (n1));      
  
  onoff.SetAttribute("Remote", AddressValue(InetSocketAddress(n4->GetObject<Ipv4>()->GetAddress(1,0).GetLocal())));
  sourceApps.Add(onoff.Install (n2));      
  
  sourceApps.Start (Seconds (1.0));
  sourceApps.Stop (Seconds (5.0));  
  
    
  NS_LOG_INFO ("Create Sinks.");  
  ApplicationContainer sinkApps;      
  PacketSinkHelper sink1 = PacketSinkHelper ("ns3::Ipv4RawSocketFactory", InetSocketAddress(n3->GetObject<Ipv4>()->GetAddress(1,0).GetLocal()) );
  sinkApps.Add(sink1.Install (n3)); 
  PacketSinkHelper sink2 = PacketSinkHelper ("ns3::Ipv4RawSocketFactory", InetSocketAddress(n4->GetObject<Ipv4>()->GetAddress(1,0).GetLocal()) );
  sinkApps.Add(sink2.Install (n4));
  
  sinkApps.Start (Seconds (0.0));
  sinkApps.Stop (Seconds (6.0));    
 
  NS_LOG_INFO ("Enable static global routing.");
  Ipv4GlobalRoutingHelper::PopulateRoutingTables ();

  NS_LOG_INFO ("Enable pcap tracing.");
  //
  // Do pcap tracing on all devices on all nodes.
  //
  csma.EnablePcapAll ("switch-scenario", true);

  NS_LOG_INFO ("Run Simulation.");
  Simulator::Run ();
  Simulator::Destroy ();
  NS_LOG_INFO ("Done.");

  return 0;
}
