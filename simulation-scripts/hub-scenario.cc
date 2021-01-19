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
//       n1    n2   n3   n4
//       |     |    |    |
//     =====================
//            CSMA
//
//  Simulates the behaviour of L1 hub device interconnecting 4 nodes in a shared CSMA channel
//  Traffic summary: 
//  node n1 pings node n3
//  node n2 pings node n4

#include <iostream>
#include <fstream>
#include <string>
#include <cassert>

#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/csma-module.h"
#include "ns3/applications-module.h"
#include "ns3/internet-apps-module.h"
#include "ns3/internet-module.h"

using namespace ns3;

NS_LOG_COMPONENT_DEFINE ("HubScenario");

std::string StringWireState (WireState state)
{
  switch (state)
  {
    case IDLE:    
      return std::string("IDLE");
    case TRANSMITTING:
      return std::string("TRANSMITTING");
    case PROPAGATING:
      return std::string("PROPAGATING");
    default: 
      return std::string("IDLE");
  }
}


static void PrintTxEvent (std::string context, Ptr<const Packet> packet)
{
  std::size_t posNode = context.find("NodeList");  
  std::size_t postEvent = context.find("CsmaNetDevice");    
  std::cout << "Node: " << context.substr (posNode+9, 1) << " ---- "
            << "Event: " << context.substr(postEvent+14) << " ---- "
            << "Simulation Time: "  << Simulator::Now().GetNanoSeconds() << " ns "<< std::endl;  
}

static void PrintBackoff(std::string context, Ptr<const Packet> packet, Time backoffTime)
{
  std::size_t posNode = context.find("NodeList");  
  std::size_t postEvent = context.find("CsmaNetDevice");    
  std::cout << "Node: " << context.substr (posNode+9, 1) << " ---- "
            << "Event: " << context.substr(postEvent+14) << " ---- "
            << "backing off for: " << backoffTime.As (Time::NS) << " s ---- "
            << "Simulation Time: "  << Simulator::Now().GetNanoSeconds() << " ns "<< std::endl;  
}

static void PrintWireState (std::string context, WireState state)
{
  std::cout << "CSMA channel state changed to: " << StringWireState(state) << std::endl;  
}


static void PrintNetDevicePacket (std::string context, Ptr<const Packet> packet)
{
  std::size_t pos = context.find("DeviceList");      
  std::cout << context.substr (0, pos-1) << " " << packet->ToString() << std::endl;  
}


int
main (int argc, char *argv[])
{

  bool printPackets = false;
  bool printChannelState = false;
  //LogComponentEnable ("HubScenario", LOG_LEVEL_INFO);
  //LogComponentEnable ("CsmaChannel", LOG_LEVEL_INFO);
  //LogComponentEnable ("CsmaNetDevice", LOG_LEVEL_LOGIC);  
  
  std::string protocolNumber = "1"; // ICMP

  CommandLine cmd (__FILE__);
  cmd.AddValue ("printPackets", "Output received packets to standard output", printPackets);  
  cmd.AddValue ("printChannelState", "Output CSMA channel events", printChannelState);  
  cmd.Parse (argc, argv);  
  
  // Here, we will explicitly create four nodes.
  NS_LOG_INFO ("Create nodes.");
    
  Ptr<Node> n1 = CreateObject<Node> (); 
  Ptr<Node> n2 = CreateObject<Node> ();                                           
  Ptr<Node> n3 = CreateObject<Node> ();  
  Ptr<Node> n4 = CreateObject<Node> ();  
  
  Names::Add ("Node1",  n1);
  Names::Add ("Node2",  n2);
  Names::Add ("Node3",  n3);
  Names::Add ("Node4",  n4);  
  
  // Group them for easy install
  NodeContainer c;
  c.Add(n1);
  c.Add(n2);
  c.Add(n3);
  c.Add(n4);
    
  // connect all our nodes to a shared channel.
  NS_LOG_INFO ("Build Topology.");
  CsmaHelper csma;
  csma.SetChannelAttribute ("DataRate", DataRateValue (DataRate (5000000)));
  csma.SetChannelAttribute ("Delay", TimeValue (MilliSeconds (2)));  
  NetDeviceContainer devs = csma.Install (c);

  // add an ip stack to all nodes.
  NS_LOG_INFO ("Add ip stack.");
  InternetStackHelper ipStack;
  ipStack.Install (c);

  // assign ip addresses
  NS_LOG_INFO ("Assign ip addresses.");
  Ipv4AddressHelper ip;
  ip.SetBase ("192.168.1.0", "255.255.255.0");
  Ipv4InterfaceContainer addresses = ip.Assign (devs);
  
  NS_LOG_INFO ("Creating Sources");    
  Config::SetDefault ("ns3::Ipv4RawSocketImpl::Protocol",  StringValue (protocolNumber.c_str()));  
  ApplicationContainer sourceApps;
  
  OnOffHelper onoff = OnOffHelper ("ns3::Ipv4RawSocketFactory", InetSocketAddress(n3->GetObject<Ipv4>()->GetAddress(1,0).GetLocal()) );
  onoff.SetConstantRate (DataRate (15000));
  onoff.SetAttribute ("PacketSize", UintegerValue (1200));     
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
  

  NS_LOG_INFO ("Configure Tracing.");
  // pcap tracing in promiscuous mode
  csma.EnablePcapAll ("hub-scenario", true);
  
  if (printPackets)
  {
    Config::Connect("/NodeList/*/DeviceList/0/$ns3::CsmaNetDevice/PromiscSniffer" ,  MakeCallback(&PrintNetDevicePacket));
    Packet::EnablePrinting ();    
  }
  
  if (printChannelState)
  { 
    Config::Connect("/NodeList/*/DeviceList/0/$ns3::CsmaNetDevice/MacRx" ,  MakeCallback(&PrintTxEvent ));  
    Config::Connect("/NodeList/*/DeviceList/0/$ns3::CsmaNetDevice/MacTx" ,  MakeCallback(&PrintTxEvent ));  
    Config::Connect("/NodeList/*/DeviceList/0/$ns3::CsmaNetDevice/PhyTxBegin" ,  MakeCallback(&PrintTxEvent ));  
    Config::Connect("/NodeList/*/DeviceList/0/$ns3::CsmaNetDevice/PhyTxEnd" ,  MakeCallback(&PrintTxEvent ));  
    Config::Connect("/NodeList/*/DeviceList/0/$ns3::CsmaNetDevice/MacTxBackoff" ,  MakeCallback(&PrintBackoff ));
    Config::Connect("/ChannelList/0/$ns3::CsmaChannel/WireState" ,  MakeCallback(&PrintWireState ));  
  }

  NS_LOG_UNCOND ("Run simulation.");
  Simulator::Run ();
  Simulator::Destroy ();
  NS_LOG_UNCOND ("Simulation finished.");
}
