#ifndef __MEDIASERVER_H__
#define __MEDIASERVER_H__




struct airplay_callbacks_s
{
    void *cls;
    /* Compulsory callback functions */
    void(*AirPlayAudio_Init)(void *cls, int bits, int channels, int samplerate, int isaudio);
    void(*AirPlayAudio_Process)(void *cls, const void *buffer, int buflen, double timestamp, uint32_t seqnum);
    void(*AirPlayAudio_destroy)(void *cls);
    void(*AirPlayAudio_SetVolume)(void *cls, int volume);//1-100
    void(*AirPlayMirroring_Play)(void *cls,int width,int height,const void *buffer, int buflen, int payloadtype, double timestamp);
    void(*AirPlayMirroring_Process)(void *cls, const void *buffer, int buflen, int payloadtype, double timestamp);
    void(*AirPlayMirroring_Stop)(void *cls);
    
};
typedef struct airplay_callbacks_s airplay_callbacks_t;

int XinDawn_StartMediaServer(char *friendname, int width, int height, int framerate, int airtunes_port, int airvideo_port, char *activecode, airplay_callbacks_t *cb);
void XinDawn_StopMediaServer();


#endif
