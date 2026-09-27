# Multiplayer

Players see each other in the arena as colored capsules labeled with their
player number. Each browser runs its own movement (so the Source-style physics
feels the same as offline) and sends its position 20 times a second to a
dedicated server, which relays it to everyone else. Frogs and citizens are still
simulated separately in each browser, so they are not in the same place for
everyone.

The code lives in the `Network` autoload (`scripts/network.gd`) and
`scripts/remote_player.gd`. With no server configured, or while the server is
down, the game is single-player and retries every 5 seconds. The header shows
**ONLINE: N** or **OFFLINE** once a server is configured.

## Hosting the server (Linux VPS)

Browsers on the HTTPS game page can only connect over secure WebSockets
(`wss://`), so the server needs a domain name and a TLS certificate. Caddy
handles the certificate automatically.

1. **Domain.** Point a DNS `A` record (for example `play.example.com`) at the
   VPS's public IP. A free DuckDNS subdomain also works.
2. **Firewall.** Allow inbound TCP 80 and 443 (in the Vultr firewall group and
   `ufw` if enabled). Port 9080 stays private.
3. **Godot.** Download the Godot 4.7 Linux editor binary (the same version as
   the project) to `/opt/godot/godot`, and clone this repository to `/opt/tfpp`.
4. **Import once:** `/opt/godot/godot --headless --path /opt/tfpp --import`
5. **Game server service**, `/etc/systemd/system/tfpp.service`:

   ```ini
   [Unit]
   Description=TFPP multiplayer server
   After=network.target

   [Service]
   User=tfpp
   ExecStart=/opt/godot/godot --headless --path /opt/tfpp -- --server --port=9080 --bind=127.0.0.1
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

   Create the user (`useradd -r tfpp`, `chown -R tfpp /opt/tfpp`), then run
   `systemctl enable --now tfpp`. Check it with `journalctl -u tfpp -f`; it
   prints `Multiplayer server listening on 127.0.0.1:9080`.
6. **Caddy** (`apt install caddy`), `/etc/caddy/Caddyfile`:

   ```
   play.example.com {
       reverse_proxy 127.0.0.1:9080
   }
   ```

   Then `systemctl reload caddy`.
7. **Point the game at it:** set `tfpp/multiplayer/server_url` in
   `project.godot` to `wss://play.example.com`.

To test a server without changing the project, open the game with
`?server=wss://play.example.com` added to its URL.

## Updating

The server and browsers must run the same network code. After a release that
changes `scripts/network.gd`, run `git pull` in `/opt/tfpp` and
`systemctl restart tfpp`.
