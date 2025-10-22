# OBS Studio RTMP Streaming Guide

This guide will help you test the RTMP streaming functionality with OBS Studio.

## Prerequisites

1. **OBS Studio** installed ([download here](https://obsproject.com/))
2. **Docker services running**: MediaMTX and Rails app
3. **User account** with a valid stream key

## Step 1: Start Docker Services

```bash
docker-compose up
```

This will start:
- **Rails app** on `localhost:3000`
- **MediaMTX** on port `1935` (RTMP) and `8889` (HLS)
- **Redis** for caching
- **PostgreSQL** for database

## Step 2: Get Your Stream Key

1. Log in to StreamHub at `http://localhost:3000`
2. Go to **Settings** → **Streaming**
3. Copy your **Stream Key** (it should look like: `sk_xxxxxxxxxxxxxxxxxxxxxxxx`)

## Step 3: Configure OBS Studio

### RTMP Settings

1. Open **OBS Studio**
2. Go to **Settings** → **Stream**
3. Configure the following:

   - **Service**: Custom
   - **Server**: `rtmp://localhost:1935`
   - **Stream Key**: `[Your stream key from Step 2]`

4. Click **Apply** and **OK**

### Optional: Output Settings

1. Go to **Settings** → **Output**
2. Set **Output Mode** to **Advanced**
3. **Streaming** tab:
   - **Encoder**: x264
   - **Rate Control**: CBR
   - **Bitrate**: 2500 Kbps (adjust based on your network)
   - **Keyframe Interval**: 2
   - **CPU Usage Preset**: veryfast or faster

4. Click **Apply** and **OK**

## Step 4: Start Streaming

1. Add a **Source** in OBS (Display Capture, Window Capture, or Video Capture Device)
2. Click **Start Streaming**
3. OBS should connect to MediaMTX within a few seconds

## Step 5: Verify Stream is Live

### Method 1: Check Rails Logs

```bash
docker-compose logs -f rails
```

Look for:
```
✅ RTMP Auth: Stream key validated for user [username]
🔴 PUBLISH: [username] started streaming
```

### Method 2: Check StreamHub Dashboard

1. Go to `http://localhost:3000/dashboard`
2. Your stream should show as **LIVE**
3. The stream should be visible on your profile page

### Method 3: Watch Your Stream

1. Go to `http://localhost:3000/streams/[your-stream-id]`
2. The HLS player should start playing your live stream
3. You may see a 5-10 second delay (normal for HLS)

## Step 6: Stop Streaming

1. Click **Stop Streaming** in OBS
2. Check the Rails logs:

```
⚫ UNPUBLISH: [username] stopped streaming
```

3. Your stream status should change to **OFFLINE** in the dashboard

## Troubleshooting

### Connection Refused

**Problem**: OBS shows "Failed to connect to server"

**Solutions**:
- Make sure MediaMTX is running: `docker-compose ps`
- Check MediaMTX logs: `docker-compose logs mediamtx`
- Verify port 1935 is not in use: `lsof -i :1935`

### Invalid Stream Key

**Problem**: OBS connects but immediately disconnects

**Solutions**:
- Verify your stream key is correct (copy it again from Settings)
- Check Rails logs for authentication errors
- Make sure you're using the full stream key (starts with `sk_`)

### Stream Not Showing as Live

**Problem**: OBS is streaming but dashboard shows offline

**Solutions**:
- Check webhook endpoints: `curl http://localhost:3000/rtmp/status`
- Verify Rails can reach MediaMTX webhooks
- Check for errors in Rails logs

### Video Won't Play

**Problem**: Stream shows as live but video player doesn't work

**Solutions**:
- Check HLS output: `curl http://localhost:8889/[stream-key]/index.m3u8`
- Make sure browser can access port 8889
- Try refreshing the page
- Check browser console for errors

## Testing Checklist

- [ ] OBS connects successfully with stream key
- [ ] Rails logs show authentication success
- [ ] Dashboard shows stream as LIVE
- [ ] HLS video player loads and plays stream
- [ ] Action Cable broadcasts stream status
- [ ] Stream stops successfully when OBS disconnects
- [ ] Dashboard shows stream as OFFLINE
- [ ] Stream duration is calculated correctly

## API Endpoints

### Check RTMP Status
```bash
curl http://localhost:3000/rtmp/status
```

### Test Authentication (simulated)
```bash
curl -X POST http://localhost:3000/rtmp/auth \
  -H "Content-Type: application/json" \
  -d '{"key": "your_stream_key_here"}'
```

## Architecture Overview

```
┌─────────────┐         RTMP          ┌──────────────┐
│  OBS Studio │ ───────────────────────> │   MediaMTX   │
└─────────────┘    rtmp://localhost:1935 └──────────────┘
                       Stream Key                │
                                                  │ Webhooks
                                                  ▼
                                         ┌──────────────┐
                                         │  Rails App   │
                                         │  (RtmpCtrl)  │
                                         └──────────────┘
                                                  │
                                                  ▼
                                         ┌──────────────┐
                                         │   Database   │
                                         │   (Streams)  │
                                         └──────────────┘
                                                  │
                                                  ▼
                                         ┌──────────────┐
                                         │ Action Cable │
                                         │  (Overlays)  │
                                         └──────────────┘
```

## Flow

1. **Authentication**: MediaMTX calls `/rtmp/auth` with stream key
2. **Stream Start**: MediaMTX calls `/rtmp/webhooks/publish` when stream begins
3. **Status Update**: Rails updates Stream model to `live`
4. **Broadcast**: Action Cable notifies connected clients
5. **HLS Output**: MediaMTX serves HLS at `http://localhost:8889/[key]/index.m3u8`
6. **Stream End**: MediaMTX calls `/rtmp/webhooks/unpublish` when stream stops
7. **Cleanup**: Rails marks stream as `offline` and calculates duration

## Next Steps

Once RTMP streaming is working:

1. **Add VOD Recording** - Configure MediaMTX to save streams to S3
2. **Implement Chat** - Connect chat to live streams
3. **Add Overlays** - Build custom OBS browser source overlays
4. **Stream Analytics** - Track viewer count, watch time, peak viewers
5. **Multi-quality Streaming** - Add adaptive bitrate streaming
6. **CDN Integration** - Use CloudFront or similar for global distribution

## Production Considerations

### Security
- Use HTTPS for webhook endpoints
- Validate webhook signatures
- Rate limit authentication attempts
- Rotate stream keys periodically

### Performance
- Use Redis for caching stream status
- Implement CDN for HLS delivery
- Monitor MediaMTX resource usage
- Scale horizontally with multiple MediaMTX instances

### Reliability
- Add health checks for MediaMTX
- Implement automatic stream recovery
- Log all stream events for debugging
- Set up alerts for failed streams

---

**Document Version:** 1.0
**Last Updated:** 2025-10-15
**Status:** Ready for Testing
