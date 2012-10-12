/*
 * Copyright (c) 2011 University of Bremen, TZI
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

generic module CoapRouteResourceP(typedef val_t, uint8_t uri_key) {
  provides interface CoapResource;
  uses interface ForwardingTable;
} implementation {

  bool lock = FALSE;
  coap_async_state_t *temp_async_state = NULL;
  unsigned int temp_media_type;

  struct {
    int ifindex;
    char *name;
  } ifaces[3] = {{0, "any"}, {1, "pan"}, {2, "ppp"}};

  char *ifnam(int ifidx) {
    int i;
    for (i = 0; i < sizeof(ifaces) / sizeof(ifaces[0]); i++) {
      if (ifaces[i].ifindex == ifidx)
	return ifaces[i].name;
    }
    return NULL;
  }

  command error_t CoapResource.initResourceAttributes(coap_resource_t *r) {

#ifdef COAP_CONTENT_TYPE_PLAIN
    coap_add_attr(r, (unsigned char *)"ct", 2, (unsigned char *)"0", 1, 0);
#endif

    return SUCCESS;
  }

  void task getRoute() {
#define LEN (COAP_MAX_PDU_SIZE - (cur - buf))
    struct route_entry *entry;
    int n;
    int cur_entry;
    char *buf;
    char *cur;
    char buf2[COAP_MAX_PDU_SIZE];
    buf = buf2;
    cur = buf;

    entry = call ForwardingTable.getTable(&n);
    if (!buf || !entry) {
      lock = FALSE;
      signal CoapResource.methodDone(FAIL, COAP_RESPONSE_CODE(500),
				     temp_async_state,
				     (uint8_t*)buf, cur - buf,
				     temp_media_type, NULL);
      return;
    }

    for (;cur_entry < n; cur_entry++) {
      if (entry[cur_entry].valid) {
	cur += snprintf(cur, LEN, "%2i\t", entry[cur_entry].key);
	cur += inet_ntop6(&entry[cur_entry].prefix, cur, LEN) - 1;
	cur += snprintf(cur, LEN, "/%i\t\t", entry[cur_entry].prefixlen);
	cur += inet_ntop6(&entry[cur_entry].next_hop, cur, LEN) - 1;
	if (LEN < 6) continue;
	*cur++ = '\t'; *cur++ = '\t';
	strncpy(cur, ifnam(entry[cur_entry].ifindex), LEN);
	cur += 3;
	*cur++ = '\n';
      }
    }

    if (cur > buf) {
      lock = FALSE;
      signal CoapResource.methodDone(SUCCESS, COAP_RESPONSE_CODE(205),
				     temp_async_state,
				     (uint8_t*)buf, cur - buf,
				     temp_media_type, NULL);
    }
    // } else {
    //   // no route available? -> don't send a packet
    //   signal ReadResource.getDone(SUCCESS, id_t, 0, (uint8_t*)"No Route", sizeof("No Route"));
    // }

  };

  command int CoapResource.getMethod(coap_async_state_t* async_state,
				     uint8_t *val, size_t buflen,
				     unsigned int media_type) {
    if (lock == FALSE) {
      lock = TRUE;
      temp_async_state = async_state;
      temp_media_type = media_type;
      post getRoute();
      return COAP_SPLITPHASE;
    } else {
      return COAP_RESPONSE_CODE(503);
    }
  }

  command int CoapResource.putMethod(coap_async_state_t* async_state,
				     uint8_t *val, size_t buflen, coap_resource_t *resource,
				     unsigned int media_type) {
    return COAP_RESPONSE_CODE(405);
  }

  command int CoapResource.postMethod(coap_async_state_t* async_state,
				      uint8_t *val, size_t buflen, coap_resource_t *resource,
				      unsigned int media_type) {
    return COAP_RESPONSE_CODE(405);
  }

  command int CoapResource.deleteMethod(coap_async_state_t* async_state,
					uint8_t *val, size_t buflen) {
    return COAP_RESPONSE_CODE(405);
  }
  }
