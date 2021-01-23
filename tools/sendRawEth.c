/*
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 */

#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <net/if.h>
#include <netinet/ether.h>
#include <regex.h>

#define MY_SRC_MAC0	0x00
#define MY_SRC_MAC1	0x00
#define MY_SRC_MAC2	0x00
#define MY_SRC_MAC3	0x00
#define MY_SRC_MAC4	0x00
#define MY_SRC_MAC5	0x01

#define MY_DEST_MAC0	0x00
#define MY_DEST_MAC1	0x00
#define MY_DEST_MAC2	0x00
#define MY_DEST_MAC3	0x00
#define MY_DEST_MAC4	0x00
#define MY_DEST_MAC5	0x03

#define DEFAULT_IF	"thetap"
#define BUF_SIZ		1024

int
match(const char *string, const char *pattern)
{
    int    status;
    regex_t    re;

    if (regcomp(&re, pattern, REG_EXTENDED|REG_NOSUB) != 0) {
        return(0);      /* report error */
    }
    status = regexec(&re, string, (size_t) 0, NULL, 0);
    regfree(&re);
    if (status != 0) {
        return(0);      /* report error */
    }
    return(1);
}

int main(int argc, char *argv[])
{
	int sockfd;
	struct ifreq if_idx;	
	int tx_len = 0;
	char sendbuf[BUF_SIZ];
	struct ether_header *eh = (struct ether_header *) sendbuf;
	struct iphdr *iph = (struct iphdr *) (sendbuf + sizeof(struct ether_header));
	struct sockaddr_ll socket_address;
	char ifName[IFNAMSIZ];
    unsigned int src_mac[6];
    unsigned int dest_mac[6];
    int parsing_mac[6];
    memset(dest_mac, 0, 6*sizeof(unsigned int));
    int i = 0;
    	
	/* Get interface name */
	if (argc > 1)
    {
        if ((strlen(argv[1]) < IFNAMSIZ) && match(argv[1], "^[a-z0-9]*$")) 
        {
           strncpy(ifName, argv[1], IFNAMSIZ);           
           printf("Using interface: %s \n", ifName);
        }
        else
        {
           printf ("Interface name not valid\n");
           return -1; 
        }
    }
	else
    {        
		strcpy(ifName, DEFAULT_IF);
        printf("Using defualt interface : %s \n", ifName);
    }
    

	/* Open RAW socket to send on */
	if ((sockfd = socket(AF_PACKET, SOCK_RAW, IPPROTO_RAW)) == -1) {
	    perror("socket");
	}

	/* Get the index of the interface to send on */
	memset(&if_idx, 0, sizeof(struct ifreq));
	strncpy(if_idx.ifr_name, ifName, IFNAMSIZ-1);
	if (ioctl(sockfd, SIOCGIFINDEX, &if_idx) < 0)
	    perror("SIOCGIFINDEX");

	/* Construct the Ethernet header */
	memset(sendbuf, 0, BUF_SIZ);	
    
    /* Get Source */
    if (argc > 2)
    {
        if( (strlen(argv[2]) ==  17)  && match(argv[2], "^([0-9a-fA-F][0-9a-fA-F]:){5}([0-9a-fA-F][0-9a-fA-F])$"))
        {   
            if (6 != sscanf(argv[2], "%2x:%2x:%2x:%2x:%2x:%2x",
                 parsing_mac, parsing_mac+1, parsing_mac+2, parsing_mac+3, parsing_mac+4, parsing_mac+5)) 
            {
                printf("Provided destination address could not be parsed\n");
                return -1;            
            }
            
            for (i=0; i< 6; i++)
                eh->ether_shost[i]=(uint8_t) parsing_mac[i];
            
            printf("Using source addres: %02x:%02x:%02x:%02x:%02x:%02x\n", 
                   (unsigned int) eh->ether_shost[0], 
                   (unsigned int) eh->ether_shost[1], 
                   (unsigned int) eh->ether_shost[2], 
                   (unsigned int) eh->ether_shost[3], 
                   (unsigned int) eh->ether_shost[4], 
                   (unsigned int) eh->ether_shost[5]);
        }
        else
        {
            printf("Format error in provided destination address, use a valid MAC address with ':' as separator value. Ex: 00:00:00:00:00:0A\n");
            return -1;
        }     
    }
    else
    {
        printf("Using default source address (00:00:00:00:00:01) \n");
        eh->ether_shost[0] = MY_SRC_MAC0;
        eh->ether_shost[1] = MY_SRC_MAC1;
        eh->ether_shost[2] = MY_SRC_MAC2;
        eh->ether_shost[3] = MY_SRC_MAC3;
        eh->ether_shost[4] = MY_SRC_MAC4;
        eh->ether_shost[5] = MY_SRC_MAC5;    
    }
    
    /* Get destination */
    if (argc > 3)
    {
        if( (strlen(argv[3]) ==  17)  && match(argv[3], "^([0-9a-fA-F][0-9a-fA-F]:){5}([0-9a-fA-F][0-9a-fA-F])$"))
        {   
            if (6 != sscanf(argv[3], "%2x:%2x:%2x:%2x:%2x:%2x",
                  parsing_mac, parsing_mac+1, parsing_mac+2, parsing_mac+3, parsing_mac+4, parsing_mac+5)) 
            {
                printf("Provided destination address could not be parsed\n");
                return -1;            
            }
            
             for (i=0; i< 6; i++)
                eh->ether_dhost[i]=(uint8_t) parsing_mac[i];
            
            printf("Using destination addres: %02x:%02x:%02x:%02x:%02x:%02x\n", 
                   (unsigned int) eh->ether_dhost[0], 
                   (unsigned int) eh->ether_dhost[1], 
                   (unsigned int) eh->ether_dhost[2], 
                   (unsigned int) eh->ether_dhost[3], 
                   (unsigned int) eh->ether_dhost[4], 
                   (unsigned int) eh->ether_dhost[5]);
        }
        else
        {
            printf("Format error in provided destination address. Use a valid MAC address with ':' as the separator value. Ex: 00:00:00:00:00:0A\n");
            return -1;
        }     
    }
    else
    {
        printf("Using default destination address (00:00:00:00:00:03) \n");
        eh->ether_dhost[0] = MY_DEST_MAC0;
        eh->ether_dhost[1] = MY_DEST_MAC1;
        eh->ether_dhost[2] = MY_DEST_MAC2;
        eh->ether_dhost[3] = MY_DEST_MAC3;
        eh->ether_dhost[4] = MY_DEST_MAC4;
        eh->ether_dhost[5] = MY_DEST_MAC5;
    }


	/* Ethertype field */
	eh->ether_type = htons(ETH_P_IP);
	tx_len += sizeof(struct ether_header);

	/* Packet data */
	sendbuf[tx_len++] = 0xde;
	sendbuf[tx_len++] = 0xad;
	sendbuf[tx_len++] = 0xbe;
	sendbuf[tx_len++] = 0xef;

	/* Index of the network device */
	socket_address.sll_ifindex = if_idx.ifr_ifindex;
	/* Address length*/
	socket_address.sll_halen = ETH_ALEN;
	/* Destination MAC */
	socket_address.sll_addr[0] = eh->ether_dhost[0];
	socket_address.sll_addr[1] = eh->ether_dhost[1];
	socket_address.sll_addr[2] = eh->ether_dhost[2];
	socket_address.sll_addr[3] = eh->ether_dhost[3];
	socket_address.sll_addr[4] = eh->ether_dhost[4];
	socket_address.sll_addr[5] = eh->ether_dhost[5];

	/* Send packet */
	if (sendto(sockfd, sendbuf, tx_len, 0, (struct sockaddr*)&socket_address, sizeof(struct sockaddr_ll)) < 0)
	    printf("Send failed\n");
    else
        printf("Raw ethernet frame sent!\n");

	return 0;
}
