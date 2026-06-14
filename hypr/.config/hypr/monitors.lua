------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°)

-- Left Monitor (Acer KG241 P)
hl.monitor({
  output = "HDMI-A-1",
  mode = "1920x1080@119.98200",
  position = "0x0",
  scale = 1,
  transform = 1, -- Rotate 90 degrees
})

-- Center Monitor (Acer VG270 P)
hl.monitor({
  output = "DP-2",
  mode = "1920x1080@143.85500",
  position = "1080x0",
  scale = 1,
})

-- Right Monitor (Dell P1913)
hl.monitor({
  output = "DP-1",
  mode = "1440x900@59.88700",
  position = "3000x0",
  scale = 1,
})
